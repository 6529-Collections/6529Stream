"""Policy-selected resources, exact source coverage and offline model controls."""

import copy
from dataclasses import replace
from pathlib import Path
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .coverage import verify_coverage
from .projection import (CLASSES, CONTEXT, CRM, CROSSWALK_BYTES, CROSSWALK_HASH, DIG, LA,
                         ProjectionProfile, project_fixture)
from .schema_inventory import EVALUATION_PROFILE_HASH, inventory_exact
from .source import FixtureSourceAdapter
from .review import REVIEW_RELATION, REVIEW_MAPPING_RULE, review_literal
from .test_review import record, row
from .test_schema_inventory import H, assertion_document, selector
from .test_semantic_selection import policy

ROOT = Path(__file__).resolve().parents[2] / "schemas/museum"
AGENT = "urn:fixture:artist"


def entity(identifier, kind, names=()):
    return {"id": identifier, "kind": kind, "declaringAgent": AGENT,
            "names": list(names), "sourceRecords": [selector()], "predecessors": []}


def fixture(*, entities=None, assertions=None, extra=()):
    doc = assertion_document()
    doc["entities"] = entities if entities is not None else [
        entity("urn:fixture:master", "digital_object"), entity("urn:fixture:image", "visual_content"),
        entity("urn:fixture:print", "physical_object"), entity("urn:fixture:place", "place"),
        entity("urn:fixture:conception", "abstract_work")]
    if assertions is None:
        relations = [("master", LA + "digitally_shows", "image"), ("print", CRM + "P65_shows_visual_item", "image"),
                     ("image", CRM + "P138_represents", "place"), ("image", CRM + "P129_is_about", "place")]
        assertions = []
        for i, (subject, predicate, target) in enumerate(relations):
            a = copy.deepcopy(doc["assertions"][0])
            a.update(id="urn:fixture:claim:" + str(i), subject="urn:fixture:" + subject,
                     relation=predicate, object={"entity": "urn:fixture:" + target})
            assertions.append(a)
    doc["assertions"] = assertions
    source = record(doc, "projection", AGENT, "artist", ["1", "0", "0"])
    state = FixtureSourceAdapter("projection", (source, *extra)).snapshot()
    p = policy(state, [row(source) | {"pointer": "/assertions/" + str(i)} for i in range(len(assertions))])
    plan = {"mode": "synthetic_resource_projection", "version": "1", "sourceStateHash": state.commitment,
            "profileHash": H, "selectionPolicyHash": keccak256(dumps(p)), "crosswalkHash": CROSSWALK_HASH,
            "entityAuthoritySet": [row(source) | {"pointer": "/entities/" + str(i)} for i in range(len(doc["entities"]))],
            "externalEntities": [{"id": AGENT, "kind": "person"}]}
    return state, p, plan


def run(data, profile):
    state, p, plan = data
    return project_fixture(state, dumps(p), dumps(plan), selection_hash=keccak256(dumps(p)),
                           plan_hash=keccak256(dumps(plan)), profile_hash=H, profile=profile)


