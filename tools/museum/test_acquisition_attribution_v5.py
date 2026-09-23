"""Native source-backed V5 attribution joins and contradictory supplied claims."""
from contextlib import redirect_stdout
from copy import deepcopy
import io
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from ..metadata.test_acquisition_packet_v5 import supplied
from . import acquisition_attribution_v5 as assembly
from . import acquisition_direct_conservation as direct
from . import acquisition_packet_v5 as packet_v5
from . import public_attribution_capture as capture
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .independent_wire import ZERO
from .test_public_attribution_source import PublicAttributionFixture


def inputs(mode="accepted"):
    fixture = PublicAttributionFixture(mode=mode)
    adapter = fixture.source(); snapshot = loads(adapter.snapshot(), maximum=64 * 1024 * 1024)
    transcript = adapter.transcript()
    native = capture.replay(adapter.anchor_bytes, keccak256(adapter.anchor_bytes), capture._source().PROFILE_HASH,
        transcript, keccak256(transcript), provenance="synthetic_fixture", disclosure="public")
    components = fixture.packages()
    original = direct.compose(*sum(([dict(component.files), component.manifest_hash] for component in components), []), disclosure="public")
    packet = supplied(original)
    binding = packet["attribution"]["binding"]
    if binding["status"] == "present": binding["record"]["recordHash"] = snapshot["current"]["binding"][3]
    confirmation = snapshot["history"]["originalConfirmation"]
    digest = confirmation["recordHash"] if confirmation else snapshot["sanctions"]["latestAssociationHash"]
    if digest != ZERO:
        row = next(row for row in snapshot["sanctions"]["records"] if row["recordHash"] == digest)
        record = deepcopy(binding["record"])
        record.update(recordHash=digest, host=row["owner"], signer=row["record"][2], authorityClass=row["record"][3],
            recordedBlock=row["publication"]["blockNumber"], recordType=keccak256(b"ARTIST_SANCTION"),
            schemaId=keccak256(b"explicitly-supplied-generic-sanction-label"))
        packet["attribution"]["sanction"] = {"status": "present", "record": record}
    return original, native, packet, snapshot


def packet_assembly(original, packet):
    raw = dumps(packet)
    return packet_v5.compose(original.files, original.manifest_hash, raw, keccak256(raw), disclosure="public")


