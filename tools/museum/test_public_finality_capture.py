"""Original source retention, bounded reads and adversarial offline reconstruction."""
import copy
from contextlib import redirect_stdout
import io
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import public_finality_capture as capture
from . import public_finality_source as source
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .finality_v6_fixture import FinalityV6Fixture


def repin(files):
    files = dict(files); manifest = loads(files["manifest.json"], maximum=1048576)
    manifest["files"] = [capture.base._ref(path, raw) for path, raw in sorted(files.items()) if path != "manifest.json"]
    files["manifest.json"] = dumps(manifest)
    return files, keccak256(files["manifest.json"])


class PublicFinalityCaptureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = FinalityV6Fixture()
        adapter = cls.fixture.finality_source()
        cls.snapshot_raw = adapter.snapshot(); transcript = adapter.transcript()
        cls.snapshot = loads(cls.snapshot_raw, maximum=source.MAX_OUTPUT)
        cls.inputs = (adapter.anchor_bytes, keccak256(adapter.anchor_bytes), source.PROFILE_HASH,
            transcript, keccak256(transcript))
        cls.result = capture.replay(*cls.inputs, provenance="synthetic_fixture", disclosure="public")

    def test_exact_original_triplet_definitions_and_native_fragment(self):
        files = dict(self.result.files)
        self.assertEqual(files["source/anchor.json"], self.inputs[0])
        self.assertEqual(files["source/transcript.json"], self.inputs[3])
        self.assertEqual(files["source/snapshot.json"], self.snapshot_raw)
        fragment = loads(files["native-finality/fragment.json"], maximum=source.MAX_OUTPUT)
        self.assertEqual(fragment["bundle"], self.snapshot["bundle"])
        self.assertEqual(fragment["sourceRef"]["snapshotHash"], keccak256(self.snapshot_raw))
        self.assertNotIn("captureManifestHash", fragment["sourceRef"])
        for row in source.wire.definitions(): self.assertEqual(files["definitions/native/" + row["name"] + ".json"], row["bytes"])

    def test_proof_and_original_core_facts_do_not_claim_full_authority(self):
        files = dict(self.result.files)
        proof = loads(files["native-finality/token-proof.json"])
        self.assertEqual(proof["leafIndex"], "2")
        self.assertEqual(proof["leafCount"], "3")
        source.wire.verify_proof(proof["leafHash"], 2, 3, proof["proof"], proof["root"])
        self.assertEqual(self.snapshot["historicalCoreFacts"]["status"], "hash_only")
        self.assertIsNone(self.snapshot["historicalCoreFacts"]["preimage"])
        for key in ("completeAuthority", "batchCallMetadataVerified", "executionTransactionInputCaptured",
                "historicalCoreFactsPreimageRecovered", "sourceConsensusVerified", "actualChainAcceptance", "completeCanonicalPacket"):
            self.assertFalse(self.result.report["claims"][key])

    def test_offline_replay_and_dispatch(self):
        from .package_v2 import verify_package
        with patch("socket.socket", side_effect=AssertionError("offline only")):
            self.assertEqual(capture.verify(self.result.files, self.result.manifest_hash).files, self.result.files)
            with TemporaryDirectory() as temporary:
                path = Path(temporary) / "capture"; write_tree(dict(self.result.files), path)
                self.assertEqual(verify_package(path, self.result.manifest_hash).files, self.result.files)

    def test_rehashed_generated_fields_cannot_replace_original_replay(self):
        for path in ("native-finality/fragment.json", "native-finality/token-proof.json", "source/snapshot.json", "capture/report.json", "extra.json"):
            with self.subTest(path=path):
                files = dict(self.result.files)
                value = {} if path not in files else loads(files[path], maximum=source.MAX_OUTPUT)
                value["callerClaimsComplete"] = True; files[path] = dumps(value)
                files, digest = repin(files)
                with self.assertRaisesRegex(MuseumError, "reconstruction differs"): capture.verify(files, digest)

    def test_external_pins_and_disclosure_precede_transport(self):
        wrong = keccak256(b"wrong")
        with self.assertRaisesRegex(MuseumError, "public disclosure"):
            capture.replay(*self.inputs, provenance="synthetic_fixture", disclosure="private")
        with self.assertRaisesRegex(MuseumError, "anchor pin"):
            capture.replay(self.inputs[0], wrong, *self.inputs[2:], provenance="synthetic_fixture", disclosure="public")
        with self.assertRaisesRegex(MuseumError, "source profile"):
            capture.replay(*self.inputs[:2], wrong, *self.inputs[3:], provenance="synthetic_fixture", disclosure="public")
        with self.assertRaisesRegex(MuseumError, "external manifest pin"): capture.verify(self.result.files, wrong)

    def test_source_rejects_admission_and_graph_pin_forgery_before_reads(self):
        for field in ("sourceCommit", "kind", "artifactHash"):
            anchor = loads(self.inputs[0]); anchor["runtimeAdmission"][field] = "wrong"
            with self.subTest(field=field), self.assertRaises(MuseumError):
                source.PublicFinalitySource(dumps(anchor), None)
        anchor = loads(self.inputs[0]); anchor["codePins"].append(copy.deepcopy(anchor["codePins"][0]))
        with self.assertRaisesRegex(MuseumError, "code pin"): source.PublicFinalitySource(dumps(anchor), None)

    def test_transcript_omission_extra_reads_and_original_bytes_corruption_reject(self):
        original = loads(self.inputs[3], maximum=source.MAX_OUTPUT)
        for mode in ("omit", "extra", "code"):
            transcript = copy.deepcopy(original)
            if mode == "omit": transcript["calls"].pop()
            elif mode == "extra": transcript["calls"].append(copy.deepcopy(transcript["calls"][-1]))
            else:
                row = next(row for row in transcript["calls"] if row["method"] == "eth_getCode")
                row["result"] = "0x00"
            raw = dumps(transcript)
            with self.subTest(mode=mode), self.assertRaises(MuseumError):
                capture.replay(*self.inputs[:3], raw, keccak256(raw), provenance="synthetic_fixture", disclosure="public")

    def test_source_uses_only_bounded_historical_reads(self):
        transcript = loads(self.inputs[3], maximum=source.MAX_OUTPUT)
        self.assertNotIn("eth_getTransactionByHash", {row["method"] for row in transcript["calls"]})
        forbidden = ("currentAction()", "computeCollectionCoreFactsHash(uint256)", "verifyFinality(uint256)", "requireCurrentManifest(bytes32,bytes32)")
        selectors = {"0x" + hex_bytes(keccak256(sig.encode()))[:4].hex() for sig in forbidden}
        for row in transcript["calls"]:
            if row["method"] == "eth_call": self.assertNotIn(row["params"][0]["data"][:10], selectors)

    def test_actual_getter_profile_completion_and_component_denominators_fail_closed(self):
        from .independent_wire import ZERO
        for mode in ("profile", "incomplete", "component_count", "original_binding"):
            fixture = copy.deepcopy(self.fixture); a = fixture.finality_addresses
            content = fixture.finality_bundle["content"]
            checkpoint = content["checkpoint"]
            if mode == "profile":
                fixture.add(a["checkpoint"], "checkpointProfile(bytes32)", ("bytes32",), (checkpoint["planHash"],),
                    ("bytes32",), (keccak256(b"unsupported STATIC or chunked profile"),))
            elif mode == "incomplete":
                plan = list(source.wire.from_json(source.wire.CHECKPOINT, checkpoint["plan"])); plan[2] -= 1
                fixture.add(a["checkpoint"], "checkpoint(bytes32)", ("bytes32",), (checkpoint["planHash"],),
                    (source.wire.CHECKPOINT,), (tuple(plan),))
            elif mode == "component_count":
                fixture.add(a["originalFinality"], "finalityComponentCount(uint256)", ("uint256",), (1,), ("uint256",), (9,))
            else:
                fixture.add(a["router"], "servingOriginalFinalityAnchor()", (), (), ("address", "bytes32"),
                    (a["originalFinality"], ZERO))
            with self.subTest(mode=mode), self.assertRaises(MuseumError): fixture.finality_source().snapshot()

    def test_native_carrier_and_store_bytes_are_both_required(self):
        fixture = copy.deepcopy(self.fixture)
        pointer = fixture.finality_bundle["content"]["artifact"]["chunks"][0]["pointer"]
        fixture.codes[pointer] = b"\0corrupted original carrier"
        with self.assertRaisesRegex(MuseumError, "carrier differs"): fixture.finality_source().snapshot()

    def test_original_core_adapter_must_bind_exact_native_counterparts(self):
        for getter, target in (("core", "core"), ("collectionMetadata", "host"), ("evidenceProvider", "contentProvider")):
            fixture = copy.deepcopy(self.fixture); a = fixture.finality_addresses
            fixture.add(a["coreAdapter"], getter + "()", (), (), ("address",), (a["router"],))
            with self.subTest(getter=getter), self.assertRaisesRegex(MuseumError, "reciprocal binding"):
                fixture.finality_source().snapshot()

    def test_original_event_omission_cannot_hide_behind_matching_getter(self):
        fixture = copy.deepcopy(self.fixture)
        topic = source.wire.EVENTS["root"]
        for receipt in fixture.receipts.values():
            receipt["logs"][:] = [row for row in receipt["logs"] if not row["topics"] or row["topics"][0] != topic]
        with self.assertRaises(MuseumError): fixture.finality_source().snapshot()

    def test_synthetic_burn_keeps_original_token_membership(self):
        result = FinalityV6Fixture(burned=True).finality_result()
        self.assertTrue(result["identity"]["burned"])
        self.assertEqual(result["identity"]["lifecycle"], "3")
        proof = source.wire.validate_bundle(result["bundle"], result["source"], result["graph"])["targetProof"]
        self.assertEqual(proof["leaf"][0], "41")

    def test_replay_cli_publishes_only_verified_originals(self):
        with TemporaryDirectory() as temporary, patch("socket.socket", side_effect=AssertionError("offline only")):
            root = Path(temporary); anchor, transcript, output = root / "anchor.json", root / "transcript.json", root / "capture"
            anchor.write_bytes(self.inputs[0]); transcript.write_bytes(self.inputs[3])
            with redirect_stdout(io.StringIO()):
                capture.main(["replay", "--anchor", str(anchor), "--anchor-hash", self.inputs[1], "--source-profile-hash", source.PROFILE_HASH,
                    "--transcript", str(transcript), "--transcript-hash", self.inputs[4], "--provenance", "synthetic_fixture",
                    "--disclosure", "public", "--output", str(output)])
            self.assertEqual(read_tree(output), dict(self.result.files))


if __name__ == "__main__": unittest.main()
