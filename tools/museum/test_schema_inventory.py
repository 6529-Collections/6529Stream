"""Applicable schema inventory against literal branch and exact-value oracles."""

import copy
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .coverage import Field, inventory, verify_coverage
from .fixtures import documents
from .schema_inventory import EVALUATION_PROFILE_HASH, inventory_exact
from .schemas import NAMES, obj, schemas


ROOT = Path(__file__).resolve().parents[2]
H = "0x" + "11" * 32
A = "0x" + "22" * 20
DIALECT = "https://json-schema.org/draft/2020-12/schema"


def evaluate(schema, value):
    s, p = dumps(schema), dumps(value)
    return inventory_exact(s, p, schema_hash=keccak256(s), payload_hash=keccak256(p),
                           evaluation_hash=EVALUATION_PROFILE_HASH)


def selector():
    return {"recordHash": H, "subjectId": H, "schemaId": H, "schemaHash": H,
            "recordType": H, "host": A, "recorder": A, "authorizationClass": "ARTIST_SIGNER",
            "pointer": "/exact/~0value~1path", "recordIndex": str((1 << 64) - 1), "recordChainHash": H}


def assertion_document():
    hash_ref = {"algorithm": "1", "digest": H, "canonicalizationId": H}
    return {"profileSchemaId": schema_id(NAMES[0]), "profileHash": H,
            "anchorSubject": {"kind": "token", "subjectId": H}, "entities": [],
            "assertions": [{"id": "urn:fixture:assertion", "subject": "urn:fixture:physical-print",
                "relation": "urn:fixture:dimension", "object": {"literal": {
                    "lexicalValue": "40.00", "datatype": "urn:fixture:exact-decimal", "language": None,
                    "unit": "cm", "precision": "two decimal places"}},
                "assertingAgent": "urn:fixture:artist", "createdAt": "2026-09-12T00:00:00Z",
                "evidence": [{"source": hash_ref, "selectorType": "json_pointer", "selector": "/dimension",
                              "basis": "own_signed_statement"}],
                "origin": "direct_statement", "reviewStatus": "unreviewed", "mappingRule": "urn:fixture:rule",
                "rationale": "Synthetic shape only; no recorded authority", "reviewEvidence": [],
                "corrects": [], "disputes": []}],
            "sourceRecords": [selector()], "authorityAlignments": []}


