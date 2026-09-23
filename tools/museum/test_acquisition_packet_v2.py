"""Synthetic packet-V2 assembly controls; no actual-chain or legal-title claim."""
from copy import deepcopy
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from jsonschema import Draft202012Validator
from jsonschema.exceptions import ValidationError

from ..metadata import acquisition_packet_v2 as definition
from ..metadata import genesis_dossier_profile as v1
from . import acquisition_accession as acquisition
from . import acquisition_packet_v2 as packet
from .canonical import MuseumError, dumps, keccak256, loads
from .package import write_package
from .package_v2 import verify_package
from .test_acquisition_accession import JoinedFixture, OWNER_A, OWNER_B, OWNER_C
from .independent_wire import ZERO_ADDRESS
from .test_owner_catalog_source import H


class PriorSelfTransferFixture(JoinedFixture):
    """Put a B->B hop between the declared A->B title hop and publication."""

    def _append_owner(self, family, schema, value, block, author, relayed):
        if (family == "ACCESSION" and isinstance(value, dict)
                and value.get("recordId") == "urn:test:accession:selected"
                and not getattr(self, "_inserted_prior_self", False)):
            self._inserted_prior_self = True
            self._transfer(3, OWNER_B, OWNER_B)
        return super()._append_owner(family, schema, value, block, author, relayed)


class BurnedAfterDocumentationFixture(JoinedFixture):
    """Burn after every documentary publication without rewriting history."""

    def __init__(self):
        super().__init__()
        self._transfer(5, OWNER_C, ZERO_ADDRESS)
        self.call("tokenCollectionIdentity(uint256)", ("bool", "uint256", "uint256", "bool"),
            (True, 6, 1, True), ("uint256",), (71,), target=self.a["core"])
        self.call("tokenLifecycle(uint256)", ("uint8",), (3,), ("uint256",), (71,), target=self.a["core"])


def acquisition_package(fixture=None):
    fixture = fixture or JoinedFixture()
    owner_files, owner_pins, ownership_files, ownership_pins, selection, documents = fixture.artifacts()
    result = acquisition.compose(owner_files, owner_pins, ownership_files, ownership_pins,
        selection, keccak256(selection), disclosure="public", documents=documents)
    return fixture, result


def assembled(fixture=None):
    fixture, source = acquisition_package(fixture)
    result = packet.compose(source.files, source.manifest_hash, disclosure="public",
        packet_schema_hash=definition.PACKET_SCHEMA_HASH, authority_profile_hash=definition.PROFILE_HASH)
    return fixture, source, result