class CanonicalResourceProjection(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.validation_hash = keccak256((ROOT / "linked-art/validation-policy.json").read_bytes())
        cls.vocabulary_hash = keccak256((ROOT / "standards/vocabulary-policy.json").read_bytes())
        cls.profile = ProjectionProfile(ROOT, CROSSWALK_BYTES, crosswalk_hash=CROSSWALK_HASH,
            validation_hash=cls.validation_hash, vocabulary_hash=cls.vocabulary_hash)

    def test_definition_crosswalk_has_exact_source_and_no_parent_hash_cycle(self):
        raw = (ROOT / "projection/crosswalk.json").read_bytes()
        self.assertEqual(raw, CROSSWALK_BYTES)
        self.assertNotIn(b'"profileHash"', raw)
        rules = loads(raw)["rules"]
        self.assertEqual(len(rules), 18)
        self.assertEqual(len({r["rule"] for r in rules}), 18)
        for r in rules:
            self.assertTrue(all(key in r for key in ("sourceSchemaId", "sourceSchemaHash", "sourceSelector",
                "sourceSubjectKind", "targetClass", "targetPath", "cardinality", "transformation", "authorityRule",
                "controlledTerms", "uncertaintyTreatment", "reverseCorrespondence", "positiveTest", "negativeTest")))
        for kwargs in ({"crosswalk_hash": H}, {"validation_hash": H}, {"vocabulary_hash": H}):
            args = {"crosswalk_hash": CROSSWALK_HASH, "validation_hash": self.validation_hash,
                    "vocabulary_hash": self.vocabulary_hash} | kwargs
            with self.assertRaises(MuseumError):
                ProjectionProfile(ROOT, raw, **args)

    def test_carriers_depiction_and_about_expand_to_exact_predicates(self):
        with patch("socket.socket", side_effect=AssertionError("network forbidden")):
            result = run(fixture(), self.profile)
        by_id = {r.identifier: loads(r.expanded)[0] for r in result.resources}
        self.assertEqual(len(by_id), 4)
        self.assertEqual(by_id["urn:fixture:master"]["@type"], [DIG + "D1_Digital_Object"])
        self.assertEqual(by_id["urn:fixture:master"][LA + "digitally_shows"][0]["@id"], "urn:fixture:image")
        self.assertEqual(by_id["urn:fixture:print"][CRM + "P65_shows_visual_item"][0]["@id"], "urn:fixture:image")
        self.assertEqual(by_id["urn:fixture:image"][CRM + "P138_represents"][0]["@id"], "urn:fixture:place")
        self.assertEqual(by_id["urn:fixture:image"][CRM + "P129_is_about"][0]["@id"], "urn:fixture:place")
        self.assertNotIn(CRM + "P7_took_place_at", by_id["urn:fixture:image"])
        report = loads(result.report, maximum=64 * 1024 * 1024)
        self.assertFalse(any(report["claims"].values()))
        self.assertEqual(report["sourceStateHash"], fixture()[0].commitment)

    def test_explicit_kinds_and_generic_extensions_remain_distinct(self):
        kinds = list(CLASSES) + ["abstract_work", "information_object", "token", "realization", "event", "statement"]
        entities = [entity("urn:fixture:" + kind, kind) for kind in kinds]
        a = assertion_document()["assertions"][0]
        a["subject"] = "urn:fixture:information_object"
        result = run(fixture(entities=entities, assertions=[a]), self.profile)
        self.assertEqual(len(result.resources), 7)
        self.assertEqual({r.identifier: loads(r.expanded)[0]["@type"][0] for r in result.resources},
                         {"urn:fixture:" + kind: values[1] for kind, values in CLASSES.items()})
        extensions = loads(result.sidecar, maximum=64 * 1024 * 1024)["extensionEntities"]
        self.assertEqual({e["kind"] for e in extensions}, set(kinds) - set(CLASSES))
        self.assertNotIn("urn:fixture:information_object", {r.identifier for r in result.resources})
        self.assertEqual(len({e["id"] for e in loads(result.report, maximum=64 * 1024 * 1024)["entities"]}), 13)

    def test_name_order_exact_text_and_unmapped_language_are_retained(self):
        names = [{"value": "Title — 40.00", "language": "el", "kind": "preferred"},
                 {"value": str((1 << 256) - 1), "language": None, "kind": "identifier"},
                 {"value": "Title — 40.00", "language": "en", "kind": "historical"}]
        data = fixture()
        doc = loads(data[0].records[0].payload)
        doc["entities"][0]["names"] = names
        data = fixture(entities=doc["entities"], assertions=doc["assertions"])
        result = run(data, self.profile)
        master = next(loads(r.content) for r in result.resources if r.identifier == "urn:fixture:master")
        self.assertEqual(master["_label"], names[0]["value"])
        self.assertEqual(master["identified_by"], [{"type": "Name", "content": names[0]["value"]},
            {"type": "Identifier", "content": names[1]["value"]}, {"type": "Name", "content": names[2]["value"]}])
        fields = {r["pointer"]: r for r in loads(result.coverage, maximum=64 * 1024 * 1024)[0]["fields"]}
        self.assertEqual(fields["/entities/0/names/0/language"]["disposition"], "retained_stream_only")
        self.assertEqual(fields["/entities/0/names/0/language"]["exactHex"], "0x" + b'"el"'.hex())
        self.assertEqual(fields["/entities/0/names/1/value"]["exactHex"], "0x" + dumps(str((1 << 256) - 1)).hex())

    def test_entity_issuer_and_every_selector_word_are_required(self):
        data = fixture()
        for field, value in (("host", "0x" + "33" * 20), ("recordHash", H), ("subjectId", schema_id("other")),
            ("schemaId", H), ("schemaHash", H), ("recordType", H), ("recorder", "0x" + "44" * 20),
            ("authorizationClass", "INDEPENDENT_ATTESTOR"), ("recordIndex", "2"), ("recordChainHash", H),
            ("pointer", "/entities/00")):
            plan = copy.deepcopy(data[2])
            plan["entityAuthoritySet"][0][field] = value
            with self.subTest(field=field), self.assertRaises(MuseumError):
                run((data[0], data[1], plan), self.profile)
        doc = loads(data[0].records[0].payload)
        doc["entities"][0]["declaringAgent"] = "urn:fixture:impostor"
        with self.assertRaises(MuseumError):
            run(fixture(entities=doc["entities"], assertions=doc["assertions"]), self.profile)
        self.assertEqual(len(run(data, self.profile).resources), 4)

    def test_wrong_domain_and_dangling_reference_reject(self):
        data = fixture()
        doc = loads(data[0].records[0].payload)
        doc["assertions"][0]["subject"] = "urn:fixture:print"
        with self.assertRaises(MuseumError):
            run(fixture(entities=doc["entities"], assertions=doc["assertions"]), self.profile)
        doc["assertions"][0]["subject"] = "urn:fixture:master"
        doc["assertions"][0]["object"]["entity"] = "urn:fixture:missing"
        with self.assertRaises(MuseumError):
            run(fixture(entities=doc["entities"], assertions=doc["assertions"]), self.profile)
        self.assertEqual(len(run(data, self.profile).resources), 4)

    def test_full_schema_denominator_and_original_exact_bytes_survive_projection(self):
        data = fixture()
        result = run(data, self.profile)
        source = data[0].records[0]
        inv = inventory_exact(source.schema, source.payload, schema_hash=source.selector.schema_hash,
            payload_hash=source.payload_hash, evaluation_hash=EVALUATION_PROFILE_HASH)
        rows = loads(result.coverage, maximum=64 * 1024 * 1024)[0]["fields"]
        self.assertTrue(verify_coverage(inv.fields, rows))
        self.assertGreater(len(rows), len(loads(result.provenance, maximum=64 * 1024 * 1024)))
        self.assertTrue(any(r["presence"] == "absent" for r in rows))
        self.assertTrue(any(r["exactHex"] == "0x" + b'[]'.hex() or r["pointer"].endswith("/corrects") for r in rows))
        retained = loads(result.sidecar, maximum=64 * 1024 * 1024)["publicSources"][0]
        self.assertEqual(bytes.fromhex(retained["payloadHex"][2:]), source.payload)
        self.assertEqual(bytes.fromhex(retained["schemaHex"][2:]), source.schema)
        self.assertTrue(retained["inventoryScope"])

    def test_opaque_unselected_record_cannot_veto_or_replace_selected_entity(self):
        bad = assertion_document()
        bad["entities"] = [{"id": "not an IRI", "kind": "person"}]
        bad["assertions"] = [{"hostile": "not admitted"}]
        hostile = record(bad, "hostile", AGENT, "artist", ["2", "0", "0"])
        healthy = run(fixture(), self.profile)
        with_hostile = run(fixture(extra=(hostile,)), self.profile)
        self.assertEqual(healthy.resources, with_hostile.resources)
        self.assertEqual(len(loads(with_hostile.sidecar, maximum=64 * 1024 * 1024)["publicSources"]), 2)
        self.assertEqual(len(loads(with_hostile.coverage, maximum=64 * 1024 * 1024)), 1)
        data = fixture(extra=(hostile,))
        data[2]["entityAuthoritySet"].append(row(hostile) | {"pointer": "/entities/0"})
        with self.assertRaises(MuseumError):
            run(data, self.profile)

    def test_selected_collision_rejects_in_both_orders_and_restricted_records_are_not_exposed(self):
        data = fixture()
        doc = loads(data[0].records[0].payload)
        doc["entities"].append(copy.deepcopy(doc["entities"][0]))
        for entities in (doc["entities"], list(reversed(doc["entities"]))):
            with self.assertRaises(MuseumError):
                run(fixture(entities=entities, assertions=doc["assertions"]), self.profile)
        restricted = record(assertion_document(), "private-secret-identity", AGENT, "artist", ["3", "0", "0"], "restricted")
        result = run(fixture(extra=(restricted,)), self.profile)
        for raw in (result.sidecar, result.coverage, result.provenance, result.report):
            self.assertNotIn(restricted.selector.record_hash.encode(), raw)
            self.assertNotIn(restricted.selector.record_chain_hash.encode(), raw)

    def test_plan_pins_and_order_independent_outputs(self):
        data = fixture()
        healthy = run(data, self.profile)
        for key in ("sourceStateHash", "profileHash", "selectionPolicyHash", "crosswalkHash"):
            plan = copy.deepcopy(data[2])
            plan[key] = schema_id("wrong")
            with self.subTest(key=key), self.assertRaises(MuseumError):
                run((data[0], data[1], plan), self.profile)
        plan = copy.deepcopy(data[2])
        plan["entityAuthoritySet"].reverse()
        reordered = run((data[0], data[1], plan), self.profile)
        self.assertEqual(healthy.resources, reordered.resources)
        self.assertEqual(healthy.coverage, reordered.coverage)
        self.assertEqual(healthy.provenance, reordered.provenance)
        self.assertNotEqual(healthy.report, reordered.report)  # exact plan identity remains different
        with self.assertRaises(MuseumError):
            project_fixture(data[0], dumps(data[1]), dumps(data[2]), selection_hash=keccak256(dumps(data[1])),
                plan_hash=H, profile_hash=H, profile=self.profile)

    def test_provenance_source_fields_are_actual_and_resource_hashes_bind_exact_bytes(self):
        data = fixture()
        result = run(data, self.profile)
        inv = {r["pointer"]: r for r in loads(result.coverage, maximum=64 * 1024 * 1024)[0]["fields"]}
        for p in loads(result.provenance, maximum=64 * 1024 * 1024):
            self.assertEqual(p["source"]["recordHash"], data[0].records[0].selector.record_hash)
            self.assertIn(p["sourcePointer"], inv)
            self.assertEqual(inv[p["sourcePointer"]]["disposition"], "mapped")
            self.assertTrue(p["rule"].startswith("urn:6529stream:museum:projection:v1:"))
        report = loads(result.report, maximum=64 * 1024 * 1024)
        self.assertEqual(report["coverageHash"], keccak256(result.coverage))
        self.assertEqual(report["provenanceHash"], keccak256(result.provenance))
        self.assertEqual(report["sidecarHash"], keccak256(result.sidecar))
        for resource, entry in zip(result.resources, report["entities"]):
            self.assertEqual(entry["id"], resource.identifier)
            self.assertEqual(entry["contentHash"], keccak256(resource.content))
            self.assertEqual(entry["expandedHash"], keccak256(resource.expanded))

    def test_mapping_review_is_consumed_before_resource_projection(self):
        initial = fixture()
        doc = loads(initial[0].records[0].payload)
        doc["assertions"][0]["origin"] = "human_mapping"
        data = fixture(entities=doc["entities"], assertions=doc["assertions"])
        source = data[0].records[0]
        original = row(source)
        a = doc["assertions"][0]
        review_doc = assertion_document()
        review = review_doc["assertions"][0]
        review.update(id="urn:fixture:projection-review", subject=a["id"], relation=REVIEW_RELATION,
            assertingAgent="urn:fixture:reviewer", mappingRule=REVIEW_MAPPING_RULE,
            object={"literal": review_literal({"assertionRecord": original,
                "assertionRevisionHash": keccak256(dumps(a)), "profileHash": H,
                "mappingRule": a["mappingRule"], "disposition": "reviewed"})})
        review_record = record(review_doc, "projection-review", "urn:fixture:reviewer", "curator", ["2", "0", "0"])
        with_review = fixture(entities=doc["entities"], assertions=doc["assertions"], extra=(review_record,))
        unselected = run(with_review, self.profile)
        master = next(loads(r.content) for r in unselected.resources if r.identifier == "urn:fixture:master")
        self.assertNotIn("digitally_shows", master)
        with_review[1]["reviewerAuthoritySet"] = [row(review_record)]
        with_review[2]["selectionPolicyHash"] = keccak256(dumps(with_review[1]))
        with_review[2]["externalEntities"].append({"id": "urn:fixture:reviewer", "kind": "person"})
        admitted = run(with_review, self.profile)
        master = next(loads(r.content) for r in admitted.resources if r.identifier == "urn:fixture:master")
        self.assertEqual(master["digitally_shows"][0]["id"], "urn:fixture:image")
        claim = next(c for c in loads(admitted.sidecar, maximum=64 * 1024 * 1024)["selectedClaims"]
                     if c["selector"] == original)
        self.assertEqual(claim["basis"], "reviewed_under_selected_policy")
        self.assertEqual(claim["reviewEvidence"][0]["reviewRecord"], row(review_record))
        self.assertEqual(len(loads(admitted.coverage, maximum=64 * 1024 * 1024)), 2)

    def test_external_reference_has_explicit_kind_and_plan_provenance(self):
        data = fixture()
        data[2]["entityAuthoritySet"] = [r for r in data[2]["entityAuthoritySet"] if r["pointer"] != "/entities/3"]
        with self.assertRaises(MuseumError):
            run(data, self.profile)
        data[2]["externalEntities"].append({"id": "urn:fixture:place", "kind": "place"})
        result = run(data, self.profile)
        report = loads(result.report)
        self.assertNotIn("urn:fixture:place", {r.identifier for r in result.resources})
        self.assertEqual(len(report["externalTypeProvenance"]), 2)
        for row_ in report["externalTypeProvenance"]:
            self.assertEqual(row_["externalEntity"], "urn:fixture:place")
            self.assertEqual(row_["planHash"], keccak256(dumps(data[2])))
        data[2]["externalEntities"][-1]["kind"] = "token"
        typed_only = run(data, self.profile)
        image = next(loads(r.content) for r in typed_only.resources if r.identifier == "urn:fixture:image")
        self.assertNotIn("represents", image)  # typed extension reference cannot be mislabeled as Place

    def test_selected_conflicts_withhold_resources_but_preserve_all_exact_claims(self):
        data = fixture()
        doc = loads(data[0].records[0].payload)
        second = copy.deepcopy(doc["assertions"][0])
        second.update(id="urn:fixture:conflicting-claim", object={"entity": "urn:fixture:place"})
        doc["assertions"].append(second)
        data = fixture(entities=doc["entities"], assertions=doc["assertions"])
        data[1]["singleValuedRelations"] = [LA + "digitally_shows"]
        data[2]["selectionPolicyHash"] = keccak256(dumps(data[1]))
        result = run(data, self.profile)
        master = next(loads(r.content) for r in result.resources if r.identifier == "urn:fixture:master")
        self.assertNotIn("digitally_shows", master)
        withheld = loads(result.sidecar, maximum=64 * 1024 * 1024)["withheldClaims"]
        self.assertEqual(len(withheld), 2)
        self.assertEqual({c["assertion"]["object"]["entity"] for c in withheld}, {"urn:fixture:image", "urn:fixture:place"})
        self.assertTrue(any(c["assertion"] == second for c in withheld))


if __name__ == "__main__":
    unittest.main()