class AcquisitionAttributionV5Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.direct, cls.native, cls.packet, cls.snapshot = inputs("later_sanction")
        cls.previous = packet_assembly(cls.direct, cls.packet)
        cls.result = assembly.compose(cls.previous.files, cls.previous.manifest_hash,
            cls.native.files, cls.native.manifest_hash, disclosure="public")

    @classmethod
    def join(cls, packet):
        previous = packet_assembly(cls.direct, packet)
        return assembly.compose(previous.files, previous.manifest_hash, cls.native.files, cls.native.manifest_hash, disclosure="public")

    @staticmethod
    def repin(files):
        files = dict(files); manifest = loads(files["manifest.json"], maximum=1048576)
        manifest["files"] = [assembly.base._ref(path, raw) for path, raw in sorted(files.items()) if path != "manifest.json"]
        files["manifest.json"] = dumps(manifest)
        return files, keccak256(files["manifest.json"])

    def test_original_paths_bytes_and_six_plus_one_sources_are_preserved(self):
        actual = dict(self.result.files)
        for path, raw in self.previous.files:
            self.assertEqual(actual[assembly.ORIGINAL_MANIFEST if path == "manifest.json" else path], raw)
        for path, raw in self.native.files: self.assertEqual(actual[assembly.CAPTURE_PREFIX + path], raw)
        self.assertEqual(len(self.result.report["sourceReconciliation"]["inputs"]), 7)
        reference = self.packet["rights"]["selectionEvidence"]
        self.assertEqual(keccak256(actual[reference["uri"]]), reference["hash"]["digest"])
        self.assertEqual(assembly.export_supplied_packet(actual, self.result.manifest_hash), dumps(self.packet))

    def test_original_confirmation_wins_over_later_sanction_without_rewriting_either(self):
        joined = self.result.report["nativeAttributionJoin"]["sanction"]
        original = self.snapshot["history"]["originalConfirmation"]["recordHash"]
        self.assertEqual(joined["selectedRecordHash"], original)
        self.assertEqual(joined["selection"], "original_confirmation")
        self.assertNotEqual(original, joined["latestAssociationHash"])
        self.assertEqual(joined["matchedFields"], ["recordHash", "host", "signer", "authorityClass", "recordedBlock"])
        self.assertFalse(joined["genericTypeSchemaAndSubjectAuthenticated"])

    def test_replacing_confirmed_record_with_actual_latest_sanction_rejects(self):
        value = deepcopy(self.packet)
        latest = next(row for row in self.snapshot["sanctions"]["records"]
            if row["recordHash"] == self.snapshot["sanctions"]["latestAssociationHash"])
        value["attribution"]["sanction"]["record"].update(recordHash=latest["recordHash"], host=latest["owner"],
            signer=latest["record"][2], authorityClass=latest["record"][3], recordedBlock=latest["publication"]["blockNumber"])
        with self.assertRaisesRegex(MuseumError, "original sanction fields"):
            self.join(value)

    def test_supported_sanction_fields_and_binding_hash_are_mandatory(self):
        for field, wrong in (("recordHash", keccak256(b"other sanction")), ("host", "0x" + "aa" * 20),
                ("signer", "0x" + "ab" * 20), ("authorityClass", "3"), ("recordedBlock", "0")):
            with self.subTest(field=field):
                value = deepcopy(self.packet); value["attribution"]["sanction"]["record"][field] = wrong
                with self.assertRaisesRegex(MuseumError, "sanction fields"):
                    self.join(value)
        value = deepcopy(self.packet); value["attribution"]["binding"]["record"]["recordHash"] = keccak256(b"other binding")
        with self.assertRaisesRegex(MuseumError, "binding native identity"):
            self.join(value)

    def test_generic_record_labels_remain_supplied_without_native_authority_claim(self):
        value = deepcopy(self.packet)
        value["attribution"]["sanction"]["record"]["schemaId"] = keccak256(b"different supplied schema label")
        value["attribution"]["binding"]["record"]["host"] = "0x" + "ac" * 20
        result = self.join(value); join = result.report["nativeAttributionJoin"]
        self.assertEqual(join["binding"]["matchedFields"], ["recordHash"])
        self.assertFalse(join["binding"]["completeAuthorityAuthenticated"])
        self.assertFalse(join["sanction"]["genericTypeSchemaAndSubjectAuthenticated"])
        self.assertEqual(dict(result.files)["packet/acquisition-packet.json"], dumps(value))

    def test_accepted_and_restored_histories_keep_source_coverage_partial(self):
        for mode in ("accepted", "unconfirmed", "restored"):
            with self.subTest(mode=mode):
                original, native, packet, snapshot = inputs(mode)
                previous = packet_assembly(original, packet)
                result = assembly.compose(previous.files, previous.manifest_hash, native.files, native.manifest_hash, disclosure="public")
                join = result.report["nativeAttributionJoin"]["sanction"]
                if mode == "restored":
                    self.assertTrue(snapshot["history"]["restorations"])
                    self.assertEqual(join["selectedRecordHash"], snapshot["history"]["originalConfirmation"]["recordHash"])
                    self.assertNotEqual(join["selectedRecordHash"], snapshot["history"]["restorations"][-1]["recordHash"])
                elif mode == "unconfirmed":
                    self.assertIsNone(snapshot["history"]["originalConfirmation"])
                    self.assertEqual(join["selection"], "latest_unconfirmed")
                    self.assertEqual(join["selectedRecordHash"], snapshot["sanctions"]["latestAssociationHash"])
                    self.assertEqual(result.report["nativeAttributionJoin"]["nativeAttribution"][0], "2")
                else: self.assertEqual(join["selection"], "none_retained")
                self.assertEqual(len(result.report["items"]), 19)
                self.assertEqual(result.report["items"][5]["sourceCoverage"], "partial")
                self.assertFalse(result.report["sourceCoverageComplete"])

    def test_projection_rejects_absence_when_retained_native_records_exist(self):
        # Exercise the source join directly; accepted-packet schema rules are a separate guard.
        absent = {"status": "absent", "evidence": deepcopy(self.packet["rights"]["selectionEvidence"])}
        for key in ("binding", "sanction"):
            with self.subTest(field=key):
                value = deepcopy(self.packet); value["attribution"][key] = absent
                with self.assertRaisesRegex(MuseumError, "absence contradicts"):
                    assembly._bind(value, self.previous.report, self.snapshot)

    def test_projection_does_not_map_native_none_to_claimed_or_undeclared_platform(self):
        value, snapshot, previous = deepcopy(self.packet), deepcopy(self.snapshot), deepcopy(self.previous.report)
        empty = [ZERO, "0x" + "00" * 20, ZERO, ZERO, "0", "0", "0", "0", "0x" + "00" * 20, False]
        value["attribution"].update(artistId=None, bindingGeneration="0")
        value["attribution"]["personhood"]["current"]["binding"] = empty
        snapshot["current"].update(binding=empty, attribution=["0", "0"], platformDeclaration=[False, ZERO, "0"])
        previous["currentAttributionJoin"].update(nativeState="0", nativeGeneration="0", currentBinding=empty)
        for state in ("claimed", "platform_works"):
            value["attribution"]["state"] = state
            with self.assertRaisesRegex(MuseumError, "native NONE"):
                assembly._bind(value, previous, snapshot)

    def test_projection_refuses_invented_publication_for_missing_original_sanction_event(self):
        snapshot = deepcopy(self.snapshot)
        digest = snapshot["history"]["originalConfirmation"]["recordHash"]
        next(row for row in snapshot["sanctions"]["records"] if row["recordHash"] == digest)["publication"] = None
        with self.assertRaisesRegex(MuseumError, "publication unavailable"):
            assembly._bind(self.packet, self.previous.report, snapshot)

    def test_source_complete_refusal_and_rehashed_tamper(self):
        with self.assertRaisesRegex(MuseumError, "complete source-covered canonical packet unavailable"):
            assembly.complete_packet(self.result.files, self.result.manifest_hash)
        for path in ("attribution/native-join.json", assembly.ORIGINAL_MANIFEST, "packet/acquisition-packet.json"):
            with self.subTest(path=path):
                files = dict(self.result.files); value = loads(files[path], maximum=32 * 1024 * 1024)
                if path == "attribution/native-join.json": value["sanction"]["selection"] = "source_complete"
                elif path == assembly.ORIGINAL_MANIFEST: value["claims"]["completeCanonicalPacket"] = True
                else: value["legalInstrument"]["instrument"]["uri"] = "ipfs://replaced-export"
                files[path] = dumps(value); files, digest = self.repin(files)
                with self.assertRaises(MuseumError): assembly.verify(files, digest)

    def test_individually_replayable_capture_with_conflicting_receipt_rejects_join(self):
        files = dict(self.native.files)
        transcript = loads(files["source/transcript.json"], maximum=64 * 1024 * 1024)
        # Each source can replay this provider-supplied receipt, but their answers cannot disagree.
        for row in transcript["calls"]:
            if row["method"] == "eth_getTransactionReceipt": row["result"]["effectiveGasPrice"] = "0x2"
        raw = dumps(transcript); anchor = files["source/anchor.json"]
        contradictory = capture.replay(anchor, keccak256(anchor), capture._source().PROFILE_HASH,
            raw, keccak256(raw), provenance="synthetic_fixture", disclosure="public")
        self.assertEqual(capture.verify(contradictory.files, contradictory.manifest_hash).files, contradictory.files)
        with self.assertRaisesRegex(MuseumError, "repeated RPC outcome|repeated receipt"):
            assembly.compose(self.previous.files, self.previous.manifest_hash,
                contradictory.files, contradictory.manifest_hash, disclosure="public")

    def test_external_pins_and_disclosure_before_read(self):
        wrong = keccak256(b"wrong pin")
        with self.assertRaises(MuseumError): assembly.verify(self.result.files, wrong)
        for old_hash, native_hash in ((wrong, self.native.manifest_hash), (self.previous.manifest_hash, wrong)):
            with self.assertRaises(MuseumError):
                assembly.compose(self.previous.files, old_hash, self.native.files, native_hash, disclosure="public")
        class Unreadable:
            def __iter__(self): raise AssertionError("read before disclosure")
        with self.assertRaisesRegex(MuseumError, "public disclosure"):
            assembly.compose(Unreadable(), wrong, Unreadable(), wrong, disclosure="restricted")

    def test_offline_cli_dispatch_export_and_no_overwrite(self):
        from .package_v2 import verify_package
        with TemporaryDirectory() as temporary:
            root = Path(temporary); old = root / "packet"; native = root / "native"; output = root / "joined"
            write_tree(dict(self.previous.files), old); write_tree(dict(self.native.files), native)
            args = ["assemble", "--packet", str(old), "--packet-hash", self.previous.manifest_hash,
                "--attribution", str(native), "--attribution-hash", self.native.manifest_hash,
                "--disclosure", "public", "--output", str(output)]
            with patch("socket.socket", side_effect=AssertionError("offline")), redirect_stdout(io.StringIO()):
                assembly.main(args)
                self.assertEqual(verify_package(output, self.result.manifest_hash).files, self.result.files)
            exported = io.StringIO()
            with patch("socket.socket", side_effect=AssertionError("offline")), redirect_stdout(exported):
                assembly.main(["export-supplied-packet", str(output), "--manifest-hash", self.result.manifest_hash])
            self.assertEqual(exported.getvalue().encode(), dumps(self.packet))
            with self.assertRaisesRegex(MuseumError, "new directory"): assembly.main(args)
            self.assertEqual(read_tree(output), dict(self.result.files))


if __name__ == "__main__": unittest.main()
