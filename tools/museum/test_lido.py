"""Exact, attributed LIDO correspondence from the same four-media fixture."""

import copy
from dataclasses import replace
from pathlib import Path
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads
from .lido import project_lido_fixture, verify_lido_fixture, source_record_id
from .lido_model import FIELDS, NS, PinnedLIDO, PROFILE_BYTES, PROFILE_HASH
from . import test_iiif
from .test_iiif import source_data as iiif_source, source_document, arguments as iiif_arguments, FILES, EXACT
from .test_projection import entity
from .test_projection_v2 import assertion, literal

ROOT = Path(__file__).resolve().parents[2] / "schemas/museum"
CREATOR = "urn:fixture:actual-creator"
ISSUER = "urn:fixture:artist"
DATE = "circa 2026-09 — source uncertainty retained; not an indexed interval"
MEDIUM = "Algorithm & sound <score>\r\n𝄞 e\u0301"
EDITION = "Edition " + str((1 << 256) - 1) + " / declared open series"
XMLNS = {"l": NS, "xml": "http://www.w3.org/XML/1998/namespace"}


def source_data(claims=None, entities=None, extra=()):
    if claims is None:
        doc = source_document(iiif_source())
        entities = doc["entities"] + [
            entity(CREATOR, "person", [{"kind": "preferred", "value": "Creator, not issuer — 𝄞", "language": None}]),
            entity(ISSUER, "person", [{"kind": "preferred", "value": "Source claimant only", "language": None}]),
            entity("urn:fixture:creation", "event")]
        claims = doc["assertions"]
        for subject, field, value in (("work", "work-type", "generative digital artwork"),
                ("work", "medium", MEDIUM), ("work", "edition", EDITION),
                ("work", "credit-line", "Work attribution only"), ("work", "document-language", "und"),
                ("creation", "event-type", "creation"), ("creation", "creation-display", DATE)):
            claims.append(assertion("lido-" + field, subject, FIELDS[field], literal(value)))
        claims += [assertion("lido-event", "work", FIELDS["creation-event"], {"entity": "urn:fixture:creation"}),
                   assertion("lido-creator", "creation", FIELDS["creator"], {"entity": CREATOR})]
    from .source import FixtureSourceAdapter
    from .test_projection_v2 import fixture_v2
    from .test_review import record, row
    from .test_schema_inventory import assertion_document
    from .premis import FIELDS as PF
    from .iiif import FIELDS as IF
    # More entity declarations fit with eight first-record claims; later records
    # carry sixteen claims each. The unchanged24KiB source limit still applies.
    data = fixture_v2(entities=entities, assertions=claims[:8])
    records = [data[0].records[0]]
    for i in range(8, len(claims), 16):
        doc = assertion_document(); doc.update(entities=[], assertions=claims[i:i+16])
        r = record(doc, "lido-claims-" + str(i), ISSUER, "artist", [str(i), "0", "0"])
        records.append(r)
        data[1]["sourceAuthoritySet"].extend(row(r) | {"pointer": "/assertions/" + str(j)} for j in range(len(doc["assertions"])))
    state = FixtureSourceAdapter("lido-projection", tuple(records) + tuple(extra)).snapshot()
    data = state, data[1], data[2]
    data[1]["sourceStateHash"] = state.commitment
    data[2]["sourceStateHash"] = state.commitment
    data[1]["singleValuedRelations"].extend(list(PF.values()) + list(IF.values()))
    data[1]["singleValuedRelations"].extend(FIELDS.values())
    data[2]["externalEntities"] = [e for e in data[2]["externalEntities"] if e["id"] not in {e["id"] for e in entities}]
    data[2]["selectionPolicyHash"] = keccak256(dumps(data[1]))
    return data


