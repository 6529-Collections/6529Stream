"""Synthetic full supplied V5 packets; source replay is not full-source acceptance."""
from contextlib import redirect_stdout
from copy import deepcopy
import io
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from ..metadata import acquisition_packet_v5 as definition
from ..metadata import genesis_dossier_profile as original_definition
from ..metadata.test_acquisition_packet_v5 import supplied
from . import acquisition_direct_conservation as direct_assembly
from . import acquisition_packet_v5 as assembly
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .direct_conservation_fixture import DirectConservationFixture
from .test_native_conservation_fixture import K


class AcquisitionPacketV5Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = DirectConservationFixture()
        inputs = cls.fixture.packages()
        cls.direct = direct_assembly.compose(*sum(([dict(value.files), value.manifest_hash] for value in inputs), []),
            disclosure="public")
        cls.packet = supplied(cls.direct)
        cls.packet_raw = dumps(cls.packet)
        cls.packet_hash = keccak256(cls.packet_raw)
        cls.result = cls.join(cls.packet)

    @classmethod
    def join(cls, packet):
        raw = dumps(packet)
        return assembly.compose(dict(cls.direct.files), cls.direct.manifest_hash, raw, keccak256(raw), disclosure="public")

    @staticmethod
    def repin(files):
        files = dict(files); manifest = loads(files["manifest.json"], maximum=32 * 1024 * 1024)
        manifest["files"] = [assembly.base._ref(path, raw) for path, raw in sorted(files.items()) if path != "manifest.json"]
        files["manifest.json"] = dumps(manifest)
        return files, keccak256(files["manifest.json"])

    def test_full_supplied_packet_and_original_assembly_bytes_are_preserved(self):
        files = dict(self.result.files)
        self.assertEqual(definition.validate(self.packet_raw), self.packet)
        self.assertEqual({path.removeprefix("direct-conservation/"): raw for path, raw in files.items()
            if path.startswith("direct-conservation/")}, dict(self.direct.files))
        self.assertEqual(files["inputs/supplied-packet.json"], self.packet_raw)
        self.assertEqual(files["packet/acquisition-packet.json"], self.packet_raw)
        self.assertEqual(self.result.report["packetHash"], self.packet_hash)
        self.assertEqual(self.packet["sourceState"], self.direct.report["fields"]["sourceState"])
        self.assertEqual(self.packet["conservation"]["kind"], "native_direct_conservation")
        direct_files = dict(self.direct.files)
        for value, path in ((self.packet["conservation"]["context"], "packet/conservation-context.json"),
                (self.packet["conservation"]["floor"], "direct-assembly/packet/native-direct-floor.json"),
                (self.packet["attribution"]["personhood"], "direct-assembly/packet/native-personhood.json")):
            self.assertEqual(dumps(value), direct_files[path])

    def test_all_nineteen_schema_fields_do_not_claim_all_nineteen_sources(self):
        report = self.result.report
        self.assertTrue(report["suppliedPacketValidated"])
        self.assertFalse(report["sourceCoverageComplete"])
        self.assertFalse(report["canonicalPacketReady"])
        self.assertEqual(report["sourceProvenance"], "synthetic_fixture")
        self.assertEqual([row["item"] for row in report["items"]], [str(index) for index in range(1, 20)])
        for row in report["items"]:
            self.assertTrue(row["suppliedFieldsValidated"])
            self.assertTrue(row["schemaCompatible"])
            self.assertEqual(row["fields"], original_definition.PACKET_REQUIREMENTS[row["item"]])
            expected = "derived_within_source_profile" if row["item"] in ("2", "7", "19") else \
                "partial" if row["item"] in ("5", "6", "10", "13") else "supplied_only"
            self.assertEqual(row["sourceCoverage"], expected)
        self.assertEqual(report["unresolvedSourceItems"], [str(index) for index in range(1, 20) if index not in (2, 7, 19)])
        self.assertTrue(report["claims"]["completeSuppliedPacketShape"])
        for key in ("fullPacketSourceCoverage", "completeCanonicalPacket", "nativeRuntimeAcceptance", "actualChainAcceptance", "networkFetch"):
            self.assertFalse(report["claims"][key], key)

    def test_native_source_reference_mutations_are_valid_supplied_data_but_not_exact_captures(self):
        for name in ("context", "floor", "personhood"):
            with self.subTest(fragment=name):
                value = deepcopy(self.packet)
                if name == "context": ref = value["conservation"]["context"]["sourceRefs"]["tier"]
                elif name == "floor": ref = value["conservation"]["floor"]["sourceRef"]
                else: ref = value["attribution"]["personhood"]["sourceRef"]
                ref["manifestHash"] = K("different supplied external commitment")
                self.assertEqual(definition.validate(dumps(value)), value)
                with self.assertRaisesRegex(MuseumError, "differs|mismatch"):
                    self.join(value)

    def test_current_attribution_mismatch_is_not_promoted_from_supplied_packet(self):
        for field, replacement in (("state", "claimed"), ("bindingGeneration", "2"), ("artistId", K("other Artist"))):
            with self.subTest(field=field):
                value = deepcopy(self.packet); value["attribution"][field] = replacement
                with self.assertRaises(MuseumError): self.join(value)

    def test_attribution_helper_rejects_generation_mismatch_between_two_retained_observations(self):
        # Isolate the helper's supplied observation relation. This namespace is
        # not a concrete capture and is never passed to compose/verify.
        report = deepcopy(self.direct.report)
        report["currentAttributionObservations"]["attribution"][1] = "2"
        value = deepcopy(self.packet); value["attribution"]["bindingGeneration"] = "2"
        with self.assertRaisesRegex(MuseumError, "generation|binding"):
            assembly._current_attribution(value, SimpleNamespace(report=report))

    def test_attribution_helper_none_state_remains_explicitly_unmapped(self):
        # Native NONE cannot establish the supplied label or platform status.
        report = deepcopy(self.direct.report)
        report["currentAttributionObservations"]["attribution"] = ["0", "0"]
        value = deepcopy(self.packet)
        value["attribution"].update(state="platform_works", bindingGeneration="0")
        observed = assembly._current_attribution(value, SimpleNamespace(report=report))
        self.assertTrue(observed["unmappedNativeState"])
        self.assertFalse(observed["platformWorksInferred"])
        self.assertNotIn("state", observed["matchedPacketFields"])
        self.assertEqual(observed["nativeState"], "0")

    def test_unrelated_legal_instrument_remains_supplied_only_even_when_exported(self):
        value = deepcopy(self.packet)
        value["legalInstrument"]["instrument"]["uri"] = "ipfs://different-supplied-instrument-without-retained-bytes"
        self.assertEqual(definition.validate(dumps(value)), value)
        result = self.join(value)
        self.assertEqual(result.report["items"][8]["sourceCoverage"], "supplied_only")
        self.assertFalse(result.report["sourceCoverageComplete"])
        self.assertEqual(assembly.export_supplied_packet(result.files, result.manifest_hash), dumps(value))

    def test_rights_selection_reference_is_relocated_without_new_evidence(self):
        expected = "direct-conservation/direct-assembly/provider-binding/rights-assembly/captures/rights/source/snapshot.json"
        reference = self.packet["rights"]["selectionEvidence"]
        self.assertEqual(reference["uri"], expected)
        self.assertEqual(reference["hash"]["digest"], keccak256(dict(self.result.files)[expected]))
        value = deepcopy(self.packet)
        value["rights"]["selectionEvidence"]["uri"] = "ipfs://caller-chosen-other-rights-source"
        self.assertEqual(definition.validate(dumps(value)), value)
        with self.assertRaisesRegex(MuseumError, "rights|RIGHTS"):
            self.join(value)

    def test_external_packet_and_assembly_pins_are_mandatory(self):
        for direct_hash, packet_hash in ((K("wrong"), self.packet_hash), (self.direct.manifest_hash, K("wrong"))):
            with self.assertRaises(MuseumError):
                assembly.compose(self.direct.files, direct_hash, self.packet_raw, packet_hash, disclosure="public")
        with self.assertRaises(MuseumError): assembly.verify(self.result.files, K("wrong"))
        with self.assertRaises(MuseumError): assembly.export_supplied_packet(self.result.files, K("wrong"))
        noncanonical = self.packet_raw + b"\n"
        with self.assertRaises(MuseumError):
            assembly.compose(self.direct.files, self.direct.manifest_hash, noncanonical, keccak256(noncanonical), disclosure="public")

    def test_rehashed_report_export_and_unexpected_payload_tamper_reject(self):
        for mode in ("report", "export", "extra"):
            with self.subTest(mode=mode):
                files = dict(self.result.files)
                if mode == "report":
                    path = "packet/assembly.json"; value = loads(files[path], maximum=1048576)
                    value["sourceCoverageComplete"] = True; files[path] = dumps(value)
                elif mode == "export":
                    value = deepcopy(self.packet)
                    value["legalInstrument"]["instrument"]["uri"] = "ipfs://replaced-after-admission"
                    files["packet/acquisition-packet.json"] = dumps(value)
                else: files["caller-full-proof.json"] = dumps({"allItemsComplete": True})
                files, digest = self.repin(files)
                with self.assertRaisesRegex(MuseumError, "reconstruction differs|commitments differ"):
                    assembly.verify(files, digest)

    def test_supplied_export_is_exact_but_complete_packet_refuses(self):
        with patch("socket.socket", side_effect=AssertionError("offline replay only")):
            self.assertEqual(assembly.export_supplied_packet(self.result.files, self.result.manifest_hash), self.packet_raw)
            self.assertEqual(assembly.verify(self.result.files, self.result.manifest_hash).files, self.result.files)
        with self.assertRaisesRegex(MuseumError, "complete.*packet|source.*coverage"):
            assembly.complete_packet(self.result.files, self.result.manifest_hash)

    def test_public_disclosure_is_checked_before_input_or_cli_path_reads(self):
        class Unreadable:
            def __iter__(self): raise AssertionError("input inspected before disclosure")
        with self.assertRaisesRegex(MuseumError, "public disclosure"):
            assembly.compose(Unreadable(), K("direct"), b"not read", K("packet"), disclosure="restricted")
        with patch.object(assembly, "read_tree", side_effect=AssertionError("path read before disclosure")):
            with self.assertRaisesRegex(MuseumError, "public disclosure"):
                assembly.main(["assemble", "--direct", "unread-direct", "--direct-hash", K("direct"),
                    "--packet", "unread-packet", "--packet-hash", K("packet"), "--disclosure", "restricted", "--output", "unread-output"])

    def test_offline_cli_common_dispatch_exact_export_and_no_overwrite(self):
        from .package_v2 import verify_package
        with TemporaryDirectory() as temporary:
            root = Path(temporary); source = root / "direct"; packet = root / "packet.json"; output = root / "assembled"
            write_tree(dict(self.direct.files), source); packet.write_bytes(self.packet_raw)
            args = ["assemble", "--direct", str(source), "--direct-hash", self.direct.manifest_hash,
                "--packet", str(packet), "--packet-hash", self.packet_hash, "--disclosure", "public", "--output", str(output)]
            stdout = io.StringIO()
            with patch("socket.socket", side_effect=AssertionError("offline replay only")), redirect_stdout(stdout):
                assembly.main(args)
                replay = verify_package(output, self.result.manifest_hash)
            self.assertEqual(replay.files, self.result.files)
            self.assertEqual(read_tree(output), dict(self.result.files))
            self.assertEqual(loads(stdout.getvalue().encode())["manifestHash"], self.result.manifest_hash)
            with self.assertRaisesRegex(MuseumError, "new directory"):
                assembly.main(args)
            self.assertEqual(read_tree(output), dict(self.result.files))
            with patch("socket.socket", side_effect=AssertionError("offline replay only")), redirect_stdout(io.StringIO()):
                assembly.main(["verify", str(output), "--manifest-hash", self.result.manifest_hash])
            exported = io.StringIO()
            with patch("socket.socket", side_effect=AssertionError("offline replay only")), redirect_stdout(exported):
                assembly.main(["export-supplied-packet", str(output), "--manifest-hash", self.result.manifest_hash])
            self.assertEqual(exported.getvalue().encode(), self.packet_raw)


if __name__ == "__main__": unittest.main()
