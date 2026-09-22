"""Offline prospective-profile regressions; no registration or source acceptance."""

from copy import deepcopy
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

from .account_profile import AccountProjectionProfile, JCS_ID, POLICY_NAME as V1_POLICY
from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .dependencies import Limits, OfflineDocuments
from .independent_wire import RAW_BYTES
from .review import BODY_SCHEMA_BYTES, _validate
from .schemas import NAMES as V1_NAMES
from .test_schema_inventory import assertion_document, selector
from .typed_authority_profile import TypedAuthorityProfile, NAME as V2_NAME, NAMES as V2_NAMES, SCHEMAS as V2_SCHEMAS
from . import qualified_review_profile as q


ROOT = Path(__file__).resolve().parents[2] / "schemas/museum"


class QualifiedReviewProfileTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with patch("socket.socket", side_effect=AssertionError("profile must stay offline")):
            cls.v1 = AccountProjectionProfile(ROOT)
            cls.v2 = TypedAuthorityProfile(ROOT)
            cls.profile = q.QualifiedAccountReviewProfile(ROOT)

    def test_original_profile_documents_and_assertion_rules_keep_original_hashes(self):
        self.assertEqual(self.v1.profile_hash, "0xa7c728732beeb6fa94be1e870cd54dc470a6050986e084393e7308a1b542075f")
        self.assertEqual(self.v2.profile_bytes,
            (ROOT / "typed-account-profile" / (V2_NAME + ".json")).read_bytes())
        self.assertEqual(self.profile.typed_profile_hash, self.v2.profile_hash)
        for name, document in self.v2.documents.items():
            with self.subTest(name=name):
                self.assertEqual(self.profile.documents[name], document)
                self.assertEqual(self.profile.document_canonicalizations[name], self.v2.document_canonicalizations[name])
        for name, predecessor in self.v2.document_predecessors.items():
            self.assertEqual(self.profile.document_predecessors[name], predecessor)
        rules = self.profile.assertion_rules()
        self.assertEqual({k: rules[k] for k in self.v2.assertion_rules()}, self.v2.assertion_rules())
        self.assertEqual(rules[schema_id(V1_NAMES[1])][2], self.v1.profile_hash)
        self.assertEqual(rules[schema_id(V2_NAMES[1])][2], self.v2.profile_hash)
        self.assertNotIn(self.profile.profile_hash, (self.v1.profile_hash, self.v2.profile_hash))

    def test_new_rule_binds_distinct_schema_profile_and_original_review_literal(self):
        rules = self.profile.assertion_rules()
        self.assertEqual(len(rules), 3)
        self.assertEqual(rules[schema_id(q.NAMES[1])],
            (q.ASSERTION_SCHEMA_BYTES, schema_id(q.NAMES[0]), self.profile.profile_hash))
        self.assertEqual(self.profile.documents["STREAM_SEMANTIC_REVIEW_BODY_V1"], (0, BODY_SCHEMA_BYTES))
        for old, new in zip(V2_NAMES, q.NAMES):
            value = loads(q.SCHEMAS[new], maximum=524288, canonical=True)
            self.assertEqual(value["title"], new)
            self.assertEqual(value["x-stream-schema-id"], schema_id(new))
            self.assertEqual(value["x-stream-profile"]["supersedesSchemaId"], schema_id(old))
        rules.clear()
        self.assertEqual(len(self.profile.assertion_rules()), 3)

    def test_new_assertion_requires_its_profile_schema_and_typed_continuation_layout(self):
        self.assertEqual(loads(q.ASSERTION_SCHEMA_BYTES, maximum=524288)["$defs"],
            loads(V2_SCHEMAS[V2_NAMES[1]], maximum=524288)["$defs"])
        value = assertion_document()
        value.update(profileSchemaId=schema_id(q.NAMES[0]), profileHash=self.profile.profile_hash)
        value["entities"] = [{"id": "urn:test:type", "kind": "type", "names": [],
            "declaringAgent": "urn:test:account", "sourceRecords": [selector()],
            "predecessors": [], "continuation": None}]
        self.assertEqual(_validate(q.ASSERTION_SCHEMA_BYTES, dumps(value)), value)
        for original in (V1_NAMES[0], V2_NAMES[0]):
            wrong = deepcopy(value); wrong["profileSchemaId"] = schema_id(original)
            with self.subTest(original=original), self.assertRaises(MuseumError):
                _validate(q.ASSERTION_SCHEMA_BYTES, dumps(wrong))
        missing = deepcopy(value); del missing["entities"][0]["continuation"]
        with self.assertRaises(MuseumError): _validate(q.ASSERTION_SCHEMA_BYTES, dumps(missing))
        value["entities"][0]["continuation"] = {"selector": selector(),
            "declarationHash": "0x" + "12" * 32, "rationale": "Exact prior declaration"}
        self.assertEqual(_validate(q.ASSERTION_SCHEMA_BYTES, dumps(value)), value)
        with self.assertRaises(MuseumError):
            _validate(V2_SCHEMAS[V2_NAMES[1]], dumps(value))

    def test_policy_explicitly_limits_qualification_and_preserves_old_self_only_meaning(self):
        policy = loads(q.POLICY_BYTES, canonical=True)
        self.assertEqual(policy["selectionMode"], "qualified_recorded_account_selection")
        self.assertEqual(policy["qualificationMode"], "authenticated_account_under_selected_policy")
        self.assertIs(policy["newProfileRequiredForMappingsAndReviews"], True)
        self.assertIn("must refuse", policy["independentHumanReview"])
        self.assertIn("explicit selection-policy opt-in", policy["selfReview"])
        self.assertIn("cannot veto", policy["conflicts"])
        self.assertIn("rejection-only", policy["conflicts"])
        self.assertIn("chain/Core/host/collection/subject/token/media", policy["conflicts"])
        self.assertIn("withhold self-declared disputed claims", policy["selection"])
        self.assertIn("Withdrawn or disputed reviews", policy["selection"])
        self.assertIn("no write authority", policy["firewall"])
        self.assertIn("Cross-account review is unsupported", loads(self.profile.documents[V1_POLICY][1])["review"])
        self.assertIn("no registration", q.QUALIFICATION)

    def test_crosswalk_adds_new_schema_without_relabelling_retained_documents(self):
        prior = loads(self.v2.crosswalk_bytes, maximum=524288, canonical=True)
        current = loads(self.profile.crosswalk_bytes, maximum=524288, canonical=True)
        self.assertEqual(len(prior["rules"]), len(current["rules"]))
        extra = {"schemaId": schema_id(q.NAMES[1]), "schemaHash": keccak256(q.ASSERTION_SCHEMA_BYTES)}
        for old, new in zip(prior["rules"], current["rules"]):
            self.assertEqual(new["additionalSourceSchemas"], [*old["additionalSourceSchemas"], extra])
            restored = dict(new, additionalSourceSchemas=old["additionalSourceSchemas"], authorityRule=old["authorityRule"])
            self.assertEqual(restored, old)
        self.assertEqual(self.profile.documents["STREAM_ACCOUNT_CROSSWALK_V2"][1], self.v2.crosswalk_bytes)
        self.assertEqual(loads(self.profile.identity)["crosswalkHash"], keccak256(self.profile.crosswalk_bytes))
        self.assertNotIn(self.profile.profile_hash.encode(), self.profile.crosswalk_bytes)

    def test_complete_original_upstream_bytes_are_retained_with_raw_canonicalization(self):
        index = loads(self.profile.documents[q.DEPENDENCY_NAME][1], maximum=524288, canonical=True)
        original = loads(self.v2.documents["STREAM_ACCOUNT_DEPENDENCIES_V2"][1], maximum=524288, canonical=True)
        self.assertEqual(index["documents"], original["documents"])
        self.assertEqual(len(index["documents"]), 19)
        actual = {}
        for subroot, path in ((ROOT, "linked-art-v2/validation-index.json"), (ROOT / "standards", "vocabulary-index.json")):
            source = loads((subroot / path).read_bytes(), maximum=524288)
            reader = OfflineDocuments(subroot, source)
            actual.update({row["sourceUri"]: reader.load(row["sourceUri"]) for row in source["documents"]})
        for row in index["documents"]:
            payload = self.profile.documents[row["documentName"]][1]
            self.assertEqual(payload, actual[row["sourceUri"]])
            self.assertEqual(row["contentHash"], {"algorithm": "1", "digest": keccak256(payload), "canonicalizationId": RAW_BYTES})
            self.assertEqual(self.profile.document_canonicalizations[row["documentName"]], RAW_BYTES)

    def test_interpretation_index_is_complete_and_has_no_new_profile_commitment_cycle(self):
        profile = self.profile
        index = loads(profile.documents[q.DEPENDENCY_NAME][1], maximum=524288, canonical=True)
        rows = index["interpretationDocuments"]
        self.assertEqual({row["name"] for row in rows}, set(profile.documents) - {q.NAME, q.DEPENDENCY_NAME})
        self.assertEqual(len(rows), len({row["name"] for row in rows}))
        for row in rows:
            kind, raw = profile.documents[row["name"]]
            self.assertEqual(row, {"name": row["name"], "documentId": schema_id(row["name"]), "kind": str(kind),
                "contentHash": {"algorithm": "1", "digest": keccak256(raw),
                    "canonicalizationId": profile.document_canonicalizations[row["name"]]}, "byteLength": str(len(raw))})
        self.assertEqual(index["registryPredecessors"], dict(profile.document_predecessors))
        self.assertTrue(set(profile.document_predecessors.values()) <= {schema_id(name) for name in profile.documents})
        self.assertNotIn(profile.profile_hash.encode(), profile.documents[q.DEPENDENCY_NAME][1])
        body = loads(profile.profile_bytes)
        self.assertEqual(body["selectionRules"]["contentHash"]["digest"], keccak256(q.POLICY_BYTES))
        self.assertEqual(body["dependencyIndex"]["contentHash"]["digest"], keccak256(profile.documents[q.DEPENDENCY_NAME][1]))
        self.assertEqual(body["supersedesSchemaId"], schema_id(V2_NAME))
        self.assertEqual(profile.document_canonicalizations[q.NAME], JCS_ID)

    def test_generated_seven_files_equal_exact_current_documents(self):
        generated = q.generated_documents(self.profile)
        self.assertEqual(set(generated), {*q.NAMES, q.NAME, q.POLICY_NAME, q.CROSSWALK_NAME, q.DEPENDENCY_NAME})
        self.assertTrue(set(generated).isdisjoint(self.v2.documents))
        for name, raw in generated.items():
            self.assertEqual((ROOT / q.DIRECTORY / (name + ".json")).read_bytes(), raw)
        self.assertEqual(set(path.stem for path in (ROOT / q.DIRECTORY).glob("*.json")), set(generated))
        with self.assertRaises(TypeError): self.profile.documents[q.NAME] = (2, b"replacement")

    def test_wrong_expected_profile_pin_refuses(self):
        with self.assertRaisesRegex(MuseumError, "profile pin mismatch"):
            q.QualifiedAccountReviewProfile(ROOT, expected_hash=self.v2.profile_hash)
        self.assertEqual(q.QualifiedAccountReviewProfile(ROOT, expected_hash=self.profile.profile_hash).profile_hash,
            self.profile.profile_hash)

    def test_final_closure_enforces_document_chunk_and_aggregate_bounds(self):
        for limits in (Limits(documents=len(self.profile.documents) - 1), Limits(chunks=1), Limits(aggregate_bytes=1)):
            with self.subTest(limits=limits), patch.object(q, "Limits", return_value=limits):
                with self.assertRaisesRegex(MuseumError, "registered closure bound"):
                    q.QualifiedAccountReviewProfile(ROOT)

    def test_changed_original_dependency_chunk_is_not_silently_rebuilt(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name in ("linked-art-v2", "standards"):
                shutil.copytree(ROOT / name, root / name)
            index = loads((root / "linked-art-v2/validation-index.json").read_bytes(), maximum=524288)
            chunk = root / index["documents"][0]["chunks"][0]["path"]
            raw = chunk.read_bytes()
            chunk.write_bytes(bytes([raw[0] ^ 1]) + raw[1:])
            with self.assertRaisesRegex(MuseumError, "chunk hash mismatch"):
                q.QualifiedAccountReviewProfile(root)


if __name__ == "__main__":
    unittest.main()