def arguments(data, linked, premis, iiif, lido):
    args, kwargs = iiif_arguments(data, linked, premis, iiif)
    plan = {"mode": "synthetic_lido_projection", "version": "1", "sourceStateHash": data[0].commitment,
        "profileHash": kwargs["profile_hash"], "linkedArtPlanHash": kwargs["plan_hash"],
        "premisPlanHash": kwargs["premis_plan_hash"], "iiifPlanHash": kwargs["iiif_plan_hash"],
        "lidoProfileHash": PROFILE_HASH, "recordId": "https://example.org/lido/fixture/record"}
    raw = dumps(plan)
    return (*args, raw), kwargs | {"lido_plan_hash": keccak256(raw), "lido_profile": lido}


def changed(data, field, value=None, *, remove=False, subject=None):
    doc = source_document(data)
    claim = next(c for c in doc["assertions"] if c["relation"] == FIELDS[field]
                 and (subject is None or c["subject"] == subject))
    if remove:
        doc["assertions"].remove(claim)
    else:
        claim["object"] = copy.deepcopy(value)
    return source_data(doc["assertions"], doc["entities"])


class LIDOCorrespondence(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Construct the same pinned dependency profiles, without inheriting their tests.
        test_iiif.IIIFCorrespondence.setUpClass()
        cls.linked, cls.premis, cls.iiif = (test_iiif.IIIFCorrespondence.linked,
            test_iiif.IIIFCorrespondence.premis, test_iiif.IIIFCorrespondence.iiif)
        cls.lido = PinnedLIDO(ROOT, PROFILE_BYTES, profile_hash=PROFILE_HASH)

    def args(self, data=None):
        return arguments(source_data() if data is None else data, self.linked, self.premis, self.iiif, self.lido)

    def run_projection(self, data=None):
        args, kwargs = self.args(data)
        return project_lido_fixture(*args, **kwargs)

    def test_actual_original_xsd_four_media_shared_identity_and_creator_provenance(self):
        with patch("socket.socket", side_effect=AssertionError("offline only")):
            result = self.run_projection()
        root = self.lido.validate(result.xml)
        q = lambda path: root.xpath(path, namespaces=XMLNS)
        self.assertEqual(q("string(l:lidoRecID)"), "https://example.org/lido/fixture/record")
        self.assertEqual(q("string(l:objectPublishedID)"), "urn:fixture:work")
        self.assertEqual(q(".//l:actorID/text()"), [CREATOR])
        self.assertEqual(q(".//l:recordSource/l:legalBodyID/text()"), [ISSUER])
        self.assertEqual(q(".//l:resourceID/text()"), ["urn:fixture:" + f for f in FILES])
        self.assertEqual(q(".//l:resourceType/l:term/text()"), ["Image", "Text", "Sound", "Video"])
        self.assertEqual(q(".//l:displayDate/text()"), [DATE])
        self.assertEqual(q(".//l:displayEdition/text()"), [EDITION])
        self.assertEqual(q(".//l:displayMaterialsTech/text()"), [MEDIUM])
        self.assertEqual(q(".//l:descriptiveNoteValue/text()"), [EXACT])
        self.assertEqual(q(".//l:measurementValue/text()"), ["6000", "4000", "0.10000000000000001", "6000", "4000", "220.000"])
        self.assertFalse(q(".//l:earliestDate | .//l:latestDate | .//l:rightsRecord"))
        self.assertFalse(any(loads(result.report)["claims"].values()))

    def test_document_language_is_explicit_never_missing_null_or_inferred(self):
        good = source_data()
        for data in (changed(good, "document-language", remove=True),
                     changed(good, "document-language", literal("en")),
                     changed(good, "document-language", literal(None)),
                     changed(good, "document-language", literal("")),
                     changed(good, "document-language", literal("und", language="en"))):
            with self.subTest(state=data[0].commitment), self.assertRaises(MuseumError):
                self.run_projection(data)
        root = self.lido.validate(self.run_projection(good).xml)
        self.assertEqual(root.xpath("*/@xml:lang", namespaces=XMLNS), ["und", "und"])
        self.assertTrue(all(n["language"] is None for e in source_document(good)["entities"] for n in e["names"]))

    def test_export_language_cannot_override_creator_name_or_empty_provider_name(self):
        good = source_data()
        for identifier, field, value in ((CREATOR, "language", "en"), (ISSUER, "value", "")):
            doc = source_document(good)
            next(e for e in doc["entities"] if e["id"] == identifier)["names"][0][field] = value
            with self.assertRaisesRegex(MuseumError, "language|empty source name"):
                self.run_projection(source_data(doc["assertions"], doc["entities"]))

    def test_missing_creator_event_or_date_never_falls_back_to_issuer(self):
        good = source_data()
        for field in ("creator", "creation-event", "creation-display"):
            with self.subTest(field=field), self.assertRaisesRegex(MuseumError, "missing selected fact"):
                self.run_projection(changed(good, field, remove=True))
        for field, value in (("creator", {"entity": "urn:fixture:photo"}),
                             ("creation-event", {"entity": CREATOR}), ("event-type", literal("acquisition"))):
            with self.subTest(field=field), self.assertRaisesRegex(MuseumError, "entity kind|creation event"):
                self.run_projection(changed(good, field, value))

    def test_role_specific_conflicts_withhold_original_claims_and_provenance(self):
        good = source_data()
        for subject, field, value in (("work", "medium", literal("Different medium")),
                ("creation", "creator", {"entity": ISSUER}), ("work", "document-language", literal("en"))):
            doc = source_document(good)
            doc["assertions"].append(assertion("lido-conflict", subject, FIELDS[field], value))
            with self.subTest(field=field), self.assertRaisesRegex(MuseumError, "LIDO conflicting selected facts") as error:
                self.run_projection(source_data(doc["assertions"], doc["entities"]))
            self.assertIn("recordHash", str(error.exception))
            self.assertIn("lido-conflict", str(error.exception))

    def test_credit_disagreement_retains_both_sources_and_no_rights_inheritance(self):
        good = source_data()
        with self.assertRaisesRegex(MuseumError, "credit line.*disagree") as error:
            self.run_projection(changed(good, "credit-line", literal("Unrelated credit")))
        self.assertIn("Work attribution only", str(error.exception))
        self.assertIn("Unrelated credit", str(error.exception))
        self.assertIn("recordHash", str(error.exception))
        root = self.lido.validate(self.run_projection(good).xml)
        self.assertEqual(root.xpath(".//l:rightsResource/l:rightsType/l:conceptID/text()", namespaces=XMLNS),
                         ["http://rightsstatements.org/vocab/InC/1.0/"] * 4)
        self.assertFalse(root.xpath(".//l:rightsWorkSet/l:rightsType | .//l:rightsRecord", namespaces=XMLNS))
        self.assertNotIn(b"creativecommons.org", self.run_projection(good).xml)

    def test_every_provenance_xpath_matches_original_exact_value_and_complete_inventory(self):
        data = source_data(); result = self.run_projection(data)
        root = self.lido.validate(result.xml)
        records = {r.selector.record_hash: r for r in data[0].records}
        for row in loads(result.provenance, maximum=67108864):
            value = loads(records[row["source"]["recordHash"]].payload)
            for part in row["sourcePointer"].removeprefix("/").split("/"):
                part = part.replace("~1", "/").replace("~0", "~")
                value = value[int(part)] if isinstance(value, list) else value[part]
            actual = root.xpath(row["targetXPath"], namespaces={"lido": NS, "xml": XMLNS["xml"]})
            self.assertEqual(len(actual), 1)
            self.assertEqual(actual[0].text if hasattr(actual[0], "text") else actual[0], value)
            self.assertEqual(row["issuer"], ISSUER)
        prior, current = [loads(b, maximum=67108864) for b in (result.iiif.coverage, result.coverage)]
        def inventory(rows):
            return [(r["recordHash"], [(f["pointer"], f["presence"], f["exactHex"]) for f in r["fields"]]) for r in rows]
        self.assertEqual(inventory(prior), inventory(current))
        original = {r.selector.record_hash: "0x" + r.payload.hex() for r in data[0].records}
        self.assertEqual({s["selector"]["recordHash"]: s["payloadHex"] for s in loads(result.iiif.premis.linked_art.sidecar, maximum=67108864)["publicSources"]}, original)
        nulls = [f for r in current for f in r["fields"] if f["pointer"].endswith("/language") and f["exactHex"] == "0x6e756c6c"]
        self.assertTrue(nulls)

    def test_derived_source_record_identity_binds_full_selector_payload_and_authority(self):
        data = source_data(); result = self.run_projection(data)
        rows = loads(result.correspondence, maximum=67108864)["sourceRecords"]
        records = {r.selector.record_hash: r for r in data[0].records}
        for row in rows:
            r = records[row["selector"]["record_hash"]]
            expected = "urn:6529stream:museum:lido-work:v1:source-record:" + keccak256(dumps({
                "selector": {"host": r.selector.host, "record_hash": r.selector.record_hash,
                    "subject_id": r.selector.subject_id, "schema_id": r.selector.schema_id,
                    "schema_hash": r.selector.schema_hash, "record_type": r.selector.record_type,
                    "recorder": r.selector.recorder, "authorization_class": r.selector.authorization_class,
                    "record_index": r.selector.record_index, "record_chain_hash": r.selector.record_chain_hash},
                "payloadHash": r.payload_hash, "authorityEvidenceHash": keccak256(r.authority_evidence)}))
            self.assertEqual(row["lidoRecordId"], expected)
            self.assertEqual(source_record_id(r), expected)
        self.assertEqual(len({r["lidoRecordId"] for r in rows}), len(rows))

    def test_record_id_cannot_merge_with_work_creator_extension_or_presentation(self):
        args, kwargs = self.args()
        for identifier in ("urn:fixture:work", CREATOR, "urn:fixture:creation",
                           "https://example.org/iiif/fixture/canvas/photo"):
            plan = loads(args[-1]); plan["recordId"] = identifier; raw = dumps(plan)
            with self.subTest(identifier=identifier), self.assertRaisesRegex(MuseumError, "aliases"):
                project_lido_fixture(*args[:-1], raw, **(kwargs | {"lido_plan_hash": keccak256(raw)}))

    def test_xml_valid_tampering_and_rehashed_reports_cannot_pass_source_rebuild(self):
        args, kwargs = self.args(); result = project_lido_fixture(*args, **kwargs)
        changed_xml = result.xml.replace(b"generative digital artwork", b"different digital artwork")
        self.lido.validate(changed_xml)
        report = loads(result.report); report["xmlHash"] = keccak256(changed_xml)
        with self.assertRaisesRegex(MuseumError, "shared-source consistency"):
            verify_lido_fixture(replace(result, xml=changed_xml, report=dumps(report)), *args, **kwargs)
        self.assertEqual(verify_lido_fixture(result, *args, **kwargs), loads(result.report))

    def test_unrelated_and_unselected_claims_do_not_veto_but_remain_accounted(self):
        from .test_review import record
        from .test_schema_inventory import assertion_document
        data = source_data(); doc = source_document(data)
        doc["assertions"].append(assertion("other-language", "photo", FIELDS["document-language"], literal("en")))
        hostile = assertion_document()
        hostile["assertions"] = [assertion("hostile-credit", "work", FIELDS["credit-line"], literal("Hostile"))]
        extra = record(hostile, "unselected-lido", "urn:fixture:outsider", "independent", ["99", "0", "0"])
        updated = source_data(doc["assertions"], doc["entities"], (extra,))
        result = self.run_projection(updated)
        self.assertEqual(result.xml, self.run_projection(source_data(doc["assertions"], doc["entities"])).xml)
        # Entire unselected records are opaque diagnostics, not admitted-schema
        # inventory rows; their exact bytes remain available in publicSources.
        self.assertNotIn(extra.selector.record_hash, {r["recordHash"] for r in loads(result.coverage, maximum=67108864)})
        sidecar = loads(result.iiif.premis.linked_art.sidecar, maximum=67108864)
        self.assertEqual(next(s["payloadHex"] for s in sidecar["publicSources"]
            if s["selector"]["recordHash"] == extra.selector.record_hash), "0x" + extra.payload.hex())

    def test_xml_unrepresentable_source_and_nonstandard_datatype_reject_without_repair(self):
        good = source_data()
        for value in (literal("medium\x01"), literal("medium", datatype="http://www.w3.org/2001/XMLSchemastring")):
            with self.assertRaises(MuseumError):
                self.run_projection(changed(good, "medium", value))

    def test_repeated_names_providers_and_resources_have_final_unique_paths(self):
        from .test_review import record, row
        from .test_schema_inventory import assertion_document
        doc = source_document(source_data())
        for identifier in (CREATOR, "urn:fixture:work"):
            next(e for e in doc["entities"] if e["id"] == identifier)["names"].append(
                {"kind": "alternate", "value": "Second <name>\r\n𝄞", "language": None})
        second = "urn:fixture:second-claimant"
        doc["entities"].append(entity(second, "group", [{"kind": "preferred", "value": "Second provider", "language": None}]))
        extra_doc = assertion_document(); extra_doc["entities"] = []
        extra_doc["assertions"] = [assertion("compatible-medium", "work", FIELDS["medium"], literal(MEDIUM))]
        extra_doc["assertions"][0]["assertingAgent"] = second
        extra = record(extra_doc, "second-lido-source", second, "artist", ["99", "0", "0"])
        data = source_data(doc["assertions"], doc["entities"], (extra,))
        data[1]["sourceAuthoritySet"].append(row(extra))
        data[2]["selectionPolicyHash"] = keccak256(dumps(data[1]))
        result = self.run_projection(data); root = self.lido.validate(result.xml)
        self.assertEqual(root.xpath(".//l:recordSource/l:legalBodyID/text()", namespaces=XMLNS), [ISSUER, second])
        self.assertEqual(root.xpath(".//l:titleSet/l:appellationValue/text()", namespaces=XMLNS),
                         ["Four forms — e\u0301", "Second <name>\r\n𝄞"])
        for r in loads(result.provenance, maximum=67108864):
            self.assertEqual(len(root.xpath(r["targetXPath"], namespaces={"lido": NS, "xml": XMLNS["xml"]})), 1)
        for r in loads(result.correspondence, maximum=67108864)["files"]:
            nodes = root.xpath(r["lidoResourceXPath"], namespaces={"lido": NS})
            self.assertEqual(len(nodes), 1)
            self.assertEqual(nodes[0].findtext("{" + NS + "}resourceID"), r["linkedArtId"])

    def test_checked_in_public_example_and_plan_scope_are_exact(self):
        from .package import fixture_state_bytes, fixture_state_from_bytes
        data = source_data(); args, kwargs = self.args(data)
        example = ROOT / "lido/example"
        self.assertEqual((example / "source-state.json").read_bytes(), fixture_state_bytes(data[0]))
        self.assertEqual(fixture_state_from_bytes((example / "source-state.json").read_bytes()), data[0])
        for name, raw in zip(("selection-policy.json", "linked-art-plan.json", "premis-plan.json", "iiif-plan.json", "lido-plan.json"), args[1:]):
            self.assertEqual((example / name).read_bytes(), raw)
        for i, record in enumerate(data[0].records):
            self.assertEqual((example / f"assertion-{i}.json").read_bytes(), record.payload)
        with self.assertRaisesRegex(MuseumError, "plan hash mismatch"):
            project_lido_fixture(*args, **(kwargs | {"lido_plan_hash": "0x" + "00" * 32}))
