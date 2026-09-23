"""Synthetic original scoped captures: exact replay, retained bytes and bounded CLI."""
import copy
from contextlib import redirect_stdout
import io
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import public_scoped_finality_capture as capture
from . import public_scoped_finality_source as source
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .scoped_static_finality_fixture import ScopedStaticFinalityFixture


def repin(files):
    files = dict(files)
    manifest = loads(files["manifest.json"], maximum=1048576)
    manifest["files"] = [capture.base._ref(path, raw) for path, raw in sorted(files.items()) if path != "manifest.json"]
    files["manifest.json"] = dumps(manifest)
    return files, keccak256(files["manifest.json"])


class PublicScopedFinalityCaptureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = ScopedStaticFinalityFixture()
        adapter = cls.fixture.scoped_source()
        cls.snapshot_raw = adapter.snapshot()
        transcript = adapter.transcript()
        cls.snapshot = loads(cls.snapshot_raw, maximum=source.MAX_OUTPUT)
        cls.inputs = (adapter.anchor_bytes, keccak256(adapter.anchor_bytes), source.PROFILE_HASH,
            transcript, keccak256(transcript))
        cls.result = capture.replay(*cls.inputs, provenance="synthetic_fixture", disclosure="public")

    def test_original_triplet_and_nine_definitions_retained_without_projection(self):
        files = dict(self.result.files)
        self.assertEqual(files["source/anchor.json"], self.inputs[0])
        self.assertEqual(files["source/transcript.json"], self.inputs[3])
        self.assertEqual(files["source/snapshot.json"], self.snapshot_raw)
        fragment = loads(files["scoped-finality/fragment.json"], maximum=source.MAX_OUTPUT)
        self.assertEqual(fragment["bundle"], self.snapshot["bundle"])
        self.assertEqual(fragment["sourceRef"]["snapshotHash"], keccak256(self.snapshot_raw))
        self.assertNotIn("captureManifestHash", fragment["sourceRef"])
        self.assertEqual(len(source.wire.definitions()), 9)
        for row in source.wire.definitions():
            self.assertEqual(files["definitions/native/" + row["name"] + ".json"], row["bytes"])

    def test_scoped_proof_keeps_hash_only_execution_and_authority_qualifications(self):
        proof = loads(dict(self.result.files)["scoped-finality/token-proof.json"])
        self.assertEqual(proof["kind"], "native_scoped_token_content_proof")
        self.assertEqual(proof["leaf"][0], self.snapshot["source"]["tokenId"])
        self.assertEqual(proof["leafCount"], str(len(self.snapshot["bundle"]["membership"]["tokens"])))
        source.neutral.verify_proof(proof["leafHash"], int(proof["leafIndex"]), int(proof["leafCount"]),
            proof["proof"], proof["root"])
        self.assertEqual(self.snapshot["historicalCoreFacts"]["status"], "hash_only")
        self.assertIsNone(self.snapshot["historicalCoreFacts"]["preimage"])
        for key in ("completeAuthority", "historicalCoreFactsPreimageRecovered", "sourceConsensusVerified",
                "actualChainAcceptance", "completeCanonicalPacket", "currentArchiveLivenessChecked"):
            self.assertFalse(self.result.report["claims"][key])
        self.assertEqual(self.result.report["provenance"], "synthetic_fixture")

    def test_union_transcript_keeps_both_original_transactions_and_historical_reads(self):
        transcript = loads(self.inputs[3], maximum=source.MAX_OUTPUT)
        transactions = [row for row in transcript["calls"] if row["method"] == "eth_getTransactionByHash"]
        self.assertEqual(len(transactions), 2)
        self.assertTrue(all(row["result"] is not None for row in transactions))
        self.assertIn("eth_getLogs", {row["method"] for row in transcript["calls"]})
        forbidden = ("currentAction()", "computeCollectionCoreFactsHash(uint256)",
            "verifyFinality(uint256)", "requireCurrentManifest(bytes32,bytes32)")
        selectors = {"0x" + hex_bytes(keccak256(sig.encode()))[:4].hex() for sig in forbidden}
        for row in transcript["calls"]:
            if row["method"] == "eth_call": self.assertNotIn(row["params"][0]["data"][:10], selectors)

    def test_union_reconciliation_allows_exact_repeats_and_rejects_transaction_conflicts(self):
        from .scoped_finality_observations import reconcile
        rows = loads(self.inputs[3], maximum=source.MAX_OUTPUT)["calls"]
        transaction = next(row for row in rows if row["method"] == "eth_getTransactionByHash")
        pins = {row["address"]: row["runtimeHash"] for row in loads(self.inputs[0])["codePins"]}
        result = reconcile(self.snapshot["source"], {"source": rows, "exact_repeat": [transaction]}, pins)
        self.assertEqual(result["originalTransactionRows"], "3")
        self.assertEqual(result["distinctOriginalTransactions"], "2")
        changed = copy.deepcopy(transaction); changed["result"]["input"] += "00"
        with self.assertRaisesRegex(MuseumError, "original transaction observation differs"):
            reconcile(self.snapshot["source"], {"source": rows, "contradiction": [changed]}, pins)

    def test_three_original_scopes_and_later_burn_preserve_native_membership(self):
        for kind, count, burned in ((1, 1, True), (2, 3, False), (3, 30, False)):
            with self.subTest(scope=kind, burned=burned):
                fixture = ScopedStaticFinalityFixture(scope_type=kind, count=count, burned=burned)
                result = fixture.scoped_capture()
                files = dict(result.files)
                snapshot = loads(files["source/snapshot.json"], maximum=source.MAX_OUTPUT)
                proof = loads(files["scoped-finality/token-proof.json"])
                self.assertEqual(proof["scope"][0], str(kind))
                self.assertEqual(proof["leafCount"], str(count))
                self.assertEqual(snapshot["identity"]["burned"], burned)
                self.assertEqual(snapshot["identity"]["lifecycle"], "3" if burned else "2")
                self.assertEqual(proof["leaf"][0], snapshot["identity"]["tokenId"])
                if kind == 3:
                    self.assertGreater(len(snapshot["bundle"]["content"]["manifest"]["chunks"]), 1)
                self.assertEqual(capture.verify(result.files, result.manifest_hash).files, result.files)

    def test_pruned_and_indirect_transaction_inputs_remain_explicit_partial(self):
        for mode in ("pruned", "indirect", "noncanonical"):
            fixture = copy.deepcopy(self.fixture)
            for digest, tx in fixture.scoped_transactions.items():
                if mode == "pruned": fixture.scoped_transactions[digest] = None
                elif mode == "indirect":
                    # The original outer target is an observation, not an inner
                    # Executor call or a decoded Safe signer proof.
                    tx["to"] = fixture.scoped_addresses["roles"]
                    fixture.receipts[digest]["to"] = tx["to"]
                else: tx["input"] += "00"  # Solidity may accept a tail; this profile preserves it as partial.
            with self.subTest(mode=mode):
                result = fixture.scoped_capture()
                snapshot = loads(dict(result.files)["source/snapshot.json"], maximum=source.MAX_OUTPUT)
                self.assertEqual(snapshot["reconstruction"]["status"], "partial")
                self.assertFalse(snapshot["reconstruction"]["claims"]["bothOriginalTransactionInputsDecoded"])
                self.assertEqual(capture.verify(result.files, result.manifest_hash).files, result.files)

    def test_coherently_rehashed_inventory_configuration_cannot_bind_wrong_role(self):
        from .chain_abi import calldata, decode, encode
        fixture = copy.deepcopy(self.fixture); a = fixture.scoped_addresses
        d = decode((source.INVENTORY_DEPENDENCIES,), hex_bytes(fixture.responses[(a["renderCriticalInventory"], calldata("dependencies()"))]))[0]
        c = decode((source.wire.PROVIDER_CONFIG,), hex_bytes(fixture.responses[(a["provider"], calldata("scopedConfiguration()"))]))[0]
        addresses = list(d[0]); pins = list(d[1])
        addresses[0], pins[0] = a["metadata"], fixture.pins[a["metadata"]]
        d = (tuple(addresses), tuple(pins), *d[2:])
        digest = keccak256(encode((source.INVENTORY_DEPENDENCIES,), (d,)))
        fixture.add(a["renderCriticalInventory"], "dependencies()", (), (), (source.INVENTORY_DEPENDENCIES,), (d,))
        fixture.add(a["renderCriticalInventory"], "dependencyHash()", (), (), ("bytes32",), (digest,))
        fixture.add(a["provider"], "scopedConfiguration()", (), (), (source.wire.PROVIDER_CONFIG,), ((*c[:6], digest),))
        with self.assertRaisesRegex(MuseumError, "inventory dependency structure"):
            fixture.scoped_source().snapshot()

    def test_offline_exact_replay_and_common_dispatch(self):
        from .package_v2 import verify_package
        with patch("socket.socket", side_effect=AssertionError("offline only")):
            self.assertEqual(capture.verify(self.result.files, self.result.manifest_hash).files, self.result.files)
            with TemporaryDirectory() as temporary:
                path = Path(temporary) / "capture"
                write_tree(dict(self.result.files), path)
                self.assertEqual(verify_package(path, self.result.manifest_hash).files, self.result.files)

    def test_rehashed_derivatives_cannot_replace_original_replay(self):
        for path in ("scoped-finality/fragment.json", "scoped-finality/token-proof.json", "source/snapshot.json",
                "capture/report.json", "extra.json"):
            with self.subTest(path=path):
                files = dict(self.result.files)
                value = {} if path not in files else loads(files[path], maximum=source.MAX_OUTPUT)
                value["callerClaimsComplete"] = True
                files[path] = dumps(value)
                files, digest = repin(files)
                with self.assertRaisesRegex(MuseumError, "reconstruction differs"):
                    capture.verify(files, digest)

    def test_closed_manifest_and_external_pins(self):
        wrong = keccak256(b"wrong")
        with self.assertRaisesRegex(MuseumError, "anchor pin"):
            capture.replay(self.inputs[0], wrong, *self.inputs[2:], provenance="synthetic_fixture", disclosure="public")
        with self.assertRaisesRegex(MuseumError, "source profile"):
            capture.replay(*self.inputs[:2], wrong, *self.inputs[3:], provenance="synthetic_fixture", disclosure="public")
        with self.assertRaisesRegex(MuseumError, "external manifest pin"):
            capture.verify(self.result.files, wrong)
        for key, value in (("callerOverride", True), ("claims", {}), ("mode", "public_finality_capture")):
            files = dict(self.result.files)
            manifest = loads(files["manifest.json"], maximum=1048576)
            manifest[key] = value; files["manifest.json"] = dumps(manifest)
            with self.subTest(key=key), self.assertRaisesRegex(MuseumError, "closed manifest"):
                capture.verify(files, keccak256(files["manifest.json"]))

    def test_transcript_omission_extra_code_and_transaction_tamper_fail_closed(self):
        original = loads(self.inputs[3], maximum=source.MAX_OUTPUT)
        for mode in ("omit", "extra", "code", "transaction"):
            transcript = copy.deepcopy(original)
            if mode == "omit": transcript["calls"].pop()
            elif mode == "extra": transcript["calls"].append(copy.deepcopy(transcript["calls"][-1]))
            elif mode == "code":
                next(row for row in transcript["calls"] if row["method"] == "eth_getCode")["result"] = "0x00"
            else:
                row = next(row for row in transcript["calls"] if row["method"] == "eth_getTransactionByHash")
                row["result"]["blockHash"] = keccak256(b"different transaction block")
            raw = dumps(transcript)
            with self.subTest(mode=mode), self.assertRaises(MuseumError):
                capture.replay(*self.inputs[:3], raw, keccak256(raw), provenance="synthetic_fixture", disclosure="public")

    def test_disclosure_precedes_paths_environment_and_transport(self):
        wrong = keccak256(b"wrong")
        with self.assertRaisesRegex(MuseumError, "public disclosure"):
            capture.replay(None, wrong, wrong, None, wrong, provenance="synthetic_fixture", disclosure="private")
        with patch.object(capture, "_read_input", side_effect=AssertionError("read before disclosure")):
            with self.assertRaisesRegex(MuseumError, "public disclosure"):
                capture.main(["capture", "--anchor", "missing", "--anchor-hash", wrong,
                    "--source-profile-hash", wrong, "--rpc-env", "MUSEUM_TEST_RPC", "--disclosure", "private", "--output", "new"])

    def test_capture_cli_rejects_synthetic_admission_before_rpc_endpoint(self):
        original_get = capture.os.environ.get
        def guarded(key, *args):
            if key == "MUSEUM_TEST_RPC": raise AssertionError("RPC environment read before source validation")
            return original_get(key, *args)
        with TemporaryDirectory() as temporary:
            root = Path(temporary); anchor = root / "anchor.json"
            anchor.write_bytes(self.inputs[0])
            with patch.object(capture.os.environ, "get", side_effect=guarded):
                with self.assertRaisesRegex(MuseumError, "runtime admission"):
                    capture.main(["capture", "--anchor", str(anchor), "--anchor-hash", self.inputs[1],
                        "--source-profile-hash", source.PROFILE_HASH, "--rpc-env", "MUSEUM_TEST_RPC",
                        "--disclosure", "public", "--output", str(root / "capture")])

    def test_read_only_capture_boundary_replays_actual_synthetic_responses(self):
        anchor = loads(self.inputs[0])
        anchor["runtimeAdmission"]["kind"] = "externally_admitted_runtime"
        raw = dumps(anchor)
        transport = capture.PublicRpcTransport("https://example.invalid/never-requested")
        with patch.object(transport, "request", side_effect=self.fixture.request), \
                patch("socket.socket", side_effect=AssertionError("synthetic mechanics only")):
            result = capture.capture(raw, keccak256(raw), source.PROFILE_HASH, transport, disclosure="public")
        self.assertEqual(result.report["provenance"], "trusted_rpc")
        self.assertFalse(result.report["claims"]["actualChainAcceptance"])
        self.assertEqual(loads(dict(result.files)["source/anchor.json"])["environment"], anchor["environment"])
        self.assertEqual(loads(dict(result.files)["source/anchor.json"])["runtimeAdmission"]["artifactHash"],
            loads(self.inputs[0])["runtimeAdmission"]["artifactHash"])

    def test_replay_cli_publishes_only_verified_originals_and_refuses_reuse(self):
        with TemporaryDirectory() as temporary, patch("socket.socket", side_effect=AssertionError("offline only")):
            root = Path(temporary); anchor, transcript, output = root / "anchor.json", root / "transcript.json", root / "capture"
            anchor.write_bytes(self.inputs[0]); transcript.write_bytes(self.inputs[3])
            args = ["replay", "--anchor", str(anchor), "--anchor-hash", self.inputs[1],
                "--source-profile-hash", source.PROFILE_HASH, "--transcript", str(transcript),
                "--transcript-hash", self.inputs[4], "--provenance", "synthetic_fixture",
                "--disclosure", "public", "--output", str(output)]
            with redirect_stdout(io.StringIO()): capture.main(args)
            self.assertEqual(read_tree(output), dict(self.result.files))
            with self.assertRaises((MuseumError, FileExistsError)): capture.main(args)
            self.assertEqual(read_tree(output), dict(self.result.files))


if __name__ == "__main__": unittest.main()
