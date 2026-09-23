"""New native title export, full packet validation and original package retention."""
from contextlib import redirect_stdout
import io
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from ..metadata import acquisition_packet_v5 as definition
from . import acquisition_title_v5 as assembly
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .title_v5_fixture import TitleV5Fixture


def reindex(files):
    manifest = loads(files["manifest.json"], maximum=1048576)
    manifest["files"] = [assembly.base._ref(path, raw) for path, raw in sorted(files.items()) if path != "manifest.json"]
    files["manifest.json"] = dumps(manifest)
    return keccak256(files["manifest.json"])


class TitleAssemblyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = TitleV5Fixture()
        cls.inputs = cls.fixture.title_inputs()
        cls.result = cls.compose(cls.inputs)

    @staticmethod
    def compose(inputs):
        return assembly.compose(*sum(([row.files, row.manifest_hash] for row in inputs), []), disclosure="public")

    def packet(self): return definition.validate(dict(self.result.files)[assembly.PACKET_PATH])

    def test_new_validated_packet_and_all_original_bytes_survive_reconstruction(self):
        files = dict(self.result.files)
        for path, raw in self.inputs[0].files:
            self.assertEqual(files[assembly.ORIGINAL_MANIFEST if path == "manifest.json" else path], raw)
        for path, raw in self.inputs[1].files:
            self.assertEqual(files[assembly.ACCESSION_PREFIX + path], raw)
        self.assertEqual(assembly.verify(files, self.result.manifest_hash).files, self.result.files)
        packet = self.packet()
        self.assertNotEqual(files[assembly.PACKET_PATH], files["packet/acquisition-packet.json"])
        self.assertEqual(keccak256(files[assembly.PACKET_PATH]), self.result.report["packetHash"])
        self.assertEqual(keccak256(files["packet/acquisition-packet.json"]), self.result.report["originalPacketHash"])
        self.assertEqual(packet["legalInstrument"]["accession"]["recordHash"],
            self.inputs[1].report["selectedAccession"]["recordHash"])

    def test_unrelated_fields_and_referenced_rights_bytes_are_unchanged(self):
        files = dict(self.result.files)
        original = loads(files["packet/acquisition-packet.json"], maximum=definition.MAX_BYTES)
        packet = self.packet()
        self.assertEqual(set(original), set(packet))
        for key in original.keys() - {"legalInstrument", "ownershipProvenance", "recordChainHeads"}:
            self.assertEqual(packet[key], original[key], key)
        self.assertEqual(packet["ownershipProvenance"]["eventHistorySnapshot"],
            original["ownershipProvenance"]["eventHistorySnapshot"])
        self.assertEqual(keccak256(files[packet["rights"]["selectionEvidence"]["uri"]]),
            packet["rights"]["selectionEvidence"]["hash"]["digest"])

    def test_all_nineteen_coverage_rows_and_honest_native_boundaries(self):
        report = self.result.report
        self.assertEqual([row["item"] for row in report["items"]], [str(i) for i in range(1, 20)])
        self.assertEqual(report["items"][8]["sourceCoverage"], "derived_within_source_profile")
        self.assertEqual(report["items"][9]["sourceCoverage"], "partial")
        self.assertEqual(report["items"][4]["sourceCoverage"], "partial")
        self.assertNotIn("9", report["unresolvedSourceItems"])
        self.assertIn("10", report["unresolvedSourceItems"])
        for key in ("legalTitleProven", "institutionIdentityProven", "custodyTransferred",
                "sourceConsensusVerified", "sourceCoverageComplete", "canonicalLatestAccessionInferred"):
            self.assertFalse(report["claims"][key])
        self.assertFalse(report["canonicalPacketReady"])

    def test_eleven_sources_derive_collection_without_changing_owner_anchor(self):
        files = dict(self.result.files); join = self.result.report["sourceReconciliation"]
        self.assertEqual(len(join["inputs"]), 11)
        owner_path = assembly.ACCESSION_PREFIX + "sources/owner/anchor.json"
        anchor = loads(files[owner_path], maximum=1048576)
        self.assertNotIn("collectionId", anchor)
        self.assertEqual(join["sourceState"]["collectionId"], self.inputs[1].report["sourceState"]["collectionId"])
        self.assertEqual(join["inputs"][assembly.ACCESSION_PREFIX + "sources/owner/"]["anchorHash"],
            keccak256(files[owner_path]))

    def test_external_pins_and_public_disclosure_precede_input_reads(self):
        wrong = keccak256(b"wrong")
        with self.assertRaisesRegex(MuseumError, "external manifest pin"):
            assembly.verify(self.result.files, wrong)
        class Unreadable:
            def __iter__(self): raise AssertionError("read before disclosure")
        with self.assertRaisesRegex(MuseumError, "public disclosure"):
            assembly.compose(Unreadable(), wrong, Unreadable(), wrong, disclosure="restricted")
        with patch.object(assembly, "read_tree", side_effect=AssertionError("read before disclosure")):
            with self.assertRaisesRegex(MuseumError, "public disclosure"):
                assembly.main(["assemble", "--packet", "missing-packet", "--packet-hash", wrong,
                    "--accession", "missing-accession", "--accession-hash", wrong,
                    "--disclosure", "restricted", "--output", "missing-output"])

    def test_schema_valid_export_tamper_cannot_be_authenticated_by_outer_manifest(self):
        files = dict(self.result.files); packet = self.packet()
        packet["legalInstrument"]["instrument"]["uri"] = "https://example.invalid/forged-instrument"
        # A changed documentary locator is still schema-shaped, but is no longer
        # the original native ACCESSION payload and must fail source reconstruction.
        raw = dumps(packet); definition.validate(raw)
        files[assembly.PACKET_PATH] = raw
        with self.assertRaisesRegex(MuseumError, "reconstruction differs"):
            assembly.verify(files, reindex(files))

    def test_rehashed_report_claim_cannot_upgrade_coverage(self):
        files = dict(self.result.files)
        report = loads(files["title/assembly.json"], maximum=32 * 1024 * 1024)
        report["sourceCoverageComplete"] = True
        files["title/assembly.json"] = dumps(report)
        with self.assertRaisesRegex(MuseumError, "reconstruction differs"):
            assembly.verify(files, reindex(files))

    def test_rehashed_export_manifest_cannot_switch_back_to_original_packet(self):
        files = dict(self.result.files)
        manifest = loads(files["manifest.json"], maximum=1048576)
        manifest["exportedPacket"] = {"path": "packet/acquisition-packet.json", "hash": self.result.report["originalPacketHash"]}
        files["manifest.json"] = dumps(manifest)
        with self.assertRaisesRegex(MuseumError, "reconstruction differs"):
            assembly.verify(files, keccak256(files["manifest.json"]))

    def test_changed_original_input_remains_subject_to_its_own_manifest(self):
        files = dict(self.result.files)
        files[assembly.ACCESSION_PREFIX + "inputs/selection.json"] += b" "
        with self.assertRaises(MuseumError): assembly.verify(files, reindex(files))

    def test_closed_manifest_cannot_change_claims_or_profiles(self):
        for field, value in (("profileHash", keccak256(b"replacement")), ("claims", {"legalTitleProven": True}),
                ("extra", True)):
            with self.subTest(field=field):
                files = dict(self.result.files); manifest = loads(files["manifest.json"], maximum=1048576)
                manifest[field] = value; files["manifest.json"] = dumps(manifest)
                with self.assertRaisesRegex(MuseumError, "closed manifest"):
                    assembly.verify(files, keccak256(files["manifest.json"]))

    def test_offline_cli_common_dispatch_exact_new_export_and_no_overwrite(self):
        from .package_v2 import verify_package
        with TemporaryDirectory() as temporary:
            root = Path(temporary); paths = [root / role for role in ("packet", "accession")]
            output = root / "joined"; args = ["assemble"]
            for role, path, value in zip(("packet", "accession"), paths, self.inputs, strict=True):
                write_tree(dict(value.files), path)
                args += ["--" + role, str(path), "--" + role + "-hash", value.manifest_hash]
            args += ["--disclosure", "public", "--output", str(output)]
            with patch("socket.socket", side_effect=AssertionError("offline")), redirect_stdout(io.StringIO()):
                assembly.main(args)
                self.assertEqual(verify_package(output, self.result.manifest_hash).files, self.result.files)
                assembly.main(["verify", str(output), "--manifest-hash", self.result.manifest_hash])
            exported = io.StringIO()
            with patch("socket.socket", side_effect=AssertionError("offline")), redirect_stdout(exported):
                assembly.main(["export-packet", str(output), "--manifest-hash", self.result.manifest_hash])
            self.assertEqual(exported.getvalue().encode(), dict(self.result.files)[assembly.PACKET_PATH])
            with self.assertRaisesRegex(MuseumError, "complete source-covered canonical packet unavailable"):
                assembly.complete_packet(self.result.files, self.result.manifest_hash)
            with self.assertRaisesRegex(MuseumError, "new directory"): assembly.main(args)
            self.assertEqual(read_tree(output), dict(self.result.files))


if __name__ == "__main__": unittest.main()
