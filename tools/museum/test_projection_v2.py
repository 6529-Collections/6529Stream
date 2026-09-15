"""Explicit work/content distinction, full source inventory and version parity."""

import copy
from pathlib import Path
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads
from .projection import CROSSWALK_BYTES, CROSSWALK_HASH, ProjectionProfile
from .projection_v2 import (CONTENT, CONTENT_KIND, CRM, LA, STRING, CROSSWALK_V2_BYTES,
                            CROSSWALK_V2_HASH, ProjectionProfileV2)
from .source import FixtureSourceAdapter
from .test_projection import AGENT, entity, fixture, run
from .test_review import record, row
from .test_schema_inventory import assertion_document

ROOT = Path(__file__).resolve().parents[2] / "schemas/museum"


def literal(text, **kwargs):
    return {"literal": {"lexicalValue": text, "datatype": STRING, "language": None, "unit": None, "precision": None} | kwargs}


def assertion(name, subject, predicate, obj):
    return assertion_document()["assertions"][0] | {
        "id": "urn:fixture:claim:" + name, "subject": "urn:fixture:" + subject, "relation": predicate, "object": obj}


def fixture_v2(*, entities=None, assertions=None, extra=()):
    data = fixture(entities=entities, assertions=assertions, extra=extra)
    data[1]["singleValuedRelations"].extend([CONTENT_KIND, CONTENT])
    data[2].update(version="2", crosswalkHash=CROSSWALK_V2_HASH,
                   selectionPolicyHash=keccak256(dumps(data[1])))
    return data


def linguistic_fixture(*, content="Spoken words — e\u0301\r\n40.00", extra_assertions=()):
    entities = [entity("urn:fixture:recording", "digital_object"), entity("urn:fixture:transcript", "statement"),
                entity("urn:fixture:paper", "physical_object"), entity("urn:fixture:place", "place")]
    assertions = [assertion("kind", "transcript", CONTENT_KIND, literal("linguistic")),
                  assertion("text", "transcript", CONTENT, literal(content)),
                  assertion("digital", "recording", LA + "digitally_carries", {"entity": "urn:fixture:transcript"}),
                  assertion("physical", "paper", CRM + "P128_carries", {"entity": "urn:fixture:transcript"}),
                  assertion("about", "transcript", CRM + "P129_is_about", {"entity": "urn:fixture:place"}),
                  *extra_assertions]
    return fixture_v2(entities=entities, assertions=assertions)


