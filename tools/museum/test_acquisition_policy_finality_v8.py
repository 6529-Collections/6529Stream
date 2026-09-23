"""Complete-shape V8 from twelve actual synthetic source replays."""
from copy import deepcopy
from contextlib import redirect_stdout
import io
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from ..metadata import acquisition_packet_v5 as v5
from ..metadata import acquisition_packet_v8 as v8
from . import acquisition_policy_finality_v8 as assembly
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .policy_finality_fixture_v2 import PolicyFinalityFixtureV2
from .test_public_scoped_finality_capture import repin


class PolicyFinalityV8AssemblyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = PolicyFinalityFixtureV2()
        cls.inputs = cls.fixture.policy_inputs()
        cls.result = cls.compose(cls.inputs)

    @staticmethod
    def compose(inputs):
        return assembly.compose(*sum(([r.files, r.manifest_hash] for r in inputs), []), disclosure="public")

    def packet(self): return v8.validate(dict(self.result.files)[assembly.PACKET_PATH])

    def test_all_original_fields_files_and_captures_survive(self):
        files = dict(self.result.files)
        for path, raw in self.inputs[0].files:
            self.assertEqual(files[assembly.ORIGINAL_MANIFEST if path == "manifest.json" else path], raw)
        for path, raw in self.inputs[1].files:
            self.assertEqual(files[assembly.FINALITY_PREFIX + path], raw)
        old, new = v5.validate(files[assembly.previous.PACKET_PATH]), self.packet()
        self.assertEqual(set(old), set(new)); self.assertEqual(new["version"], 8)
        self.assertEqual(new["schema"], v8.PACKET)
        for key in old.keys() - {"schema", "version", "finality", "contentRootProof", "citation"}:
            self.assertEqual(new[key], old[key], key)
        self.assertEqual(keccak256(files[assembly.PACKET_PATH]), self.result.report["packetHash"])

    def test_native_policy_proof_original_citation_and_twelve_sources(self):
        packet = self.packet(); fragment = packet["finality"]["fragment"]
        self.assertEqual(packet["finality"]["kind"], "native_policy_collection_finality_v2")
        self.assertEqual(packet["contentRootProof"]["kind"], "native_policy_token_content_proof_v2")
        self.assertEqual(packet["contentRootProof"]["scope"], ["0", packet["sourceState"]["collectionId"], "0", v8.ZERO])
        self.assertEqual(packet["citation"]["qualifier"], {"kind": "fin", "hash": fragment["bundle"]["finality"]["record"][1]})
        self.assertEqual(len(fragment["definitions"]), 17)
        self.assertEqual(len(self.result.report["sourceReconciliation"]["inputs"]), 12)
        self.assertEqual(self.result.report["sourceReconciliation"]["counts"]["distinctOriginalTransactions"], "2")
        self.assertEqual(fragment["historicalCoreFacts"]["status"], "hash_only")

    def test_burn_preserves_original_collection_membership(self):
        fixture = PolicyFinalityFixtureV2(count=3, burned=True)
        result = self.compose(fixture.policy_inputs())
        packet = v8.validate(dict(result.files)[assembly.PACKET_PATH])
        self.assertTrue(packet["sourceState"]["burned"])
        self.assertEqual(packet["ownershipProvenance"]["currentOwner"], v8.ZERO_ADDRESS)
        self.assertEqual(packet["contentRootProof"]["leafCount"], "3")
        self.assertEqual(len(packet["finality"]["fragment"]["bundle"]["membership"]["tokens"]), 3)

    def test_independently_valid_capture_conflicting_header_rejects(self):
        fixture = deepcopy(self.fixture)
        fixture.blocks[fixture.policy_anchor["blockHash"]]["extraData"] = "0x1234"
        capture = fixture.policy_capture()
        self.assertEqual(assembly.finality.verify(capture.files, capture.manifest_hash).files, capture.files)
        with self.assertRaisesRegex(MuseumError, "RPC outcome|header .*differs"):
            assembly.compose(self.inputs[0].files, self.inputs[0].manifest_hash,
                capture.files, capture.manifest_hash, disclosure="public")

    def test_all_nineteen_items_and_explicit_refusal_of_complete_packet(self):
        report = self.result.report
        self.assertEqual([r["item"] for r in report["items"]], [str(i) for i in range(1, 20)])
        self.assertEqual(report["items"][2]["sourceCoverage"], "partial")
        self.assertIn("3", report["unresolvedSourceItems"])
        for key in ("completeAuthority", "sourceConsensusVerified", "actualChainAcceptance", "sourceCoverageComplete", "completeCanonicalPacket"):
            self.assertFalse(report["claims"][key])
        with self.assertRaisesRegex(MuseumError, "unresolved items"):
            assembly.complete_packet(self.result.files, self.result.manifest_hash)

    def test_rehashed_derivatives_and_manifest_overrides_reject(self):
        for path in (assembly.PACKET_PATH, "finality/assembly.json", "extra.json"):
            files = dict(self.result.files)
            value = loads(files[path], maximum=assembly.MAX_BYTES) if path in files else {}
            value["callerClaimsComplete"] = True; files[path] = dumps(value)
            files, digest = repin(files)
            with self.subTest(path=path), self.assertRaisesRegex(MuseumError, "reconstruction differs"):
                assembly.verify(files, digest)
        files = dict(self.result.files); manifest = loads(files["manifest.json"], maximum=assembly.MAX_MANIFEST)
        manifest["claims"] = {}; files["manifest.json"] = dumps(manifest)
        with self.assertRaisesRegex(MuseumError, "closed manifest"):
            assembly.verify(files, keccak256(files["manifest.json"]))
        with self.assertRaisesRegex(MuseumError, "external manifest pin"):
            assembly.verify(self.result.files, keccak256(b"wrong"))

    def test_pair_citation_and_unrelated_group_contradictions_reject(self):
        original = self.packet()
        for mode in ("proof_kind", "proof_root", "citation", "entropy", "rights"):
            packet = deepcopy(original)
            if mode == "proof_kind": packet["contentRootProof"]["kind"] = "native_scoped_token_content_proof"
            elif mode == "proof_root": packet["contentRootProof"]["root"] = keccak256(b"wrong")
            elif mode == "citation":
                digest = keccak256(b"wrong")
                packet["citation"]["qualifier"]["hash"] = digest
                packet["citation"]["qualified"] = packet["citation"]["work"] + "@fin:" + digest
            elif mode == "entropy": packet["entropy"]["leafHash"] = keccak256(b"wrong")
            else: packet["rights"]["completeness"] = "absent"
            with self.subTest(mode=mode), self.assertRaises(MuseumError): v8.validate(dumps(packet))

    def test_offline_exact_replay_export_and_common_dispatch(self):
        from .package_v2 import verify_package
        with patch("socket.socket", side_effect=AssertionError("offline only")):
            self.assertEqual(assembly.verify(self.result.files, self.result.manifest_hash).files, self.result.files)
            self.assertEqual(assembly.export_packet(self.result.files, self.result.manifest_hash), dict(self.result.files)[assembly.PACKET_PATH])
            with TemporaryDirectory() as temp:
                path = Path(temp) / "v8"; write_tree(dict(self.result.files), path)
                self.assertEqual(verify_package(path, self.result.manifest_hash).files, self.result.files)

    def test_disclosure_precedes_reads_and_atomic_cli_refuses_overwrite(self):
        class Unreadable:
            def __iter__(self): raise AssertionError("premature read")
        with self.assertRaisesRegex(MuseumError, "public disclosure"):
            assembly.compose(Unreadable(), "bad", Unreadable(), "bad", disclosure="private")
        with TemporaryDirectory() as temp, patch("socket.socket", side_effect=AssertionError("offline only")):
            root = Path(temp); paths = [root / "title", root / "capture"]
            for path, item in zip(paths, self.inputs): write_tree(dict(item.files), path)
            output = root / "v8"
            args = ["assemble", "--packet", str(paths[0]), "--packet-hash", self.inputs[0].manifest_hash,
                "--finality", str(paths[1]), "--finality-hash", self.inputs[1].manifest_hash,
                "--disclosure", "public", "--output", str(output)]
            with redirect_stdout(io.StringIO()): assembly.main(args)
            self.assertEqual(read_tree(output), dict(self.result.files))
            with self.assertRaises((MuseumError, FileExistsError)): assembly.main(args)
            self.assertEqual(read_tree(output), dict(self.result.files))


if __name__ == "__main__": unittest.main()
