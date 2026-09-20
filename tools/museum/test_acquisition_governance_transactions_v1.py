"""Whole V6 retention and additive original-governance evidence assembly."""
from contextlib import redirect_stdout
import io
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import acquisition_governance_transactions_v1 as assembly
from . import public_governance_transaction_capture as capture
from . import public_governance_transaction_source as source
from .bagit import write_tree, read_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .finality_governance_transaction_fixture import FinalityGovernanceTransactionFixture
from .test_public_finality_capture import repin


class GovernanceTransactionAssemblyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = FinalityGovernanceTransactionFixture(mode="batch")
        cls.inputs = cls.fixture.transaction_inputs()
        cls.result = cls.compose(cls.inputs)

    @staticmethod
    def compose(inputs):
        return assembly.compose(*sum(([row.files, row.manifest_hash] for row in inputs), []), disclosure="public")

    def test_original_v6_package_and_active_packet_are_byte_identical(self):
        files = dict(self.result.files)
        for path, raw in self.inputs[0].files:
            self.assertEqual(files[assembly.ORIGINAL_MANIFEST if path == "manifest.json" else path], raw)
        for path, raw in self.inputs[1].files: self.assertEqual(files[assembly.CAPTURE_PREFIX + path], raw)
        self.assertEqual(files[assembly.PACKET_PATH], dict(self.inputs[0].files)[assembly.PACKET_PATH])
        packet = loads(files[assembly.PACKET_PATH], maximum=assembly.MAX_BYTES)
        self.assertFalse(packet["finality"]["fragment"]["claims"]["batchCallMetadataVerified"])
        self.assertFalse(packet["finality"]["fragment"]["claims"]["completeAuthority"])
        self.assertTrue(self.result.report["reconstruction"]["claims"]["fullGovernanceCallMetadataReconstructed"])

    def test_complete_batch_and_actual_nonfirst_finality_call_keep_nineteen_items_partial(self):
        report = self.result.report
        self.assertEqual(report["reconstruction"]["status"], "reconstructed")
        self.assertEqual(report["reconstruction"]["finalityCall"]["index"], "1")
        self.assertEqual(len(report["reconstruction"]["calls"]), 2)
        self.assertEqual([row["item"] for row in report["items"]], [str(i) for i in range(1, 20)])
        self.assertEqual(report["items"][2]["sourceCoverage"], "partial")
        self.assertFalse(report["claims"]["completeAuthority"])
        with self.assertRaisesRegex(MuseumError, "unresolved items"):
            assembly.complete_packet(self.result.files, self.result.manifest_hash)

    def test_missing_schedule_batch_can_reconstruct_preimages_but_overall_stays_partial(self):
        captured = dict(self.inputs[1].files)
        transcript = loads(captured["source/transcript.json"]); transcript["calls"][1]["result"] = None
        raw = dumps(transcript)
        native = {path.removeprefix(capture.NATIVE_PREFIX): value for path, value in captured.items()
            if path.startswith(capture.NATIVE_PREFIX)}
        partial = capture.replay(native, self.inputs[1].report["nativeManifestHash"], source.PROFILE_HASH,
            raw, keccak256(raw), provenance="synthetic_fixture", disclosure="public")
        result = self.compose((self.inputs[0], partial))
        self.assertEqual(result.report["reconstruction"]["status"], "partial")
        self.assertTrue(result.report["reconstruction"]["claims"]["actionIdPreimageReconstructed"])
        self.assertFalse(result.report["reconstruction"]["claims"]["bothOriginalTransactionInputsDecoded"])

    def test_unrelated_native_capture_cannot_attach_to_v6(self):
        other = FinalityGovernanceTransactionFixture().transaction_capture()
        with self.assertRaisesRegex(MuseumError, "original native capture differs"):
            self.compose((self.inputs[0], other))

    def test_rehashed_reports_packet_changes_extra_files_cannot_override_originals(self):
        for path in (assembly.REPORT_PATH, assembly.PACKET_PATH, "extra.json"):
            files = dict(self.result.files)
            value = loads(files[path], maximum=assembly.MAX_BYTES) if path in files else {}
            value["completeAuthority"] = True; files[path] = dumps(value); files, digest = repin(files)
            with self.subTest(path=path), self.assertRaises(MuseumError): assembly.verify(files, digest)

    def test_offline_cli_export_and_common_dispatch(self):
        from .package_v2 import verify_package
        with TemporaryDirectory() as temporary, patch("socket.socket", side_effect=AssertionError("offline only")):
            root = Path(temporary); paths = (root / "v6", root / "capture")
            for path, item in zip(paths, self.inputs): write_tree(dict(item.files), path)
            output = root / "joined"
            with redirect_stdout(io.StringIO()):
                assembly.main(["assemble", "--packet", str(paths[0]), "--packet-hash", self.inputs[0].manifest_hash,
                    "--transactions", str(paths[1]), "--transactions-hash", self.inputs[1].manifest_hash,
                    "--disclosure", "public", "--output", str(output)])
            self.assertEqual(read_tree(output), dict(self.result.files))
            self.assertEqual(verify_package(output, self.result.manifest_hash).files, self.result.files)
            stdout = io.StringIO()
            with redirect_stdout(stdout): assembly.main(["export-packet", str(output), "--manifest-hash", self.result.manifest_hash])
            self.assertEqual(stdout.getvalue().encode(), dict(self.inputs[0].files)[assembly.PACKET_PATH])

    def test_disclosure_and_external_pin_refuse_before_intake(self):
        with self.assertRaisesRegex(MuseumError, "public disclosure"):
            assembly.compose({}, keccak256(b"a"), {}, keccak256(b"b"), disclosure="private")
        with self.assertRaisesRegex(MuseumError, "external manifest pin"):
            assembly.verify(self.result.files, keccak256(b"wrong"))


if __name__ == "__main__": unittest.main()