class ExactSchemaInventory(unittest.TestCase):
    def test_all_eight_foundation_denominators_remain_exact(self):
        corpus = documents()
        schema = corpus.pop("source.schema.json")
        self.assertEqual(len(corpus), 8)
        for name, value in corpus.items():
            with self.subTest(name=name):
                result = evaluate(schema, value)
                self.assertEqual(result.fields, inventory(schema, value))
                self.assertEqual(result.branches, ())
                self.assertEqual(result.schema_hash, keccak256(dumps(schema)))
                self.assertEqual(result.payload_hash, keccak256(dumps(value)))

    def test_actual_assertion_schema_refs_oneof_and_exact_literal(self):
        raw_schema = (ROOT / "schemas/museum/STREAM_SEMANTIC_ASSERTION_V1.json").read_bytes()
        self.assertEqual(raw_schema, dumps(schemas()[NAMES[1]]))
        value = assertion_document()
        result = evaluate(loads(raw_schema), value)
        fields = {f.pointer: f for f in result.fields}
        self.assertEqual(fields["/assertions/0/object/literal/lexicalValue"],
                         Field("/assertions/0/object/literal/lexicalValue", "present", "str", b'"40.00"'))
        self.assertEqual(fields["/assertions/0/object/literal/language"].exact, b"null")
        self.assertEqual(fields["/assertions/0/effectiveDate"].presence, "absent")
        self.assertEqual(fields["/sourceRecords/0/recordIndex"].exact, b'"18446744073709551615"')
        self.assertNotIn("/assertions/0/object/entity", fields)  # inapplicable oneOf branch
        branch = next(d for d in result.branches if d.instance_pointer == "/assertions/0/object")
        self.assertEqual(branch.schema_hash, keccak256(raw_schema))
        self.assertEqual(branch.schema_location, "#/$defs/assertion/properties/object")
        self.assertEqual(branch.valid_branches, ("#/$defs/assertion/properties/object/oneOf/1",))
        dispositions = [{"pointer": f.pointer, "presence": f.presence, "exactHex": "0x" + f.exact.hex(),
                         "disposition": "retained_stream_only", "rule": "urn:fixture:exact", "reason": "No projection claim"}
                        for f in result.fields]
        self.assertTrue(verify_coverage(result.fields, dispositions))
        with self.assertRaises(MuseumError):
            verify_coverage(result.fields, dispositions[:-1])
        for kind in ("overflow", "extra", "missing", "trailing_date"):
            bad = copy.deepcopy(value)
            if kind == "overflow":
                bad["sourceRecords"][0]["recordIndex"] = str(1 << 64)
            elif kind == "extra":
                bad["assertions"][0]["object"]["entity"] = "urn:fixture:other"
            elif kind == "missing":
                del bad["assertions"][0]["evidence"]
            else:
                bad["assertions"][0]["createdAt"] += "\n"
            with self.subTest(kind=kind), self.assertRaises(MuseumError):
                evaluate(loads(raw_schema), bad)

    def test_anyof_retains_every_valid_branch_and_only_its_optional_fields(self):
        schema = obj({"mode": {"type": "string"}, "x": {"type": "string"}}, ["mode", "x"])
        schema["anyOf"] = [
            {"properties": {"mode": {"const": "both"}, "a": {"type": "string"}}},
            {"properties": {"mode": {"const": "both"}, "b": {"type": "string"}}},
            {"properties": {"mode": {"const": "other"}, "inactive": {"type": "string"}}},
        ]
        result = evaluate(schema, {"mode": "both", "x": "kept"})
        self.assertEqual(result.branches[0].valid_branches, ("#/anyOf/0", "#/anyOf/1"))
        self.assertEqual({f.pointer for f in result.fields}, {"", "/mode", "/x", "/a", "/b"})
        self.assertEqual({f.pointer for f in result.fields if f.presence == "absent"}, {"/a", "/b"})

    def test_profile_and_export_candidate_schemas_retain_complete_exact_source_shapes(self):
        hash_ref = {"algorithm": "1", "digest": H, "canonicalizationId": H}
        doc = {"path": "fixture-only.json", "contentHash": hash_ref, "byteLength": "2", "mediaType": "application/json"}
        profile = {"standards": {"cidocCrm": "7.1.3", "linkedArtModel": "1.0.0", "jsonLd": "1.1"},
                   "dependencyIndex": doc, "crosswalkDocuments": [doc], "selectionRules": doc,
                   "validationDocuments": [doc], "classPropertyTables": [doc], "termCatalogs": [],
                   "limits": {"recordPayloadBytes": "24576", "sstore2DataBytes": "24575", "rawChunkBytes": "8192",
                              "documents": "512", "chunks": "4096", "aggregateBytes": "16777216",
                              "referenceDepth": "8", "jsonDepth": "64"}, "supersedesSchemaId": None}
        export = {"profileSchemaId": schema_id(NAMES[0]), "profileHash": H,
                  "sourceState": {"chainId": "1", "core": A, "collectionId": str((1 << 256) - 1),
                                  "tokenId": str((1 << 256) - 1), "anchorSubject": {"kind": "token", "subjectId": H},
                                  "canonicalCitation": "Synthetic shape only", "blockNumber": "0", "blockHash": H,
                                  "finalityQualifier": "fixture_only", "recordHeads": [selector()], "disclosurePolicyHash": H},
                  "selectionPolicyHash": H, "sourceAuthoritySet": [], "reviewerAuthoritySet": [],
                  "components": {k: doc for k in ("entityIndex", "assertions", "provenance", "authoritySnapshots",
                      "dependencyLock", "coverage", "validation", "identityCorrespondence")}, "resources": [],
                  "completeness": "incomplete", "conformance": {"streamProfile": "not_evaluated",
                      "linkedArtModel": "not_evaluated", "linkedArtApi": "not_claimed"}, "previousExport": None}

        def actual_paths(value, pointer=""):
            found = {pointer}
            if isinstance(value, dict):
                for key, child in value.items():
                    found |= actual_paths(child, pointer + "/" + key.replace("~", "~0").replace("/", "~1"))
            elif isinstance(value, list):
                for index, child in enumerate(value):
                    found |= actual_paths(child, pointer + "/" + str(index))
            return found

        for name, value in ((NAMES[0], profile), (NAMES[2], export)):
            schema = loads((ROOT / "schemas/museum" / (name + ".json")).read_bytes())
            result = evaluate(schema, value)
            self.assertEqual({f.pointer for f in result.fields}, actual_paths(value))
            self.assertEqual(len(result.fields), len(actual_paths(value)))
        result = evaluate(schemas()[NAMES[2]], export)
        token = next(f for f in result.fields if f.pointer == "/sourceState/tokenId")
        self.assertEqual(token.exact, b'"115792089237316195423570985008687907853269984665640564039457584007913129639935"')
        export["sourceState"]["tokenId"] = str(1 << 256)
        with self.assertRaises(MuseumError):
            evaluate(schemas()[NAMES[2]], export)

    def test_oneof_ambiguous_or_zero_valid_branches_reject_before_inventory(self):
        for schema, value in (({"oneOf": [{"type": "integer"}, {"type": "number"}]}, 1),
                              ({"oneOf": [{"type": "string"}, {"type": "null"}]}, True)):
            with self.assertRaises(MuseumError):
                evaluate(schema, value)

    def test_repeated_allof_reference_is_not_a_cycle(self):
        schema = {"$schema": DIALECT, "$defs": {"text": {"type": "string", "minLength": 1}},
                  "allOf": [{"$ref": "#/$defs/text"}, {"$ref": "#/$defs/text"}]}
        result = evaluate(schema, "same")
        self.assertEqual(result.fields, (Field("", "present", "str", b'"same"'),))
        self.assertEqual(result.branches[0].valid_branches, ("#/allOf/0", "#/allOf/1"))

    def test_recursive_values_advance_instance_path_and_retain_custom_unsigned_checks(self):
        schema = obj({"value": {"type": "string", "x-stream-unsigned-bits": 8},
                      "children": {"type": "array", "items": {"$ref": "#"}}})
        schema["$schema"] = DIALECT
        value = {"value": "255", "children": [{"value": "0", "children": []}]}
        result = evaluate(schema, value)
        self.assertEqual({f.pointer for f in result.fields},
                         {"", "/value", "/children", "/children/0", "/children/0/value", "/children/0/children"})
        value["children"][0]["value"] = "256"
        with self.assertRaises(MuseumError):
            evaluate(schema, value)
        with self.assertRaises(MuseumError):
            evaluate({"$schema": DIALECT, "$ref": "#"}, "loop")

    def test_unknown_keywords_formats_remote_and_unused_missing_refs_fail_preflight(self):
        cases = [{"type": "string", "format": "ignored-unknown"}, {"type": "string", "unknownKeyword": True},
                 {"type": "string", "$defs": {"unused": {"$ref": "https://foreign.invalid/schema"}}},
                 {"type": "string", "$defs": {"unused": {"$ref": "#/$defs/missing"}}},
                 {"type": "string", "$defs": {"unused": {"$id": "urn:foreign", "type": "string"}}},
                 {"type": "string", "$ref": "#/description", "description": "not a schema"},
                 {"type": "string", "properties": []}, {"type": "string", "anyOf": {}},
                 {"type": "string", "x-stream-unsigned-bits": True},
                 {"type": "string", "$defs": {"unused": {"$ref": "#/$defs/%75nused"}}}]
        for schema in cases:
            with self.subTest(schema=schema), patch("socket.socket", side_effect=AssertionError("network forbidden")), self.assertRaises(MuseumError):
                evaluate(schema, "valid leaf otherwise")

    def test_inputs_and_evaluation_profile_are_three_independent_pins(self):
        schema, payload = dumps({"type": "string"}), b'"exact"'
        hashes = {"schema_hash": keccak256(schema), "payload_hash": keccak256(payload),
                  "evaluation_hash": EVALUATION_PROFILE_HASH}
        for key in hashes:
            with self.subTest(pin=key), self.assertRaises(MuseumError):
                inventory_exact(schema, payload, **(hashes | {key: H}))
        result = inventory_exact(schema, payload, **hashes)
        self.assertEqual(result.fields[0].exact, payload)
        for raw in (b'"exact"\n', b'1.0', b'9007199254740992', b'{"a":1,"a":2}'):
            with self.subTest(raw=raw), self.assertRaises(MuseumError):
                inventory_exact(schema, raw, schema_hash=keccak256(schema), payload_hash=keccak256(raw),
                                evaluation_hash=EVALUATION_PROFILE_HASH)

    def test_escaped_property_pointers_and_null_empty_absent_are_distinct(self):
        schema = obj({"a/b~c": {"type": ["string", "null"]}, "empty": {"type": "array", "items": {"type": "string"}},
                      "missing": {"type": "string"}}, ["a/b~c", "empty"])
        result = evaluate(schema, {"a/b~c": None, "empty": []})
        self.assertEqual(result.fields, (
            Field("", "present", "object", b'["a/b~c","empty"]'),
            Field("/a~1b~0c", "present", "null", b"null"),
            Field("/empty", "present", "array", b'"0"'),
            Field("/missing", "absent", "absent", b""),
        ))

    def test_validation_work_budget_rejects_expanding_refs_with_same_leaf_control(self):
        definitions = {"leaf": {"type": "string"}}
        previous = "leaf"
        for index in range(17):
            name = "level" + str(index)
            definitions[name] = {"allOf": [{"$ref": "#/$defs/" + previous}, {"$ref": "#/$defs/" + previous}]}
            previous = name
        schema = {"$schema": DIALECT, "$defs": definitions, "$ref": "#/$defs/" + previous}
        with self.assertRaisesRegex(MuseumError, "validation keyword step limit"):
            evaluate(schema, "same leaf")
        schema["$ref"] = "#/$defs/level2"
        self.assertEqual(evaluate(schema, "same leaf").fields, (Field("", "present", "str", b'"same leaf"'),))

    def test_inventory_budget_includes_absent_property_expansion(self):
        schema = {"type": "array", "items": obj({"p" + str(i): {"type": "string"} for i in range(100)}, [])}
        with self.assertRaisesRegex(MuseumError, "inventory evaluation step limit"):
            evaluate(schema, [{} for _ in range(600)])
        result = evaluate(schema, [{}])
        self.assertEqual(len(result.fields), 102)
        self.assertEqual(sum(f.presence == "absent" for f in result.fields), 100)

    def test_module_cli_requires_three_pins_and_emits_exact_fields_without_authority_claim(self):
        schema, value = {"oneOf": [{"type": "string"}, {"type": "null"}]}, "40.00"
        expected = evaluate(schema, value)
        with tempfile.TemporaryDirectory() as directory:
            source, spec = Path(directory) / "source.json", Path(directory) / "schema.json"
            source.write_bytes(dumps(value))
            spec.write_bytes(dumps(schema))
            command = [sys.executable, "-m", "tools.museum.schema_inventory", str(spec), str(source),
                       "--schema-hash", expected.schema_hash, "--source-hash", expected.payload_hash,
                       "--evaluation-hash", EVALUATION_PROFILE_HASH]
            run = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            self.assertEqual(run.returncode, 0, run.stderr.decode(errors="replace"))
            result = loads(run.stdout)
            self.assertEqual(result["sourceHash"], expected.payload_hash)
            self.assertEqual(result["evaluationProfileHash"], EVALUATION_PROFILE_HASH)
            self.assertEqual(result["fields"], [{"pointer": "", "presence": "present", "kind": "str", "exactHex": "0x2234302e303022"}])
            self.assertEqual(result["branches"][0]["validBranches"], ["#/oneOf/0"])
            self.assertFalse(any(result["claims"].values()))
            bad = subprocess.run(command[:-1] + [H], cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            self.assertNotEqual(bad.returncode, 0)
            self.assertEqual(bad.stdout, b"")


if __name__ == "__main__":
    unittest.main()