class AcquisitionPacketV2Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture, cls.source, cls.result = assembled()

    def test_v2_discriminator_explicit_definition_pins_and_v1_immutability(self):
        manifest = loads(self.result.manifest, maximum=1048576)
        self.assertEqual((manifest["mode"], manifest["version"], manifest["packetSchemaHash"],
            manifest["authorityProfileHash"]), (packet.MODE, "2", definition.PACKET_SCHEMA_HASH,
            definition.PROFILE_HASH))
        self.assertEqual(definition.V1_PACKET_SCHEMA_HASH,
            keccak256((v1.ROOT / "schemas/records/STREAM_ACQUISITION_PACKET_V1.json").read_bytes()))
        self.assertEqual(definition.V1_OBJECT_SCHEMA_HASH,
            keccak256((v1.ROOT / "schemas/records/STREAM_OBJECT_DOSSIER_V1.json").read_bytes()))
        for schema_hash, authority_hash in ((definition.V1_PACKET_SCHEMA_HASH, definition.PROFILE_HASH),
                (definition.PACKET_SCHEMA_HASH, H("wrong-authority"))):
            with self.subTest(schema=schema_hash, authority=authority_hash), \
                    self.assertRaisesRegex(MuseumError, "schema/authority profile pins"):
                packet.compose(self.source.files, self.source.manifest_hash, disclosure="public",
                    packet_schema_hash=schema_hash, authority_profile_hash=authority_hash)

    def test_native_owner_fragment_commits_exact_relayed_source_bytes_without_numeric_class(self):
        files = dict(self.result.files); fragment = loads(files["packet/legal-instrument.json"])
        record = fragment["accession"]; authority = record["authority"]
        self.assertNotIn("authorityClass", record)
        self.assertEqual((authority["kind"], authority["version"], record["signer"]),
            ("native_owner_receipt", "1", authority["receipt"]["owner"]))
        self.assertTrue(authority["receipt"]["relayed"])
        self.assertNotEqual(authority["receipt"]["authorizationDigest"], "0x" + "00" * 32)
        digest = self.fixture.selected[2:]
        original = files["acquisition/records/" + digest + "/original.json"]
        payload = files["acquisition/records/" + digest + "/payload.bin"]
        bundle = files["acquisition/records/" + digest + "/signature-bundle.bin"]
        provenance = authority["provenance"]
        self.assertEqual((provenance["originalRecordBytesHash"], provenance["originalPayloadBytesHash"],
            provenance["signatureBundleBytesHash"]), (keccak256(original), keccak256(payload), keccak256(bundle)))
        self.assertEqual(authority["receipt"]["signatureBundleHash"], keccak256(bundle))
        self.assertEqual(provenance["acquisitionManifestHash"], self.source.manifest_hash)
        self.assertNotEqual(provenance["originalRecordBytesHash"], record["recordHash"])
        self.assertEqual(authority["ownerState"]["sourceBlockTimestamp"],
            self.source.report["sourceState"]["timestamp"])

    def test_owner_state_uses_last_prepublication_hop_not_declared_title_hop(self):
        fixture, _, result = assembled(PriorSelfTransferFixture())
        fragment = loads(dict(result.files)["packet/legal-instrument.json"])
        declared = loads(dict(result.files)["acquisition/accession/selected.json"])["titleBinding"]["declared"]
        state = fragment["accession"]["authority"]["ownerState"]
        self.assertEqual((declared["from"], declared["to"], declared["logIndex"]), (OWNER_A, OWNER_B, "0"))
        self.assertEqual((state["transferIndex"], state["transfer"]["from"], state["transfer"]["to"],
            state["transfer"]["logIndex"]), ("2", OWNER_B, OWNER_B, "1"))
        self.assertEqual(fragment["accession"]["signer"], OWNER_B)
        self.assertEqual(packet.verify(result.files, result.manifest_hash), result)
        self.assertEqual(fixture.selected, fragment["accession"]["recordHash"])

    def test_fragment_validates_under_v2_and_old_record_variant_rejects_it(self):
        fragment_raw = dict(self.result.files)["packet/legal-instrument.json"]
        fragment = definition.validate_legal_instrument(fragment_raw, self.result.report["fields"]["sourceState"])
        self.assertEqual(fragment["status"], "recorded")
        old_defs = v1.definitions()
        old_schema = {"$defs": old_defs, **v1.ref("legalInstrument")}
        with self.assertRaises(ValidationError):
            Draft202012Validator(old_schema).validate(fragment)
        self.assertNotEqual(definition.PACKET_SCHEMA_BYTES,
            (v1.ROOT / "schemas/records/STREAM_ACQUISITION_PACKET_V1.json").read_bytes())

    def test_all_nineteen_requirements_are_retained_and_completion_stays_blocked(self):
        report = self.result.report
        self.assertEqual([row["item"] for row in report["items"]], [str(i) for i in range(1, 20)])
        compatible = {row["item"] for row in report["items"] if row["canonicalPacketCompatible"]}
        self.assertEqual(compatible, {"2", "9", "19"})
        self.assertEqual(next(row for row in report["items"] if row["item"] == "10")["status"], "partial")
        self.assertEqual(report["unresolvedItems"], [str(i) for i in range(1, 20) if i not in (2, 9, 19)])
        self.assertFalse(report["canonicalPacketReady"])
        for key in ("completeCanonicalPacket", "actualChainAcceptance", "legalTitleProven",
                "custodyTransferred", "institutionIdentityProven", "unknownConvertedToAbsence"):
            self.assertFalse(report["claims"][key])
        with self.assertRaisesRegex(MuseumError, "complete canonical packet unavailable"):
            packet.complete_packet(self.result.files, self.result.manifest_hash)

    def test_later_burn_is_retained_without_rewriting_historical_owner_authority(self):
        fixture, _, result = assembled(BurnedAfterDocumentationFixture())
        state = result.report["fields"]["sourceState"]
        authority = result.report["fields"]["legalInstrument"]["accession"]["authority"]
        self.assertTrue(state["burned"])
        self.assertEqual(authority["receipt"]["owner"], OWNER_B)
        self.assertEqual(authority["ownerState"]["transfer"]["to"], OWNER_B)
        self.assertEqual(result.report["fields"]["legalInstrument"]["accession"]["recordHash"], fixture.selected)

    def test_embedded_acquisition_is_byte_exact_and_rebased_source_commitment_rejects(self):
        files = dict(self.result.files)
        for path, raw in self.source.files:
            self.assertEqual(files["acquisition/" + path], raw)
        changed = dict(self.source.files)
        selected = loads(changed["accession/selected.json"])
        selected["accessionIdentifier"] = "forged-rebased-identifier"
        changed["accession/selected.json"] = dumps(selected)
        base_manifest = loads(changed["manifest.json"])
        base_manifest["files"] = [acquisition.base._ref(path, raw) for path, raw in sorted(changed.items())
            if path != "manifest.json"]
        changed["manifest.json"] = dumps(base_manifest)
        with self.assertRaises(MuseumError):
            packet.compose(changed.items(), keccak256(changed["manifest.json"]), disclosure="public",
                packet_schema_hash=definition.PACKET_SCHEMA_HASH, authority_profile_hash=definition.PROFILE_HASH)

    def test_offline_verification_rejects_rehashed_derived_output(self):
        with patch("socket.socket", side_effect=AssertionError("offline packet V2 replay")):
            self.assertEqual(packet.verify(self.result.files, self.result.manifest_hash), self.result)
        files = dict(self.result.files); report = loads(files["packet/assembly.json"])
        report["canonicalPacketReady"] = True
        files["packet/assembly.json"] = dumps(report)
        manifest = loads(files["manifest.json"])
        manifest["files"] = [packet.base._ref(path, raw) for path, raw in sorted(files.items())
            if path != "manifest.json"]
        files["manifest.json"] = dumps(manifest)
        with self.assertRaisesRegex(MuseumError, "source reconstruction differs"):
            packet.verify(files.items(), keccak256(files["manifest.json"]))

    def test_coherently_rehashed_source_block_timestamp_tamper_rejects_reconstruction(self):
        files = dict(self.result.files)
        fragment = loads(files["packet/legal-instrument.json"])
        report = loads(files["packet/assembly.json"], maximum=64 * 1024 * 1024)
        # Keep both derived views equal and semantically plausible: the forged
        # value remains after the original receipt and before examinedAt.
        forged = str(int(self.source.report["sourceState"]["timestamp"]) - 1)
        fragment["accession"]["authority"]["ownerState"]["sourceBlockTimestamp"] = forged
        report["fields"]["legalInstrument"]["accession"]["authority"]["ownerState"][
            "sourceBlockTimestamp"] = forged
        files["packet/legal-instrument.json"] = dumps(fragment)
        files["packet/assembly.json"] = dumps(report)
        manifest = loads(files["manifest.json"])
        manifest["files"] = [packet.base._ref(path, raw) for path, raw in sorted(files.items())
            if path != "manifest.json"]
        files["manifest.json"] = dumps(manifest)
        with self.assertRaisesRegex(MuseumError, "source reconstruction differs"):
            packet.verify(files.items(), keccak256(files["manifest.json"]))

    def test_base_report_tamper_cannot_be_hidden_behind_rehashed_acquisition_manifest(self):
        files = dict(self.source.files); report = loads(files["acquisition/report.json"], maximum=64 * 1024 * 1024)
        report["claims"]["legalTitleProven"] = True
        files["acquisition/report.json"] = dumps(report)
        manifest = loads(files["manifest.json"])
        manifest["files"] = [acquisition.base._ref(path, raw) for path, raw in sorted(files.items())
            if path != "manifest.json"]
        files["manifest.json"] = dumps(manifest)
        with self.assertRaisesRegex(MuseumError, "source reconstruction differs"):
            packet.compose(files.items(), keccak256(files["manifest.json"]), disclosure="public",
                packet_schema_hash=definition.PACKET_SCHEMA_HASH, authority_profile_hash=definition.PROFILE_HASH)

    def test_private_disclosure_preflight_and_exact_source_provenance(self):
        with self.assertRaisesRegex(MuseumError, "public disclosure"):
            packet.compose(self.source.files, self.source.manifest_hash, disclosure="restricted",
                packet_schema_hash=definition.PACKET_SCHEMA_HASH, authority_profile_hash=definition.PROFILE_HASH)
        self.assertEqual(self.result.report["sourceProvenance"], "synthetic_fixture")
        self.assertFalse(self.result.report["claims"]["sourceProvenanceSelfAuthenticated"])
        self.assertEqual(loads(dict(self.result.files)["definitions/native-owner-authority-profile.json"]),
            loads(definition.PROFILE_BYTES))

    def test_cli_atomic_assemble_verify_profiles_and_common_dispatch_offline(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); source = root / "source"; output = root / "packet"
            write_package(self.source, source)
            stdout = io.StringIO()
            argv = ["assemble", "--acquisition", str(source), "--acquisition-hash", self.source.manifest_hash,
                "--packet-schema-hash", definition.PACKET_SCHEMA_HASH,
                "--authority-profile-hash", definition.PROFILE_HASH, "--disclosure", "public",
                "--output", str(output)]
            with patch("socket.socket", side_effect=AssertionError("offline CLI")), patch("sys.stdout", stdout):
                packet.main(argv)
            summary = loads(stdout.getvalue().encode())
            self.assertEqual((summary["manifestHash"], summary["canonicalPacketReady"]),
                (self.result.manifest_hash, False))
            self.assertEqual(packet.verify(dict(self.result.files).items(), self.result.manifest_hash), self.result)
            with patch("socket.socket", side_effect=AssertionError("offline common dispatch")):
                self.assertEqual(verify_package(output, self.result.manifest_hash).manifest, self.result.manifest)
            stdout = io.StringIO()
            with patch("sys.stdout", stdout): packet.main(["profiles"])
            profiles = loads(stdout.getvalue().encode())
            self.assertEqual((profiles["packetSchemaHash"], profiles["authorityProfileHash"]),
                (definition.PACKET_SCHEMA_HASH, definition.PROFILE_HASH))
            with self.assertRaisesRegex(MuseumError, "output must be a new directory"):
                packet.main(argv)


if __name__ == "__main__":
    unittest.main()
