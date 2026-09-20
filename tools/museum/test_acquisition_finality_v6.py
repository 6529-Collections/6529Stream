"""Twelve-source original finality export with exact V5 retention and qualified coverage."""
from contextlib import redirect_stdout
import io
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from ..metadata import acquisition_packet_v5 as v5
from ..metadata import acquisition_packet_v6 as v6
from . import acquisition_finality_v6 as assembly
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .finality_v6_fixture import FinalityV6Fixture
from .test_public_finality_capture import repin


class FinalityV6AssemblyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = FinalityV6Fixture()
        cls.inputs = cls.fixture.finality_inputs()
        cls.result = cls.compose(cls.inputs)

    @staticmethod
    def compose(inputs):
        return assembly.compose(*sum(([row.files, row.manifest_hash] for row in inputs), []), disclosure="public")

    def packet(self): return v6.validate(dict(self.result.files)[assembly.PACKET_PATH])

    def test_new_native_v6_preserves_all_original_title_and_finality_files(self):
        files = dict(self.result.files)
        for path, raw in self.inputs[0].files:
            self.assertEqual(files[assembly.ORIGINAL_MANIFEST if path == "manifest.json" else path], raw)
        for path, raw in self.inputs[1].files: self.assertEqual(files[assembly.FINALITY_PREFIX + path], raw)
        old = v5.validate(files[assembly.previous.PACKET_PATH]); new = self.packet()
        self.assertEqual(set(old), set(new))
        self.assertEqual(new["schema"], v6.PACKET)
        self.assertEqual(new["version"], 6)
        for key in old.keys() - {"schema", "version", "finality", "contentRootProof", "citation"}:
            self.assertEqual(new[key], old[key], key)
        self.assertEqual(keccak256(files[assembly.previous.PACKET_PATH]), self.result.report["originalPacketHash"])
        self.assertEqual(keccak256(files[assembly.PACKET_PATH]), self.result.report["packetHash"])

    def test_original_native_finality_proof_and_fin_citation_are_paired(self):
        packet = self.packet()
        self.assertEqual(packet["finality"]["kind"], "native_collection_finality")
        self.assertEqual(packet["contentRootProof"]["kind"], "native_token_content_proof")
        fragment = packet["finality"]["fragment"]
        self.assertEqual(packet["citation"]["qualifier"], {"kind": "fin", "hash": fragment["bundle"]["finality"]["record"][1]})
        self.assertEqual(fragment["historicalCoreFacts"], {"status": "hash_only", "hash": fragment["historicalCoreFacts"]["hash"], "preimage": None})
        self.assertFalse(fragment["claims"]["completeAuthority"])

    def test_twelve_reconciled_sources_keep_owner_anchor_unmodified(self):
        report, files = self.result.report, dict(self.result.files)
        self.assertEqual(len(report["sourceReconciliation"]["inputs"]), 12)
        owner = assembly.previous.ACCESSION_PREFIX + "sources/owner/anchor.json"
        self.assertNotIn("collectionId", loads(files[owner]))
        self.assertEqual(report["sourceReconciliation"]["inputs"][assembly.FINALITY_PREFIX + "source/"]["anchorHash"],
            keccak256(files[assembly.FINALITY_PREFIX + "source/anchor.json"]))

    def test_nineteen_items_and_native_proof_do_not_inflate_source_completeness(self):
        report = self.result.report
        self.assertEqual([row["item"] for row in report["items"]], [str(i) for i in range(1, 20)])
        self.assertEqual(report["items"][2]["sourceCoverage"], "partial")
        self.assertIn("3", report["unresolvedSourceItems"])
        self.assertEqual(report["items"][8]["sourceCoverage"], "derived_within_source_profile")
        for key in ("sourceCoverageComplete", "sourceConsensusVerified", "actualChainAcceptance", "completeAuthority", "completeCanonicalPacket"):
            self.assertFalse(report["claims"][key])
        with self.assertRaisesRegex(MuseumError, "unresolved items"):
            assembly.complete_packet(self.result.files, self.result.manifest_hash)

    def test_offline_exact_replay_export_and_common_dispatch(self):
        from .package_v2 import verify_package
        with patch("socket.socket", side_effect=AssertionError("offline only")):
            self.assertEqual(assembly.verify(self.result.files, self.result.manifest_hash).files, self.result.files)
            self.assertEqual(assembly.export_packet(self.result.files, self.result.manifest_hash), dict(self.result.files)[assembly.PACKET_PATH])
            with TemporaryDirectory() as temporary:
                path = Path(temporary) / "assembly"; write_tree(dict(self.result.files), path)
                self.assertEqual(verify_package(path, self.result.manifest_hash).files, self.result.files)

    def test_rehashed_derivatives_cannot_override_reconstruction(self):
        for path in (assembly.PACKET_PATH, "finality/assembly.json", "extra.json"):
            with self.subTest(path=path):
                files = dict(self.result.files)
                value = {} if path not in files else loads(files[path], maximum=assembly.MAX_BYTES)
                value["completeAuthority"] = True; files[path] = dumps(value)
                files, digest = repin(files)
                with self.assertRaisesRegex(MuseumError, "reconstruction differs"): assembly.verify(files, digest)

    def test_manifest_claims_mode_extra_key_and_external_pin_reject(self):
        wrong = keccak256(b"wrong")
        with self.assertRaisesRegex(MuseumError, "external manifest pin"): assembly.verify(self.result.files, wrong)
        for key, value in (("mode", "acquisition_title_v5_assembly"), ("callerOverride", True), ("claims", {})):
            files = dict(self.result.files); manifest = loads(files["manifest.json"], maximum=1048576)
            manifest[key] = value; files["manifest.json"] = dumps(manifest)
            with self.subTest(key=key), self.assertRaisesRegex(MuseumError, "closed manifest"):
                assembly.verify(files, keccak256(files["manifest.json"]))

    def test_disclosure_precedes_input_directory_reads(self):
        class Unreadable:
            def __iter__(self): raise AssertionError("read before disclosure")
        wrong = keccak256(b"wrong")
        with self.assertRaisesRegex(MuseumError, "public disclosure"):
            assembly.compose(Unreadable(), wrong, Unreadable(), wrong, disclosure="restricted")
        with patch.object(assembly, "read_tree", side_effect=AssertionError("read before disclosure")):
            with self.assertRaisesRegex(MuseumError, "public disclosure"):
                assembly.main(["assemble", "--packet", "missing", "--packet-hash", wrong,
                    "--finality", "missing", "--finality-hash", wrong, "--disclosure", "private", "--output", "new"])

    def test_cli_assemble_and_export_reconstruct_exact_bytes(self):
        with TemporaryDirectory() as temporary, patch("socket.socket", side_effect=AssertionError("offline only")):
            root = Path(temporary); paths = (root / "title", root / "finality")
            for path, item in zip(paths, self.inputs): write_tree(dict(item.files), path)
            output = root / "v6"
            with redirect_stdout(io.StringIO()):
                assembly.main(["assemble", "--packet", str(paths[0]), "--packet-hash", self.inputs[0].manifest_hash,
                    "--finality", str(paths[1]), "--finality-hash", self.inputs[1].manifest_hash,
                    "--disclosure", "public", "--output", str(output)])
            self.assertEqual(read_tree(output), dict(self.result.files))
            capture = io.StringIO()
            with redirect_stdout(capture): assembly.main(["export-packet", str(output), "--manifest-hash", self.result.manifest_hash])
            self.assertEqual(capture.getvalue().encode("utf-8"), dict(self.result.files)[assembly.PACKET_PATH])


if __name__ == "__main__": unittest.main()
