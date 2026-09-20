"""Synthetic supplied-data and original-wire controls; no actual-chain evidence."""
import copy
import hashlib
from pathlib import Path
import unittest

from jsonschema import Draft202012Validator

from . import acquisition_packet_v3 as v3
from . import acquisition_packet_v2 as v2
from . import genesis_dossier_profile as v1
from .test_acquisition_packet_v2 import with_owner
from tools.museum.canonical import MuseumError, dumps, keccak256, loads, schema_id


def packet(captures=0):
    value = copy.deepcopy(v1.examples()["acquisition-packet.json"])
    value.update(schema=v3.PACKET, version=3)
    original = value["tombstone"]["record"]
    for lane, family in (("owner", "CONDITION_REPORT"), ("independent", "INDEPENDENT_CONDITION")):
        record = copy.deepcopy(original)
        record.update(recordHash=v1._h(lane + " synthetic condition"), recordType=schema_id(family),
            schemaId=schema_id("STREAM_CONDITION_REPORT_V1"))
        value["conditionReports"][lane] = {"status": "present", "record": record,
            "examinationCaptures": [v1._reference(lane + "-capture-" + str(i)) for i in range(captures)]}
    return value


class AcquisitionPacketV3Tests(unittest.TestCase):
    def reject(self, value, message=None):
        with self.assertRaises(v1.DossierError) as caught: v3.validate(dumps(value))
        if message: self.assertIn(message, str(caught.exception))

    def test_zero_optional_captures_supported_in_full_packet_and_exact_fragment(self):
        value = packet()
        self.assertEqual(v3.validate(dumps(value)), value)
        fragment = value["conditionReports"]
        self.assertEqual(v3.validate_condition_reports(dumps(fragment), value["sourceState"]), fragment)
        self.assertEqual([fragment[lane]["examinationCaptures"] for lane in ("owner", "independent")], [[], []])
        for name, version, validate in ((v1.PACKET, 1, lambda raw: v1.validate(v1.PACKET, raw)),
                (v2.PACKET, 2, v2.validate)):
            previous = copy.deepcopy(value); previous.update(schema=name, version=version)
            with self.subTest(version=version), self.assertRaises(v1.DossierError): validate(dumps(previous))

    def test_nonempty_capture_reference_shape_order_and_old_semantics_unchanged(self):
        value = packet(2)
        self.assertEqual(v3.validate(dumps(value)), value)
        self.assertEqual(v3.validate_condition_reports(dumps(value["conditionReports"]), value["sourceState"]), value["conditionReports"])
        for name, version, validate in ((v1.PACKET, 1, lambda raw: v1.validate(v1.PACKET, raw)),
                (v2.PACKET, 2, v2.validate)):
            previous = copy.deepcopy(value); previous.update(schema=name, version=version)
            self.assertEqual(validate(dumps(previous)), previous)
        self.assertNotEqual(value["conditionReports"]["owner"]["examinationCaptures"][0],
            value["conditionReports"]["owner"]["examinationCaptures"][1])

    def test_definitions_change_only_packet_identity_and_capture_minimum(self):
        expected = copy.deepcopy(v2.definitions())
        expected["packet"]["properties"]["schema"] = {"const": v3.PACKET}
        expected["packet"]["properties"]["version"] = {"const": 3}
        present = expected["condition"]["oneOf"][1]
        self.assertEqual(present["properties"]["status"], {"const": "present"})
        self.assertEqual(present["properties"]["examinationCaptures"]["minItems"], 1)
        present["properties"]["examinationCaptures"]["minItems"] = 0
        self.assertEqual(v3.definitions(), expected)
        self.assertEqual(v2.definitions()["condition"]["oneOf"][1]["properties"]["examinationCaptures"]["minItems"], 1)
        for raw in v3.documents().values():
            schema = loads(raw, maximum=v3.MAX_BYTES)
            Draft202012Validator.check_schema(schema)
            constraints = " ".join(schema["x-stream-constraints"])
            self.assertNotIn("Packet version is numeric2", constraints)
            self.assertIn("Numeric packet version3", constraints)
            self.assertIn("kind=native_owner_receipt, version=string1", constraints)
            self.assertIn("No numeric authorityClass is assigned or synthesized", constraints)

    def test_v1_v2_schema_profile_and_validator_bytes_remain_frozen(self):
        pins = {v1.PACKET: "0x88d89a5ee0a1b15bc4c4b38e73c57f6c120bf198e03a82f7f8ad61d0f9923357",
            v1.OBJECT: "0xd9d328022f6c30fd3d6b961504d67f4b1732c03e4f73f1dd41b542db74982f74",
            v2.PACKET: "0xfda1ee532ac701b3030a79f7a3c628a26bb9d2243459d03b850d245ab8c2bd89",
            v2.LEGAL_INSTRUMENT: "0x84066512aed266d3951177120d7eb8e1142b11e338232dc947ddee33aee448ef"}
        for name, expected in pins.items():
            self.assertEqual(keccak256((v3.ROOT / "schemas/records" / (name + ".json")).read_bytes()), expected)
            self.assertEqual(keccak256((v1.documents() if name in (v1.PACKET, v1.OBJECT) else v2.documents())[name]), expected)
        self.assertEqual(v3.AUTHORITY_PROFILE_BYTES, v2.PROFILE_BYTES)
        self.assertEqual(v3.AUTHORITY_PROFILE_HASH, "0xd9a70efd37bf78aef720176cea8a392887edb8275f4e456d0b67590ce0b17456")
        self.assertEqual((v3.ROOT / "schemas/records/profiles" / (v2.PROFILE + ".json")).read_bytes(), v3.AUTHORITY_PROFILE_BYTES)
        for module, expected in ((v1, "234e0cb71450e6402e34e6273daa5e355edd5606ecf331e4915b52390fd82d01"),
                (v2, "a694e1c71d4bf3437a68f7fa11d8b186c35b5f2aa1ddbcbafaa2c8003d0e15d4")):
            # Source pins use Git's LF text representation; generated JSON pins use exact bytes.
            raw = Path(module.__file__).read_bytes().replace(b"\r\n", b"\n")
            self.assertEqual(hashlib.sha256(raw).hexdigest(), expected)
        self.assertEqual(set(v3.outputs()), {"schemas/records/" + name + ".json" for name in (v3.PACKET, v3.CONDITION_REPORTS)})
        for path, raw in v3.outputs().items(): self.assertEqual((v3.ROOT / path).read_bytes(), raw)

    def test_native_owner_authority_meaning_and_role_limit_are_unchanged(self):
        for scheme in ("DIRECT", "EIP712", "ERC1271"):
            value = with_owner(scheme=scheme, title=True); value.update(schema=v3.PACKET, version=3)
            self.assertEqual(v3.validate(dumps(value)), value)
            wrong = copy.deepcopy(value)
            wrong["legalInstrument"]["accession"]["authority"]["receipt"]["owner"] = "0x" + "99" * 20
            self.reject(wrong, "signer/receipt/prior holder")
            wrong = copy.deepcopy(value)
            wrong["conditionReports"]["owner"] = {"status": "present", "record": copy.deepcopy(value["legalInstrument"]["accession"]),
                "examinationCaptures": []}
            self.reject(wrong)

    def test_malformed_missing_extra_and_overbound_captures_remain_invalid(self):
        maximum = v3.definitions()["condition"]["oneOf"][1]["properties"]["examinationCaptures"]["maxItems"]
        edits = [lambda row: row.pop("examinationCaptures"), lambda row: row.update(examinationCaptures=None),
            lambda row: row.update(examinationCaptures=[{}]), lambda row: row.update(examinationCaptures=[v1._reference("x")] * (maximum + 1)),
            lambda row: row["examinationCaptures"][0].update(uri="https:///missing-authority"),
            lambda row: row["examinationCaptures"][0]["hash"].update(digest="0x01"),
            lambda row: row["examinationCaptures"][0].update(retrieved=True)]
        for edit in edits:
            value = packet(1); edit(value["conditionReports"]["owner"])
            with self.subTest(edit=edit):
                self.reject(value)
                with self.assertRaises(v1.DossierError):
                    v3.validate_condition_reports(dumps(value["conditionReports"]), value["sourceState"])

    def test_fragment_source_context_lane_type_and_repeated_record_joins(self):
        edits = [lambda r: r.update(recordType=schema_id("EXHIBITION")),
            lambda r: r.update(subjectId=v1._h("other token")), lambda r: r.update(recordedBlock="101")]
        for edit in edits:
            value = packet(); edit(value["conditionReports"]["owner"]["record"])
            with self.subTest(edit=edit):
                self.reject(value)
                with self.assertRaises(v1.DossierError):
                    v3.validate_condition_reports(dumps(value["conditionReports"]), value["sourceState"])
        value = packet()
        value["conditionReports"]["independent"]["record"]["recordHash"] = value["conditionReports"]["owner"]["record"]["recordHash"]
        with self.assertRaisesRegex(v1.DossierError, "contradictory repeated"):
            v3.validate_condition_reports(dumps(value["conditionReports"]), value["sourceState"])
        value = packet(); value["sourceState"]["tokenId"] = "0"
        with self.assertRaises(v1.DossierError): v3.validate_condition_reports(dumps(value["conditionReports"]), value["sourceState"])

    def test_supplied_absence_remains_separate_and_no_selection_proof_added(self):
        value = packet()
        value["conditionReports"]["independent"] = {"status": "none_recorded", "evidence": v1._reference("supplied-absence-claim")}
        self.assertEqual(v3.validate(dumps(value)), value)
        self.assertEqual(v3.validate_condition_reports(dumps(value["conditionReports"]), value["sourceState"]), value["conditionReports"])
        self.assertIn("does not select a latest report", v3.QUALIFICATION)
        self.assertIn("prove record absence", v3.QUALIFICATION)
        wrong = copy.deepcopy(value); wrong["conditionReports"]["independent"]["examinationCaptures"] = []
        self.reject(wrong)
        wrong = copy.deepcopy(value); wrong["conditionReports"]["owner"]["latestSelectionProven"] = True
        self.reject(wrong)

    def test_original_condition_payload_profile_already_accepts_empty_optional_captures(self):
        from tools.museum import condition as condition_module
        from tools.museum.test_condition import condition
        value = condition(); value["captures"] = []
        row = condition_module.admit_payload(dumps(value))
        self.assertEqual(row["value"], value)
        self.assertFalse(row["authority"]["authenticated"])
        self.assertEqual(condition_module.documents()[condition_module.NAME]["properties"]["captures"]["minItems"], 0)
        self.assertEqual((v3.ROOT / "schemas/museum/condition" / (condition_module.NAME + ".json")).read_bytes(), condition_module.SCHEMA_BYTES)

    def test_selected_latest_unsupported_original_is_retained_without_older_fallback(self):
        from tools.museum import condition as condition_module
        from tools.museum.test_condition import ConditionOwnerFixture
        from tools.museum.test_loans import OwnerFixture
        from tools.museum.test_valuations import ValuationFixture
        fixture = ConditionOwnerFixture()
        older = fixture.lanes[(41, schema_id("CONDITION_REPORT"))][-1]
        unsupported_schema = dumps({"type": "object", "additionalProperties": True})
        name = "SYNTHETIC_UNSUPPORTED_CONDITION_V1"
        ValuationFixture.register_schema(fixture, name, unsupported_schema)
        latest = OwnerFixture.append(fixture, "CONDITION_REPORT", name, {"opaque": "selected latest original"})
        self.assertEqual(fixture.lanes[(41, schema_id("CONDITION_REPORT"))][-1], latest)
        source, _, _ = fixture.replay(); pin = keccak256(source.snapshot())
        self.assertIsNotNone(condition_module.admit_owner(source, [older], source_hash=pin)[0]["value"])
        rows = condition_module.admit_owner(source, [latest], source_hash=pin)
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["source"]["recordHash"], latest)
        self.assertEqual(rows[0]["source"]["recordIndex"], "2")
        self.assertIsNone(rows[0]["value"])
        self.assertEqual(rows[0]["reasonCode"], "original_registered_definition_unsupported")
        self.assertEqual(rows[0]["originalPayloadHex"], "0x" + fixture.rows[latest][0][5].hex())
        self.assertEqual(rows[0]["registeredSchemaHex"], "0x" + unsupported_schema.hex())
        files = condition_module.project_owner_conditions(source, [latest], source_hash=pin,
            profile_hash=condition_module.PROFILE_HASH)
        self.assertEqual(loads(files["condition/report.json"])["status"], "unsupported")
        self.assertEqual(loads(files["condition/index.json"])["resources"], [])
        retained = loads(files["condition/dossiers.json"], maximum=524288)
        self.assertEqual([r["source"]["recordHash"] for r in retained], [latest])

    def test_selected_latest_malformed_supported_payload_fails_without_fallback(self):
        from tools.museum import condition as condition_module
        from tools.museum.test_condition import ConditionOwnerFixture
        from tools.museum.test_loans import OwnerFixture
        fixture = ConditionOwnerFixture()
        latest = OwnerFixture.append(fixture, "CONDITION_REPORT", condition_module.NAME, {"version": "1"})
        source, _, _ = fixture.replay(); pin = keccak256(source.snapshot())
        self.assertEqual(fixture.lanes[(41, schema_id("CONDITION_REPORT"))][-1], latest)
        with self.assertRaises(MuseumError):
            condition_module.admit_owner(source, [latest], source_hash=pin)

    def test_version_canonical_bytes_and_fragment_wrapping_remain_explicit(self):
        value = packet()
        for changes in ({"version": "3"}, {"version": 2}, {"schema": v2.PACKET}):
            wrong = copy.deepcopy(value); wrong.update(changes)
            with self.subTest(changes=changes): self.reject(wrong)
        for raw in (dumps(value) + b"\n", b'{"version":3,"version":3}', b" " * (v3.MAX_BYTES + 1)):
            with self.assertRaises(v1.DossierError): v3.validate(raw)
        with self.assertRaises(v1.DossierError):
            v3.validate_condition_reports(dumps({"conditionReports": value["conditionReports"]}), value["sourceState"])


if __name__ == "__main__": unittest.main()
