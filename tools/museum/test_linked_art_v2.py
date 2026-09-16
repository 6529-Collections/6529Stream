"""New pinned upstream shape profile; historical v1 remains independently valid."""

import copy
import json
from pathlib import Path
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads
from .dependencies import OfflineDocuments
from .linked_art import PinnedLinkedArt, _repair
from .schema_interpretation import conjoin_duplicate_schema
from .test_linked_art import digital

ROOT = Path(__file__).resolve().parents[2] / "schemas/museum"
CONTEXT = "https://linked.art/ns/v1/linked-art.json"
CRM = "http://www.cidoc-crm.org/cidoc-crm/"


def abstract():
    return {"@context": CONTEXT, "id": "urn:fixture:conceptual-work", "type": "PropositionalObject",
            "_label": "An explicitly declared conceptual work", "identified_by": [{"type": "Name", "content": "Exact conception"}],
            "about": [{"id": "urn:fixture:place", "type": "Place"}]}


class PinnedLinkedArtV2(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw = (ROOT / "linked-art-v2/validation-policy.json").read_bytes()
        cls.policy = loads(cls.raw, maximum=524288)
        cls.documents = OfflineDocuments(ROOT, loads((ROOT / "linked-art-v2/validation-index.json").read_bytes(), maximum=65536))
        cls.profile = PinnedLinkedArt(cls.documents, cls.raw, keccak256(cls.raw))
        old_docs = OfflineDocuments(ROOT, loads((ROOT / "linked-art/validation-index.json").read_bytes(), maximum=65536))
        old_raw = (ROOT / "linked-art/validation-policy.json").read_bytes()
        cls.old = PinnedLinkedArt(old_docs, old_raw, keccak256(old_raw))

    def test_abstract_work_has_its_own_class_and_offline_shape(self):
        with patch("socket.socket", side_effect=AssertionError("no live context")):
            result = self.profile.validate_and_expand(dumps(abstract()))
        expanded = loads(result.expanded_bytes)[0]
        self.assertEqual(expanded["@type"], [CRM + "E89_Propositional_Object"])
        self.assertEqual(expanded[CRM + "P129_is_about"][0]["@id"], "urn:fixture:place")
        self.assertNotIn(CRM + "P108i_was_produced_by", expanded)
        self.assertNotIn(CRM + "P7_took_place_at", expanded)
        self.assertEqual(result.source_bytes, dumps(abstract()))

    def test_same_work_equivalence_rejects_copied_linguistic_and_unrelated_classes(self):
        doc = abstract()
        doc["equivalent"] = [{"id": "urn:fixture:same-concept", "type": "PropositionalObject"}]
        expanded = loads(self.profile.validate_and_expand(dumps(doc)).expanded_bytes)[0]
        equivalent = expanded["https://linked.art/ns/terms/equivalent"][0]
        self.assertEqual(equivalent["@id"], "urn:fixture:same-concept")
        for kind in ("LinguisticObject", "Person", "DigitalObject", "HumanMadeObject", "Set"):
            doc["equivalent"][0]["type"] = kind
            with self.subTest(kind=kind), self.assertRaises(MuseumError):
                self.profile.validate_and_expand(dumps(doc))

    def test_old_profile_retains_exact_bytes_outputs_and_abstract_rejection(self):
        before = {uri: self.old.derived_schema_bytes(uri) for uri in self.old.derived_schema_hashes}
        with self.assertRaises(MuseumError):
            self.old.validate_and_expand(dumps(abstract()))
        old = self.old.validate_and_expand(dumps(digital()))
        new = self.profile.validate_and_expand(dumps(digital()))
        self.assertEqual(old.expanded_bytes, new.expanded_bytes)
        self.assertNotEqual(old.policy_hash, new.policy_hash)
        self.assertEqual(before, {uri: self.old.derived_schema_bytes(uri) for uri in before})
        self.assertEqual(self.old._documents.load(CONTEXT), self.documents.load(CONTEXT))

    def test_complete_new_closure_and_original_root_gap_are_explicit(self):
        self.assertEqual(len(self.profile.derived_schema_hashes), 14)
        self.assertEqual(len(self.profile.schema_references), 837)
        root = "https://linked.art/api/1.0/schema/linked-art.json"
        original = self.documents.jsonld_loader(root)["document"]
        derived = json.loads(self.profile.derived_schema_bytes(root))
        entry = {"$ref": "https://linked.art/api/1.0/schema/abstract.json"}
        self.assertNotIn(entry, original["anyOf"])
        self.assertEqual(derived["anyOf"], original["anyOf"] + [entry])
        self.assertEqual(len(original["anyOf"]), 11)
        source = self.documents.jsonld_loader(entry["$ref"])["document"]
        self.assertEqual(source["properties"]["equivalent"]["allOf"][1]["items"]["$ref"], "core.json#/$defs/LinguisticObjectRef")
        fixed = json.loads(self.profile.derived_schema_bytes(entry["$ref"]))
        self.assertEqual(fixed["properties"]["equivalent"]["allOf"][1]["items"]["$ref"], "core.json#/$defs/AbstractWorkRef")

    def test_root_append_requires_exact_array_and_absent_new_entry(self):
        rule = copy.deepcopy(self.policy["schemaRepairs"][0])
        original = self.documents.jsonld_loader(rule["schemaUri"])["document"]
        for mode in ("old_array", "existing", "wrong_pointer", "wrong_item"):
            value, bad = copy.deepcopy(original), copy.deepcopy(rule)
            if mode == "old_array":
                value["anyOf"].reverse()
            elif mode == "existing":
                value["anyOf"].append(bad["appendItem"])
            elif mode == "wrong_pointer":
                bad["pointer"] = "/properties"
            else:
                bad["appendItem"] = {"type": "object"}
            with self.subTest(mode=mode), self.assertRaises(MuseumError):
                _repair(value, bad)
        _repair(original, rule)
        self.assertEqual(original["anyOf"][-1], rule["appendItem"])

    def test_policy_original_hash_and_reference_target_guards(self):
        for mode in ("source_hash", "ref_preimage", "target", "missing_abstract", "supporting_text"):
            policy = copy.deepcopy(self.policy)
            if mode == "source_hash":
                policy["schemaDocuments"][0]["contentHash"] = "0x" + "00" * 32
            elif mode == "ref_preimage":
                policy["schemaRepairs"][1]["expectedValue"] = "core.json#/$defs/AnyRef"
            elif mode == "target":
                policy["schemaRepairs"][1]["replacementValue"] = "core.json#/$defs/Unavailable"
            elif mode == "missing_abstract":
                policy["schemaDocuments"] = [r for r in policy["schemaDocuments"] if not r["sourceUri"].endswith("abstract.json")]
            else:
                policy["supportingDocuments"][0]["contentHash"] = "0x" + "00" * 32
            raw = dumps(policy)
            with self.subTest(mode=mode), self.assertRaises(MuseumError):
                PinnedLinkedArt(self.documents, raw, keccak256(raw))
        self.profile.validate_and_expand(dumps(abstract()))

    def test_version_does_not_silently_enable_new_repair_for_old_policy(self):
        policy = copy.deepcopy(self.policy)
        policy["version"] = "1"
        raw = dumps(policy)
        with self.assertRaises(MuseumError):
            PinnedLinkedArt(self.documents, raw, keccak256(raw))
        policy["version"] = "99"
        raw = dumps(policy)
        with self.assertRaises(MuseumError):
            PinnedLinkedArt(self.documents, raw, keccak256(raw))

    def test_unknown_properties_context_drift_and_false_physical_production_reject(self):
        for change in ({"produced_by": {"type": "Production"}}, {"unknown": "ignored?"},
                       {"@context": [CONTEXT]}, {"id": "relative-work"}):
            with self.subTest(change=change), self.assertRaises(MuseumError):
                self.profile.validate_and_expand(dumps(abstract() | change))
        self.profile.validate_and_expand(dumps(abstract()))

    def test_duplicate_member_interpretation_preserves_both_original_constraints(self):
        rule = self.policy["duplicateSchemaInterpretations"][0]
        raw = self.documents.load(rule["schemaUri"])
        # Ordinary context/dependency parsing still rejects the original pair.
        with self.assertRaises(MuseumError):
            self.documents.jsonld_loader(rule["schemaUri"])
        derived = json.loads(self.profile.derived_schema_bytes(rule["schemaUri"]))
        self.assertEqual(derived["properties"]["used_for"], {"allOf": rule["expectedValues"]})
        doc = {"@context": CONTEXT, "id": "urn:fixture:print", "type": "HumanMadeObject", "_label": "Print",
               "used_for": [{"type": "Activity", "_label": "Recorded use"}]}
        self.profile.validate_and_expand(dumps(doc))
        for invalid in ({"type": "Activity"}, [{"type": "Person"}], ["Activity"]):
            with self.subTest(invalid=invalid), self.assertRaises(MuseumError):
                self.profile.validate_and_expand(dumps(doc | {"used_for": invalid}))
        self.assertEqual(raw, self.documents.load(rule["schemaUri"]))

    def test_duplicate_pair_guards_reject_swapped_third_nested_missing_and_foreign_source(self):
        rule = self.policy["duplicateSchemaInterpretations"][0]
        first, second = rule["expectedValues"]
        def source(values):
            return b'{"properties":{' + b','.join(b'"used_for":' + dumps(v) for v in values) + b'}}'
        good = source([first, second])
        local = rule | {"contentHash": keccak256(good)}
        self.assertEqual(conjoin_duplicate_schema(good, local)["properties"]["used_for"], {"allOf": [first, second]})
        for raw in (source([second, first]), source([first, second, second]), source([first]),
                    b'{"properties":{"used_for":{},"used_for":{}},"a":{"x":1,"x":2}}'):
            with self.subTest(raw=raw), self.assertRaises(MuseumError):
                conjoin_duplicate_schema(raw, local | {"contentHash": keccak256(raw)})
        with self.assertRaises(MuseumError):
            conjoin_duplicate_schema(good + b' ', local)
        with self.assertRaises(MuseumError):
            conjoin_duplicate_schema(good, local | {"pointer": "/other/used_for"})

    def test_derived_duplicate_schema_conjoins_instead_of_first_or_last_wins(self):
        from jsonschema import Draft202012Validator
        # Independent distinct restrictions prove conjunction behavior even
        # though the retained upstream pair has equivalent Activity-array shape.
        values = [{"required": ["first"]}, {"required": ["second"]}]
        raw = b'{"properties":{"used_for":{"required":["first"]},"used_for":{"required":["second"]}}}'
        rule = self.policy["duplicateSchemaInterpretations"][0] | {
            "contentHash": keccak256(raw), "expectedValues": values}
        validator = Draft202012Validator(conjoin_duplicate_schema(raw, rule))
        self.assertTrue(validator.is_valid({"used_for": {"first": 1, "second": 2}}))
        self.assertFalse(validator.is_valid({"used_for": {"first": 1}}))
        self.assertFalse(validator.is_valid({"used_for": {"second": 2}}))

    def test_duplicate_parser_rejects_other_duplicates_after_a_valid_expected_pair(self):
        rule = self.policy["duplicateSchemaInterpretations"][0]
        first, second = rule["expectedValues"]
        prefix = b'{"properties":{"used_for":' + dumps(first) + b',"used_for":' + dumps(second) + b'},"annotation":'
        good = prefix + b'"ordinary"}'
        self.assertEqual(conjoin_duplicate_schema(good, rule | {"contentHash": keccak256(good)})["annotation"], "ordinary")
        nested = prefix + b'{"unrelated":1,"unrelated":2}}'
        with self.assertRaisesRegex(MuseumError, "invalid interpreted schema JSON") as rejected:
            conjoin_duplicate_schema(nested, rule | {"contentHash": keccak256(nested)})
        self.assertIsInstance(rejected.exception.__cause__, MuseumError)
        self.assertEqual(str(rejected.exception.__cause__), "unapproved duplicate schema key")
        for suffix in (b'NaN}', b'Infinity}', b'1e999}', b'9007199254740992}', b'"\\ud800"}',
                       b'[' * 65 + b'0' + b']' * 65 + b'}'):
            raw = prefix + suffix
            with self.subTest(suffix=suffix), self.assertRaises(MuseumError):
                conjoin_duplicate_schema(raw, rule | {"contentHash": keccak256(raw)})

    def test_new_document_order_and_supporting_uri_failure_are_deterministic(self):
        policy = copy.deepcopy(self.policy)
        policy["schemaDocuments"].reverse()
        raw = dumps(policy)
        reverse = PinnedLinkedArt(self.documents, raw, keccak256(raw))
        self.assertEqual(dict(reverse.derived_schema_hashes), dict(self.profile.derived_schema_hashes))
        self.assertEqual(reverse.schema_references, self.profile.schema_references)
        policy["supportingDocuments"][0]["sourceUri"] = []
        raw = dumps(policy)
        with self.assertRaises(MuseumError):
            PinnedLinkedArt(self.documents, raw, keccak256(raw))


if __name__ == "__main__":
    unittest.main()
