"""Actual offline processor and upstream shape checks; not a full crosswalk."""

import copy
import json
from pathlib import Path
import tempfile
import subprocess
import sys
import unittest
from unittest.mock import patch
from jsonschema import Draft202012Validator
from jsonschema.exceptions import SchemaError

from .canonical import MuseumError, dumps, keccak256, loads
from .dependencies import OfflineDocuments
from .linked_art import PinnedLinkedArt, _reference_closure, _repair, format_checker
from .chunk_documents import write_document

ROOT = Path(__file__).resolve().parents[2] / "schemas/museum"
CONTEXT = "https://linked.art/ns/v1/linked-art.json"
CRM = "http://www.cidoc-crm.org/cidoc-crm/"


def digital():
    return {"@context": CONTEXT, "id": "urn:fixture:master:" + str((1 << 256) - 1),
            "type": "DigitalObject", "_label": "Synthetic master; described only",
            "digitally_shows": [{"id": "urn:fixture:image", "type": "VisualItem", "_label": "Image content"}],
            "created_by": {"type": "Creation", "carried_out_by": [{"id": "urn:fixture:artist",
                "type": "Person", "_label": "Synthetic artist"}],
                "took_place_at": [{"id": "urn:fixture:place", "type": "Place", "_label": "Asserted place"}]}}


