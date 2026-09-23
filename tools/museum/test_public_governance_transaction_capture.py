"""Original transaction source joins, refusal paths and exact offline capture replay."""
import copy
from contextlib import redirect_stdout
import io
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from ..metadata import acquisition_governance_transactions_v1 as definition
from . import public_governance_transaction_capture as capture
from . import public_governance_transaction_source as source
from . import public_governance_transaction_rpc as rpc
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .finality_governance_transaction_fixture import FinalityGovernanceTransactionFixture
from .test_current_rights_source import A, H
from .test_public_finality_capture import repin


class PublicGovernanceTransactionCaptureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = FinalityGovernanceTransactionFixture()
        cls.native = cls.fixture.finality_capture()
        cls.observed = source.PublicGovernanceTransactionSource(cls.native.files, cls.native.manifest_hash, cls.fixture)
        cls.result = capture._assemble(cls.observed, source.PROFILE_HASH)
        cls.transcript = loads(cls.observed.transcript(), maximum=rpc.MAX_TRANSCRIPT, canonical=True)

    def replay(self, transcript):
        raw = dumps(transcript)
        return capture.replay(self.native.files, self.native.manifest_hash, source.PROFILE_HASH,
            raw, keccak256(raw), provenance="synthetic_fixture", disclosure="public")

    def test_original_capture_transaction_receipt_bytes_and_source_pins_retained(self):
        files = dict(self.result.files)
        for path, raw in self.native.files: self.assertEqual(files[capture.NATIVE_PREFIX + path], raw)
        fragment = loads(files[capture.FRAGMENT_PATH], maximum=definition.MAX_BYTES)
        self.assertEqual(definition.validate(files[capture.FRAGMENT_PATH]), fragment["reconstruction"])
        self.assertEqual(fragment["nativeFinality"], loads(dict(self.native.files)["native-finality/fragment.json"], maximum=definition.MAX_BYTES))
        anchor = loads(files["source/anchor.json"])
        self.assertEqual(anchor["nativeManifestHash"], self.native.manifest_hash)
        self.assertEqual(anchor["executor"], fragment["nativeFinality"]["graph"]["executor"])
        for role, index in (("schedule", 1), ("execution", 2)):
            observation = fragment["transactions"][role]
            tx = self.transcript["calls"][index]["result"]
            self.assertEqual(hex_bytes(observation["transactionBytes"]), dumps(tx))
            receipt = self.fixture.receipts[tx["hash"]]
            self.assertEqual(hex_bytes(observation["receiptBytes"]), dumps(receipt))

    def test_three_original_lookups_and_preimages_do_not_rewrite_authority(self):
        rows = self.transcript["calls"]
        self.assertEqual([row["method"] for row in rows], ["eth_chainId", "eth_getTransactionByHash", "eth_getTransactionByHash"])
        self.assertEqual(rows[1]["params"], [self.fixture.schedule_transaction_hash])
        self.assertEqual(rows[2]["params"], [self.fixture.execution_transaction_hash])
        report = self.result.report["reconstruction"]
        self.assertEqual(report["status"], "reconstructed")
        self.assertTrue(report["claims"]["bothOriginalTransactionInputsDecoded"])
        self.assertTrue(report["claims"]["actionIdPreimageReconstructed"])
        for flag in ("completeAuthority", "historicalRoleAuthorizationReexecuted", "historicalPolicyReexecuted",
                "transactionHashesRecomputed", "actualChainAcceptance"):
            self.assertFalse(report["claims"][flag])

    def test_original_transaction_identity_placement_chain_and_actor_tampering_rejects(self):
        changes = {"hash": H(123456), "blockHash": H(123456), "blockNumber": "0x99", "transactionIndex": "0x99",
            "chainId": "0xffff", "from": A(123456), "value": "0x1"}
        for key, value in changes.items():
            transcript = copy.deepcopy(self.transcript); transcript["calls"][1]["result"][key] = value
            with self.subTest(key=key), self.assertRaises(MuseumError): self.replay(transcript)
        transcript = copy.deepcopy(self.transcript); transcript["calls"][0]["result"] = "0xffff"
        with self.assertRaisesRegex(MuseumError, "RPC chain differs"): self.replay(transcript)

    def test_missing_inputs_stay_partial_and_single_execute_never_inverts_aggregate_hashes(self):
        for index in (1, 2):
            transcript = copy.deepcopy(self.transcript); transcript["calls"][index]["result"] = None
            result = self.replay(transcript)
            report = result.report["reconstruction"]
            self.assertEqual(report["status"], "partial")
            self.assertFalse(report["claims"]["bothOriginalTransactionInputsDecoded"])
            self.assertFalse(report["claims"]["completeAuthority"])
            if index == 1:
                self.assertIsNone(report["calls"])
                self.assertIn("single_execution_first_call_transitions_unavailable", report["reasons"])
            else: self.assertTrue(report["claims"]["actionIdPreimageReconstructed"])

    def test_unsupported_outer_and_noncanonical_inputs_retained_as_partial(self):
        for role, key, value, suffix in ((1, "to", A(999), "outer_recipient_not_executor"),
                (1, "to", None, "outer_recipient_not_executor"),
                (1, "input", "0x12345678", "outer_selector_unsupported"),
                (2, "input", self.transcript["calls"][2]["result"]["input"] + "00", "unsupported_noncanonical_input")):
            transcript = copy.deepcopy(self.transcript); transcript["calls"][role]["result"][key] = value
            result = self.replay(transcript); report = result.report["reconstruction"]
            self.assertEqual(report["status"], "partial")
            self.assertIn(("schedule" if role == 1 else "execution") + "_" + suffix, report["reasons"])
            fragment = loads(dict(result.files)[capture.FRAGMENT_PATH], maximum=definition.MAX_BYTES)
            tx = loads(hex_bytes(fragment["transactions"]["schedule" if role == 1 else "execution"]["transactionBytes"]))
            self.assertEqual(tx[key], value)

    def test_absent_legacy_chain_field_is_not_invented(self):
        transcript = copy.deepcopy(self.transcript)
        for row in transcript["calls"][1:]: del row["result"]["chainId"]
        result = self.replay(transcript)
        fragment = loads(dict(result.files)[capture.FRAGMENT_PATH], maximum=definition.MAX_BYTES)
        self.assertEqual(fragment["chainBoundBy"], "source_anchor_and_block")
        self.assertEqual(result.report["reconstruction"]["status"], "reconstructed")
        for value in fragment["transactions"].values(): self.assertNotIn("chainId", loads(hex_bytes(value["transactionBytes"])))

    def test_reordered_missing_extra_transcript_rows_refuse(self):
        variants = []
        value = copy.deepcopy(self.transcript); value["calls"][1:] = reversed(value["calls"][1:]); variants.append(value)
        value = copy.deepcopy(self.transcript); value["calls"].pop(); variants.append(value)
        value = copy.deepcopy(self.transcript); value["calls"].append(value["calls"][0]); variants.append(value)
        for transcript in variants:
            with self.assertRaises(MuseumError): self.replay(transcript)

    def test_rehashed_derivatives_and_original_anchor_cannot_override_replay(self):
        for path in ("source/anchor.json", "source/snapshot.json", capture.FRAGMENT_PATH, "capture/report.json"):
            files = dict(self.result.files); value = loads(files[path], maximum=definition.MAX_BYTES)
            value["callerOverride"] = True; files[path] = dumps(value); files, digest = repin(files)
            with self.subTest(path=path), self.assertRaisesRegex(MuseumError, "reconstruction differs"):
                capture.verify(files, digest)

    def test_offline_cli_replay_verify_and_common_dispatch(self):
        from .package_v2 import verify_package
        with TemporaryDirectory() as temporary, patch("socket.socket", side_effect=AssertionError("offline only")):
            root = Path(temporary); native = root / "native"; write_tree(dict(self.native.files), native)
            tx = root / "transactions.json"; tx.write_bytes(dumps(self.transcript)); output = root / "capture"
            with redirect_stdout(io.StringIO()):
                capture.main(["replay", "--native", str(native), "--native-hash", self.native.manifest_hash,
                    "--source-profile-hash", source.PROFILE_HASH, "--transcript", str(tx),
                    "--transcript-hash", keccak256(tx.read_bytes()), "--provenance", "synthetic_fixture",
                    "--disclosure", "public", "--output", str(output)])
            self.assertEqual(read_tree(output), dict(self.result.files))
            self.assertEqual(verify_package(output, self.result.manifest_hash).files, self.result.files)

    def test_bad_original_pin_and_disclosure_precede_rpc(self):
        class NoRead:
            def request(self, *_): raise AssertionError("must validate inputs before RPC")
        with self.assertRaisesRegex(MuseumError, "external manifest pin"):
            source.PublicGovernanceTransactionSource(self.native.files, H(123456), NoRead())
        with self.assertRaisesRegex(MuseumError, "public disclosure"):
            capture.capture({}, H(1), source.PROFILE_HASH, NoRead(), disclosure="private")
        with self.assertRaisesRegex(MuseumError, "source profile"):
            capture.replay({}, H(1), H(2), b"", H(3), provenance="synthetic_fixture", disclosure="public")


if __name__ == "__main__": unittest.main()