class AbstractNonvisualProjection(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        vocab = keccak256((ROOT / "standards/vocabulary-policy.json").read_bytes())
        cls.profile = ProjectionProfileV2(ROOT, CROSSWALK_V2_BYTES, crosswalk_hash=CROSSWALK_V2_HASH,
            validation_hash=keccak256((ROOT / "linked-art-v2/validation-policy.json").read_bytes()), vocabulary_hash=vocab)
        cls.old = ProjectionProfile(ROOT, CROSSWALK_BYTES, crosswalk_hash=CROSSWALK_HASH,
            validation_hash=keccak256((ROOT / "linked-art/validation-policy.json").read_bytes()), vocabulary_hash=vocab)

    def test_abstract_work_is_explicit_separate_and_never_invented(self):
        data = fixture_v2()
        with patch("socket.socket", side_effect=AssertionError("no live standards")):
            result = run(data, self.profile)
        resources = {r.identifier: loads(r.expanded)[0] for r in result.resources}
        self.assertEqual(len(resources), 5)
        self.assertEqual(resources["urn:fixture:conception"]["@type"], [CRM + "E89_Propositional_Object"])
        self.assertEqual(resources["urn:fixture:master"]["@type"], ["http://www.ics.forth.gr/isl/CRMdig/D1_Digital_Object"])
        self.assertNotIn(CRM + "P108i_was_produced_by", resources["urn:fixture:conception"])
        source = loads(data[0].records[0].payload)
        without = run(fixture_v2(entities=source["entities"][:-1], assertions=source["assertions"]), self.profile)
        self.assertEqual(len(without.resources), 4)
        self.assertFalse(any(loads(r.content)["type"] == "PropositionalObject" for r in without.resources))

    def test_abstract_about_and_exact_name_do_not_become_carrier_or_event_location(self):
        data = fixture_v2(entities=[entity("urn:fixture:idea", "abstract_work", [{"value": "40.00 — idea", "kind": "preferred", "language": None}]),
                                    entity("urn:fixture:place", "place")],
                          assertions=[assertion("about", "idea", CRM + "P129_is_about", {"entity": "urn:fixture:place"})])
        result = run(data, self.profile)
        idea = next(r for r in result.resources if r.identifier.endswith(":idea"))
        self.assertEqual(loads(idea.content)["identified_by"], [{"type": "Name", "content": "40.00 — idea"}])
        self.assertEqual(loads(idea.expanded)[0][CRM + "P129_is_about"], [{"@id": "urn:fixture:place", "@type": [CRM + "E53_Place"]}])
        self.assertNotIn(CRM + "P7_took_place_at", loads(idea.expanded)[0])

    def test_linguistic_text_and_both_carriers_have_exact_expansion_and_provenance(self):
        exact = "Spoken words — e\u0301\r\n40.00 " + str((1 << 256) - 1)
        data = linguistic_fixture(content=exact)
        result = run(data, self.profile)
        resources = {r.identifier: loads(r.expanded)[0] for r in result.resources}
        self.assertEqual(resources["urn:fixture:transcript"]["@type"], [CRM + "E33_Linguistic_Object"])
        self.assertEqual(resources["urn:fixture:transcript"][CRM + "P190_has_symbolic_content"], [{"@value": exact}])
        for carrier, predicate in (("recording", LA + "digitally_carries"), ("paper", CRM + "P128_carries")):
            self.assertEqual(resources["urn:fixture:" + carrier][predicate],
                             [{"@id": "urn:fixture:transcript", "@type": [CRM + "E33_Linguistic_Object"]}])
        provenance = loads(result.provenance, maximum=67108864)
        for entity_id, target in (("transcript", "/type"), ("recording", "/digitally_carries/0/type")):
            self.assertTrue(any(p["entity"] == "urn:fixture:" + entity_id and p["targetPointer"] == target
                                and p["sourcePointer"] == "/assertions/0/object/literal/lexicalValue" for p in provenance))
        coverage = {f["pointer"]: f for f in loads(result.coverage, maximum=67108864)[0]["fields"]}
        self.assertEqual(coverage["/assertions/1/object/literal/lexicalValue"]["exactHex"], "0x" + dumps(exact).hex())
        self.assertEqual(coverage["/assertions/1/object/literal/lexicalValue"]["disposition"], "mapped")

    def test_sound_software_and_multimedia_keep_exact_e73_relationships_and_history(self):
        for kind in ("nonlinguistic_sound", "software", "structured_multimedia"):
            with self.subTest(kind=kind):
                claims = [assertion("kind", "content", CONTENT_KIND, literal(kind)),
                    assertion("carrier", "master", LA + "digitally_carries", {"entity": "urn:fixture:content"}),
                    assertion("duration", "master", "urn:fixture:duration", literal("00:03:40.000", datatype="urn:fixture:exact-duration", unit="s", precision="milliseconds")),
                    assertion("runtime", "content", "urn:fixture:execution-environment", literal("OS 4.0; render(seed=0xffff);\n")),
                    assertion("derivation", "master", "urn:fixture:byte-derivation", {"entity": "urn:fixture:source"})]
                data = fixture_v2(entities=[entity("urn:fixture:master", "digital_object"),
                    entity("urn:fixture:source", "digital_object"), entity("urn:fixture:content", "information_object")], assertions=claims)
                result = run(data, self.profile)
                self.assertEqual(len(result.resources), 2)
                self.assertTrue(all(loads(r.content)["type"] == "DigitalObject" for r in result.resources))
                master = next(loads(r.content) for r in result.resources if r.identifier.endswith(":master"))
                self.assertNotIn("digitally_carries", master)
                sidecar = loads(result.sidecar, maximum=67108864)
                extension = sidecar["extensionEntities"][0]
                self.assertEqual((extension["crmClass"], extension["contentKind"]), (CRM + "E73_Information_Object", kind))
                self.assertEqual({dumps(c["assertion"]) for c in sidecar["selectedClaims"]}, {dumps(c) for c in claims})
                self.assertEqual(sidecar["publicSources"][0]["payloadHex"], "0x" + data[0].records[0].payload.hex())
                self.assertTrue(all(f["disposition"] == "retained_stream_only" for f in loads(result.coverage, maximum=67108864)[0]["fields"]
                                    if f["pointer"].startswith(("/assertions/1", "/assertions/2", "/assertions/3", "/assertions/4"))))

    def test_composite_keeps_visual_linguistic_and_generic_content_as_separate_identities(self):
        data = linguistic_fixture()
        doc = loads(data[0].records[0].payload)
        doc["entities"].extend([entity("urn:fixture:composite", "information_object"), entity("urn:fixture:visual", "visual_content")])
        doc["assertions"].extend([
            assertion("composite-kind", "composite", CONTENT_KIND, literal("structured_multimedia")),
            assertion("visual-carrier", "recording", LA + "digitally_shows", {"entity": "urn:fixture:visual"}),
            assertion("generic-carrier", "recording", LA + "digitally_carries", {"entity": "urn:fixture:composite"})])
        result = run(fixture_v2(entities=doc["entities"], assertions=doc["assertions"]), self.profile)
        resources = {r.identifier: loads(r.content) for r in result.resources}
        self.assertEqual(resources["urn:fixture:recording"]["digitally_carries"], [{"id": "urn:fixture:transcript", "type": "LinguisticObject"}])
        self.assertEqual(resources["urn:fixture:recording"]["digitally_shows"], [{"id": "urn:fixture:visual", "type": "VisualItem"}])
        self.assertNotIn("urn:fixture:composite", resources)
        self.assertEqual(loads(result.sidecar, maximum=67108864)["extensionEntities"][0]["id"], "urn:fixture:composite")

    def test_readable_code_and_mime_looking_name_do_not_create_a_linguistic_declaration(self):
        code = "const person = {name: 'human'};\nrender();"
        entities = [entity("urn:fixture:code", "information_object", [{"value": "interview.txt text/plain", "language": None, "kind": "preferred"}])]
        claims = [assertion("code", "code", CONTENT, literal(code))]
        for declared in ([], [assertion("kind", "code", CONTENT_KIND, literal("software"))]):
            result = run(fixture_v2(entities=entities, assertions=claims + declared), self.profile)
            self.assertFalse(result.resources)
            sidecar = loads(result.sidecar, maximum=67108864)
            self.assertEqual(sidecar["extensionEntities"][0]["crmClass"], CRM + "E73_Information_Object")
            self.assertEqual(sidecar["selectedClaims"][0]["assertion"], claims[0])

    def test_kind_conflicts_withhold_specialization_without_hiding_originals(self):
        extra = assertion("other-kind", "transcript", CONTENT_KIND, literal("software"))
        data = linguistic_fixture(extra_assertions=[extra])
        source = loads(data[0].records[0].payload)
        source["entities"][1]["kind"] = "information_object"
        data = fixture_v2(entities=source["entities"], assertions=source["assertions"])
        result = run(data, self.profile)
        self.assertNotIn("urn:fixture:transcript", {r.identifier for r in result.resources})
        sidecar = loads(result.sidecar, maximum=67108864)
        self.assertEqual(len(sidecar["withheldClaims"]), 2)
        self.assertEqual({c["assertion"]["object"]["literal"]["lexicalValue"] for c in sidecar["withheldClaims"]}, {"linguistic", "software"})
        data[1]["sourceAuthoritySet"].reverse()
        data[2]["entityAuthoritySet"].reverse()
        data[2]["selectionPolicyHash"] = keccak256(dumps(data[1]))
        reversed_result = run(data, self.profile)
        self.assertEqual(result.resources, reversed_result.resources)
        self.assertEqual(result.sidecar, reversed_result.sidecar)

    def test_conflicting_content_and_qualified_text_are_not_silently_flattened(self):
        result = run(linguistic_fixture(extra_assertions=[assertion("other-text", "transcript", CONTENT, literal("different"))]), self.profile)
        transcript = next(loads(r.content) for r in result.resources if r.identifier.endswith(":transcript"))
        self.assertEqual(transcript["type"], "LinguisticObject")
        self.assertNotIn("content", transcript)
        self.assertEqual(len(loads(result.sidecar, maximum=67108864)["withheldClaims"]), 2)
        data = linguistic_fixture()
        doc = loads(data[0].records[0].payload)
        for qualifier in ({"language": "en"}, {"unit": "lines"}, {"precision": "verbatim"}, {"datatype": "urn:fixture:code"}):
            assertions = copy.deepcopy(doc["assertions"])
            assertions[1]["object"]["literal"].update(qualifier)
            result = run(fixture_v2(entities=doc["entities"], assertions=assertions), self.profile)
            self.assertNotIn("content", next(loads(r.content) for r in result.resources if r.identifier.endswith(":transcript")))
            self.assertEqual(loads(result.sidecar, maximum=67108864)["selectedClaims"][1]["assertion"], assertions[1])

    def test_wrong_type_and_content_predicates_never_force_linguistic_carriers(self):
        for kind in ("digital_object", "person", "abstract_work", "visual_content"):
            with self.subTest(kind=kind), self.assertRaises(MuseumError):
                run(fixture_v2(entities=[entity("urn:fixture:wrong", kind)],
                    assertions=[assertion("kind", "wrong", CONTENT_KIND, literal("linguistic"))]), self.profile)
        for predicate in (LA + "digitally_carries", CRM + "P128_carries"):
            with self.subTest(predicate=predicate), self.assertRaises(MuseumError):
                run(fixture_v2(entities=[entity("urn:fixture:master", "digital_object"), entity("urn:fixture:image", "visual_content")],
                    assertions=[assertion("wrong", "master", predicate, {"entity": "urn:fixture:image"})]), self.profile)
        for value in (literal("linguistic", language="en"), literal("code"), {"entity": "urn:fixture:place"}):
            with self.subTest(value=value), self.assertRaises(MuseumError):
                run(fixture_v2(entities=[entity("urn:fixture:content", "information_object"), entity("urn:fixture:place", "place")],
                    assertions=[assertion("kind", "content", CONTENT_KIND, value)]), self.profile)

    def test_unselected_hostile_content_and_ineligible_mapping_do_not_specialize_or_veto(self):
        doc = assertion_document()
        doc["assertions"] = [{"malformed": "unselected"}]
        hostile = record(doc, "hostile-v2", "urn:fixture:hostile", "curator", ["10", "0", "0"])
        data = linguistic_fixture()
        old = run(data, self.profile)
        original = loads(data[0].records[0].payload)
        for extra in ((hostile,),):
            result = run(fixture_v2(entities=original["entities"], assertions=original["assertions"], extra=extra), self.profile)
            self.assertEqual(old.resources, result.resources)
            self.assertTrue(any(s["payloadHex"] == "0x" + hostile.payload.hex() for s in loads(result.sidecar, maximum=67108864)["publicSources"]))
        for status in ("human_mapping", "withdrawn"):
            assertions = copy.deepcopy(original["assertions"])
            assertions[0]["origin" if status == "human_mapping" else "reviewStatus"] = status
            result = run(fixture_v2(entities=original["entities"], assertions=assertions), self.profile)
            self.assertNotIn("urn:fixture:transcript", {r.identifier for r in result.resources})

    def test_new_crosswalk_plan_and_required_conflict_policies_are_hash_bound(self):
        data = linguistic_fixture()
        for mode in ("old_plan", "old_crosswalk", "missing_kind", "missing_content"):
            p, plan = copy.deepcopy(data[1]), copy.deepcopy(data[2])
            if mode == "old_plan": plan["version"] = "1"
            elif mode == "old_crosswalk": plan["crosswalkHash"] = CROSSWALK_HASH
            else:
                p["singleValuedRelations"].remove(CONTENT_KIND if mode == "missing_kind" else CONTENT)
                plan["selectionPolicyHash"] = keccak256(dumps(p))
            with self.subTest(mode=mode), self.assertRaises(MuseumError):
                run((data[0], p, plan), self.profile)
        self.assertNotIn(b'"profileHash"', CROSSWALK_V2_BYTES)
        self.assertEqual((ROOT / "projection/crosswalk-v2.json").read_bytes(), CROSSWALK_V2_BYTES)
        self.assertEqual(len(loads(CROSSWALK_V2_BYTES)["rules"]), 22)

    def test_original_profile_output_and_full_record_coverage_stay_exact(self):
        data = fixture()
        old = run(data, self.old)
        run(fixture_v2(), self.profile)
        self.assertEqual(old, run(data, self.old))
        self.assertEqual(len(old.resources), 4)
        self.assertTrue(any(e["kind"] == "abstract_work" for e in loads(old.sidecar, maximum=67108864)["extensionEntities"]))
        result = run(linguistic_fixture(), self.profile)
        from .schema_inventory import EVALUATION_PROFILE_HASH, inventory_exact
        source = linguistic_fixture()[0].records[0]
        inv = inventory_exact(source.schema, source.payload, schema_hash=source.selector.schema_hash,
                              payload_hash=source.payload_hash, evaluation_hash=EVALUATION_PROFILE_HASH)
        rows = loads(result.coverage, maximum=67108864)[0]["fields"]
        self.assertEqual([(f.pointer, f.presence, "0x" + f.exact.hex()) for f in inv.fields],
                         [(r["pointer"], r["presence"], r["exactHex"]) for r in rows])
        self.assertFalse(any(loads(result.report)["claims"].values()))

    def test_external_declared_subject_retains_claim_without_local_resource(self):
        a = assertion("external-about", "unused", CRM + "P129_is_about", {"entity": "urn:fixture:place"})
        a["subject"] = AGENT  # exact external Person already declared by the plan
        for make, profile in ((fixture, self.old), (fixture_v2, self.profile)):
            data = make(entities=[entity("urn:fixture:place", "place")], assertions=[a])
            result = run(data, profile)
            self.assertEqual([r.identifier for r in result.resources], ["urn:fixture:place"])
            self.assertEqual(loads(result.sidecar, maximum=67108864)["selectedClaims"][0]["assertion"], a)

    def test_equivalent_content_claims_and_record_order_keep_identical_resources_and_provenance(self):
        data = linguistic_fixture()
        source = loads(data[0].records[0].payload)
        extra_doc = assertion_document()
        extra_doc["assertions"] = copy.deepcopy(source["assertions"][:2])
        for a in extra_doc["assertions"]: a["id"] += ":same-meaning"
        extra = record(extra_doc, "equivalent-content", AGENT, "artist", ["2", "0", "0"])
        state, p, plan = fixture_v2(entities=source["entities"], assertions=source["assertions"], extra=(extra,))
        p["sourceAuthoritySet"].extend([row(extra) | {"pointer": "/assertions/" + str(i)} for i in range(2)])
        plan["selectionPolicyHash"] = keccak256(dumps(p))
        result = run((state, p, plan), self.profile)
        reverse = FixtureSourceAdapter("projection", tuple(reversed(state.records))).snapshot()
        p = copy.deepcopy(p)
        p.update(sourceStateHash=reverse.commitment, sourceAuthoritySet=list(reversed(p["sourceAuthoritySet"])))
        plan = copy.deepcopy(plan)
        plan.update(sourceStateHash=reverse.commitment, selectionPolicyHash=keccak256(dumps(p)),
                    entityAuthoritySet=list(reversed(plan["entityAuthoritySet"])))
        again = run((reverse, p, plan), self.profile)
        self.assertEqual(result.resources, again.resources)
        self.assertEqual(result.sidecar, again.sidecar)
        self.assertEqual(result.provenance, again.provenance)
        self.assertEqual(result.coverage, again.coverage)
        self.assertNotEqual(result.report, again.report)  # exact source/plan provenance remains distinct

    def test_public_nonvisual_example_keeps_readable_source_and_complete_accounting(self):
        from .package import fixture_state_from_bytes
        path = ROOT / "projection/nonvisual-example"
        state = fixture_state_from_bytes((path / "source-state.json").read_bytes())
        self.assertEqual(state.records[0].payload, (path / "assertion.json").read_bytes())
        result = run((state, loads((path / "selection-policy.json").read_bytes()),
                      loads((path / "projection-plan.json").read_bytes())), self.profile)
        by_id = {r.identifier: loads(r.content) for r in result.resources}
        self.assertEqual(len(by_id), 6)
        self.assertEqual(by_id["urn:fixture:conception"]["type"], "PropositionalObject")
        self.assertEqual(by_id["urn:fixture:transcript"]["type"], "LinguisticObject")
        self.assertEqual(by_id["urn:fixture:transcript"]["content"],
                         "Transcript: silence is intentional.\nDo not normalize this e\u0301 or decimal 40.00.")
        sidecar = loads(result.sidecar, maximum=67108864)
        self.assertEqual(sidecar["extensionEntities"][0]["id"], "urn:fixture:software")
        self.assertEqual(len(sidecar["selectedClaims"]), 10)
        rows = loads(result.coverage, maximum=67108864)[0]["fields"]
        self.assertEqual(next(r for r in rows if r["pointer"] == "/assertions/9/object/literal/lexicalValue")["exactHex"],
                         "0x" + b'"00:03:40.000"'.hex())
        self.assertFalse(any(loads(result.report)["claims"].values()))


if __name__ == "__main__":
    unittest.main()