class ActualOfflineLinkedArt(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.index = loads((ROOT / "linked-art/validation-index.json").read_bytes(), maximum=65536)
        cls.documents = OfflineDocuments(ROOT, cls.index)
        cls.policy_bytes = (ROOT / "linked-art/validation-policy.json").read_bytes()
        cls.profile = PinnedLinkedArt(cls.documents, cls.policy_bytes, keccak256(cls.policy_bytes))

    def test_actual_digital_creation_and_place_expand_to_exact_predicates(self):
        raw = dumps(digital())
        with patch("socket.socket", side_effect=AssertionError("network forbidden")):
            result = self.profile.validate_and_expand(raw)
        self.assertEqual(result.source_bytes, raw)
        expanded = loads(result.expanded_bytes)[0]
        self.assertEqual(expanded["@id"], digital()["id"])
        self.assertEqual(expanded["@type"], ["http://www.ics.forth.gr/isl/CRMdig/D1_Digital_Object"])
        self.assertEqual(expanded["https://linked.art/ns/terms/digitally_shows"][0]["@id"], "urn:fixture:image")
        creation = expanded[CRM + "P94i_was_created_by"][0]
        self.assertEqual(creation["@type"], [CRM + "E65_Creation"])
        self.assertEqual(creation[CRM + "P14_carried_out_by"][0]["@id"], "urn:fixture:artist")
        self.assertEqual(creation[CRM + "P7_took_place_at"][0]["@id"], "urn:fixture:place")

    def test_physical_print_production_uses_different_relations(self):
        print_ = {"@context": CONTEXT, "id": "urn:fixture:print", "type": "HumanMadeObject", "_label": "Described print",
                  "shows": [{"id": "urn:fixture:image", "type": "VisualItem", "_label": "Image content"}],
                  "produced_by": {"type": "Production"}}
        expanded = loads(self.profile.validate_and_expand(dumps(print_)).expanded_bytes)[0]
        self.assertEqual(expanded[CRM + "P65_shows_visual_item"][0]["@id"], "urn:fixture:image")
        self.assertEqual(expanded[CRM + "P108i_was_produced_by"][0]["@type"], [CRM + "E12_Production"])
        with self.assertRaises(MuseumError):
            self.profile.validate_and_expand(dumps(digital() | {"produced_by": {"type": "Production"}}))

    def test_unknown_property_context_override_and_relative_identity_reject(self):
        original = digital()
        for mutation in (original | {"misspelled_relation": "lost"}, original | {"id": "relative/path"},
                         original | {"@context": [CONTEXT, "https://foreign.invalid/context"]},
                         original | {"@context": "https://foreign.invalid/context"},
                         original | {"created_by": {"type": "Creation", "@context": {"type": "@id"}}}):
            with self.subTest(mutation=mutation), patch("socket.socket", side_effect=AssertionError("network forbidden")), self.assertRaises(MuseumError):
                self.profile.validate_and_expand(dumps(mutation))
        self.profile.validate_and_expand(dumps(original))

    def test_schema_context_and_policy_hashes_are_independent_pins(self):
        original = loads(self.policy_bytes)
        with self.assertRaises(MuseumError):
            PinnedLinkedArt(self.documents, dumps(original | {"version": "2"}), keccak256(self.policy_bytes))
        for key in ("context", "schema"):
            changed = copy.deepcopy(original)
            if key == "context":
                changed["contextHash"] = "0x" + "00" * 32
            else:
                changed["schemaDocuments"][0]["contentHash"] = "0x" + "00" * 32
            raw = dumps(changed)
            with self.assertRaises(MuseumError):
                PinnedLinkedArt(self.documents, raw, keccak256(raw))
        with patch("socket.socket", side_effect=AssertionError("network forbidden")):
            self.profile.validate_and_expand(dumps(digital()))

    def test_upstream_dialect_defect_requires_exact_declared_repair(self):
        uri = "https://linked.art/api/1.0/schema/core.json"
        original_raw = self.documents.load(uri)
        original = self.documents.jsonld_loader(uri)["document"]
        with self.assertRaises(SchemaError):
            Draft202012Validator.check_schema(original)
        self.assertEqual(original["definitions"]["ContextStringOrArray"]["anyOf"][1]["items"],
                         [{"type": "string", "format": "uri"}])
        derived_bytes = self.profile.derived_schema_bytes(uri)
        self.assertEqual(keccak256(derived_bytes), self.profile.derived_schema_hashes[uri])
        derived = json.loads(derived_bytes)
        repaired = derived["definitions"]["ContextStringOrArray"]["anyOf"][1]
        self.assertNotIn("items", repaired)
        self.assertEqual(repaired["prefixItems"], [{"type": "string", "format": "uri"}])
        # Original tuple semantics constrain only the first element. The fixed
        # context profile rejects arrays independently, not by silently changing this rule.
        tuple_validator = Draft202012Validator(repaired, format_checker=format_checker())
        tuple_validator.validate([CONTEXT, 17])
        self.assertFalse(tuple_validator.is_valid([17]))
        self.assertFalse(tuple_validator.is_valid(["relative/context"]))
        already_changed = copy.deepcopy(original)
        already_changed["definitions"]["ContextStringOrArray"]["anyOf"][1]["prefixItems"] = []
        with self.assertRaises(MuseumError):
            _repair(already_changed, loads(self.policy_bytes)["schemaRepairs"][0])
        self.assertEqual(self.documents.load(uri), original_raw)
        # Caller inspection gets immutable bytes; mutating a parsed copy has no effect.
        derived.clear()
        self.assertEqual(self.profile.derived_schema_bytes(uri), derived_bytes)
        for mutation in ("missing", "wrong_value", "wrong_pointer", "duplicate", "unknown_document"):
            policy = loads(self.policy_bytes)
            if mutation == "missing":
                policy["schemaRepairs"] = []
            elif mutation == "wrong_value":
                policy["schemaRepairs"][0]["expectedItems"] = [{"type": "number"}]
            elif mutation == "wrong_pointer":
                policy["schemaRepairs"][0]["pointer"] = "/definitions/ContextStringOrArray/anyOf/0"
            elif mutation == "duplicate":
                policy["schemaRepairs"] *= 2
            else:
                policy["schemaRepairs"][0]["schemaUri"] = "urn:unavailable"
            raw = dumps(policy)
            with self.subTest(mutation=mutation), self.assertRaises(MuseumError):
                PinnedLinkedArt(self.documents, raw, keccak256(raw))

    def test_document_order_and_missing_schema_have_exact_local_controls(self):
        policy = loads(self.policy_bytes)
        policy["schemaDocuments"].reverse()
        raw = dumps(policy)
        reordered = PinnedLinkedArt(self.documents, raw, keccak256(raw))
        self.assertEqual(reordered.derived_schema_hashes, self.profile.derived_schema_hashes)
        self.assertEqual(reordered.validate_and_expand(dumps(digital())).expanded_bytes,
                         self.profile.validate_and_expand(dumps(digital())).expanded_bytes)
        policy["schemaDocuments"] = [r for r in policy["schemaDocuments"] if not r["sourceUri"].endswith("digital.json")]
        raw = dumps(policy)
        with patch("socket.socket", side_effect=AssertionError("network forbidden")), self.assertRaises(MuseumError):
            PinnedLinkedArt(self.documents, raw, keccak256(raw))
        self.profile.validate_and_expand(dumps(digital()))

    def test_same_context_uri_later_bytes_do_not_reuse_another_profiles_cache(self):
        original_result = self.profile.validate_and_expand(dumps(digital()))
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            rows = []
            later_context = self.documents.load(CONTEXT).replace(b"rdfs:label", b"urn:fixture:later-label")
            self.assertNotEqual(later_context, self.documents.load(CONTEXT))
            for row in self.index["documents"]:
                uri = row["sourceUri"]
                raw = later_context if uri == CONTEXT else self.documents.load(uri)
                rows.append(write_document(root, raw, {"sourceUri": uri, "revision": "synthetic-cache-control",
                    "retrievedAt": "2026-09-12T00:00:00Z", "mediaType": row["mediaType"], "dependencies": row["dependencies"]}))
            documents = OfflineDocuments(root, {"documents": rows})
            policy = loads(self.policy_bytes)
            policy["contextHash"] = keccak256(later_context)
            raw = dumps(policy)
            later = PinnedLinkedArt(documents, raw, keccak256(raw))
            with patch("socket.socket", side_effect=AssertionError("network forbidden")):
                later_result = later.validate_and_expand(dumps(digital()))
                original_again = self.profile.validate_and_expand(dumps(digital()))
            self.assertEqual(original_again, original_result)
            self.assertNotEqual(later_result.expanded_bytes, original_result.expanded_bytes)
            node = loads(later_result.expanded_bytes)[0]
            self.assertIn("urn:fixture:later-label", node)
            self.assertNotIn("http://www.w3.org/2000/01/rdf-schema#label", node)

    def test_uri_and_datetime_formats_do_not_depend_on_optional_host_packages(self):
        checker = format_checker()
        self.assertEqual(set(checker.checkers), {"uri", "date-time"})
        for format_, valid, invalid in (("uri", "urn:fixture:entity", "relative/entity"),
                                       ("date-time", "2026-09-12T00:00:00Z", "2026-02-30T00:00:00Z")):
            self.assertTrue(checker.conforms(valid, format_))
            self.assertFalse(checker.conforms(invalid, format_))

    def test_formats_consume_the_whole_input_without_trimming_or_leap_second_coercion(self):
        checker = format_checker()
        for format_, valid in (("uri", "urn:fixture:entity"), ("date-time", "2026-09-12T00:00:00Z")):
            for suffix in ("\n", "\r\n", " ", "\t"):
                with self.subTest(format=format_, suffix=suffix):
                    self.assertFalse(checker.conforms(valid + suffix, format_))
                    self.assertFalse(checker.conforms(suffix + valid, format_))
            self.assertTrue(checker.conforms(valid, format_))
        self.assertFalse(checker.conforms("2016-12-31T23:59:60Z", "date-time"))
        self.assertTrue(checker.conforms("2016-12-31t23:59:59z", "date-time"))
        with self.assertRaises(MuseumError):
            self.profile.validate_and_expand(dumps(digital() | {"id": "urn:fixture:entity\n"}))
        self.profile.validate_and_expand(dumps(digital()))

    def test_right_acquisition_establishes_and_invalidates_actual_rights(self):
        document = {"@context": CONTEXT, "id": "urn:fixture:right-activity", "type": "Activity",
                    "_label": "Synthetic rights account; no title or custody claim",
                    "classified_as": [{"id": "http://vocab.getty.edu/aat/300055863", "type": "Type"}],
                    "part": [{"type": "RightAcquisition",
                              "establishes": [{"type": "Right", "_label": "New asserted right"}],
                              "invalidates": [{"type": "Right", "_label": "Prior asserted right"}]}]}
        raw = dumps(document)
        with patch("socket.socket", side_effect=AssertionError("network forbidden")):
            result = self.profile.validate_and_expand(raw)
        self.assertEqual(result.source_bytes, raw)
        part = loads(result.expanded_bytes)[0][CRM + "P9_consists_of"][0]
        self.assertEqual(part["@type"], ["https://linked.art/ns/terms/RightAcquisition"])
        for relation, label in (("establishes", "New asserted right"), ("invalidates", "Prior asserted right")):
            right = part["https://linked.art/ns/terms/" + relation][0]
            self.assertEqual(right["@type"], [CRM + "E30_Right"])
            self.assertEqual(right["http://www.w3.org/2000/01/rdf-schema#label"], [{"@value": label}])
            bad = copy.deepcopy(document)
            bad["part"][0][relation][0]["type"] = "HumanMadeObject"
            with self.subTest(relation=relation), self.assertRaises(MuseumError):
                self.profile.validate_and_expand(dumps(bad))
        self.assertEqual(self.profile.validate_and_expand(raw), result)

    def test_exact_right_reference_repairs_and_complete_constructor_closure(self):
        uri = "https://linked.art/api/1.0/schema/provenance.json"
        original_raw = self.documents.load(uri)
        original = self.documents.jsonld_loader(uri)["document"]
        derived = json.loads(self.profile.derived_schema_bytes(uri))
        for relation in ("establishes", "invalidates"):
            self.assertEqual(original["definitions"]["RightAcquisition"]["properties"][relation]["items"]["$ref"],
                             "core.json#/definitions/LegalRight")
            self.assertEqual(derived["definitions"]["RightAcquisition"]["properties"][relation]["items"]["$ref"],
                             "core.json#/definitions/Right")
            self.assertIn((uri, f"/definitions/RightAcquisition/properties/{relation}/items/$ref",
                           "https://linked.art/api/1.0/schema/core.json", "/definitions/Right"),
                          self.profile.schema_references)
        self.assertEqual(self.documents.load(uri), original_raw)
        for relation_index in (1, 2):
            for mutation in ("missing", "wrong_old", "wrong_path", "missing_target", "scalar_target", "wrong_hash"):
                policy = loads(self.policy_bytes)
                rule = policy["schemaRepairs"][relation_index]
                if mutation == "missing":
                    policy["schemaRepairs"].pop(relation_index)
                elif mutation == "wrong_old":
                    rule["expectedValue"] = "core.json#/definitions/Right"
                elif mutation == "wrong_path":
                    rule["pointer"] = "/definitions/RightAcquisition/properties/unavailable/items/$ref"
                elif mutation == "missing_target":
                    rule["replacementValue"] = "core.json#/definitions/Unavailable"
                elif mutation == "scalar_target":
                    rule["replacementValue"] = "core.json#/definitions/Right/title"
                else:
                    next(row for row in policy["schemaDocuments"] if row["sourceUri"] == uri)["contentHash"] = "0x" + "00" * 32
                raw = dumps(policy)
                with self.subTest(relation=relation_index, mutation=mutation), self.assertRaises(MuseumError):
                    PinnedLinkedArt(self.documents, raw, keccak256(raw))

    def test_reference_preflight_checks_unused_definitions_and_allows_semantic_recursion(self):
        uri = "https://example.invalid/schema.json"
        recursive = {"$id": uri, "$defs": {"recursive": {"$ref": "#/$defs/recursive"}}, "type": "string"}
        expected = ((uri, "/$defs/recursive/$ref", uri, "/$defs/recursive"),)
        self.assertEqual(_reference_closure({uri: recursive}), expected)
        for ref in ("#/$defs/missing", "https://foreign.invalid/schema.json", "#/type", "#/$defs/~2bad",
                    "#/$defs/recursive\n", "#/$defs/%invalid"):
            bad = copy.deepcopy(recursive)
            bad["$defs"]["recursive"]["$ref"] = ref
            with self.subTest(ref=ref), self.assertRaises(MuseumError):
                _reference_closure({uri: bad})
        for addition in ({"$id": "https://foreign.invalid/nested"}, {"$dynamicRef": "#recursive"}, {"$anchor": "recursive"}):
            bad = copy.deepcopy(recursive)
            bad["$defs"]["recursive"].update(addition)
            with self.assertRaises(MuseumError):
                _reference_closure({uri: bad})

    def test_module_entrypoint_verifies_literal_example_with_explicit_policy_pin(self):
        example = ROOT / "linked-art/examples/digital.json"
        self.assertEqual(example.read_bytes(), dumps(digital()))
        command = [sys.executable, "-m", "tools.museum.linked_art", str(example),
                   "--policy-hash", keccak256(self.policy_bytes), "--dependency-root", str(ROOT)]
        run = subprocess.run(command, cwd=ROOT.parents[1], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.assertEqual(run.returncode, 0, run.stderr.decode(errors="replace"))
        result = loads(run.stdout, maximum=65536)
        self.assertEqual(result["mode"], "candidate_unregistered_validation")
        self.assertEqual(result["sourceHash"], keccak256(example.read_bytes()))
        self.assertEqual(result["expandedHash"], keccak256(dumps(result["expanded"])))
        self.assertEqual(result["derivedSchemaHashes"], dict(self.profile.derived_schema_hashes))
        self.assertFalse(any(result["claims"].values()))


if __name__ == "__main__":
    unittest.main()
