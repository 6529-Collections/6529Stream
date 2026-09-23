"""Fast controls for current typed-authority fixture preparation; no Anvil."""
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest.mock import patch

from .authority_v2 import _body, RELATION
from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .current_authority_capture import (AAT_IRI, ENTITY_ID, ROOT, alignment_payload, declaration_payload,
    prepare_arguments, review_payload, synthetic_snapshot, typed_media_plans, validate_snapshot)
from .independent_wire import RAW_BYTES
from .review import REVIEW_RELATION
from .typed_authority_profile import NAMES, TypedAuthorityProfile

H = "0x" + "11" * 32
A = "0x" + "12" * 20


def selector(pointer="", number="11"):
    return {"host": A, "recordHash": "0x" + number * 32, "subjectId": H,
        "schemaId": schema_id(NAMES[1]), "schemaHash": H,
        "recordType": schema_id("INDEPENDENT_SEMANTIC_ASSERTION"), "recorder": A,
        "authorizationClass": "INDEPENDENT_ATTESTOR", "recordIndex": "1",
        "recordChainHash": H, "pointer": pointer}


class CurrentAuthorityCapturePreparation(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.profile = TypedAuthorityProfile(ROOT)
        cls.descriptor, cls.snapshot, cls.pin, cls.mode = synthetic_snapshot()
        cls.parsed, cls.label, cls.type_fact = validate_snapshot(cls.descriptor, cls.snapshot, cls.pin)

    def test_synthetic_fallback_is_explicit_and_snapshot_bound(self):
        metadata = loads(self.descriptor, canonical=True)
        self.assertEqual(metadata["canonicalIri"], AAT_IRI)
        self.assertEqual(metadata["sourceUri"], "https://example.org/fixtures/getty-aat-300033618.rdf.json")
        self.assertIn("not bytes served", metadata["attribution"])
        self.assertEqual(metadata["contentHash"]["canonicalizationId"], RAW_BYTES)
        self.assertEqual(self.parsed["descriptorHash"], self.pin)

    def test_prior_declaration_alignment_and_exact_review_build(self):
        source_raw = dumps({"sourceText": self.label["value"]})
        source = selector("", "21")
        declaration_raw, declaration = declaration_payload(self.profile,
            "urn:6529stream:account:eip155:31337:" + A, H, source, source_raw,
            "2026-09-16T01:00:00Z", self.label)
        declaration_value = loads(declaration_raw, canonical=True)
        self.assertIsNone(declaration_value["entities"][0]["continuation"])
        declaration_selector = selector("/entities/0", "22")
        aligned_raw, assertion = alignment_payload(self.profile,
            "urn:6529stream:account:eip155:31337:" + A, H, source, source_raw,
            declaration_selector, declaration, "2026-09-16T01:00:01Z", self.parsed,
            self.label, self.type_fact)
        aligned = loads(aligned_raw, canonical=True)
        body = _body(assertion)
        self.assertEqual(assertion["relation"], RELATION)
        self.assertEqual(assertion["origin"], "automated_mapping")
        self.assertEqual(body["declaration"]["scope"], "prior_record")
        self.assertEqual(body["declaration"]["selector"], declaration_selector)
        self.assertEqual(body["declaration"]["declarationHash"], keccak256(dumps(declaration)))
        self.assertIn(declaration_selector, aligned["sourceRecords"])
        original = selector("/assertions/0", "23")
        reviewed_raw = review_payload(self.profile,
            "urn:6529stream:account:eip155:31337:" + A, H, original, aligned_raw, assertion,
            "2026-09-16T01:00:02Z")
        reviewed = loads(reviewed_raw, canonical=True)
        self.assertEqual(reviewed["assertions"][0]["relation"], REVIEW_RELATION)
        review_body = loads(reviewed["assertions"][0]["object"]["literal"]["lexicalValue"].encode(), canonical=True)
        self.assertEqual(review_body["assertionRecord"], original)
        self.assertEqual(review_body["assertionRevisionHash"], keccak256(dumps(assertion)))
        self.assertEqual(reviewed["sourceRecords"], [dict(original, pointer="")])
        self.assertLess(len(declaration_raw), 8192)
        self.assertLess(len(aligned_raw), 8192)
        self.assertLess(len(reviewed_raw), 8192)

    def test_mixed_media_plans_advance_only_profile_version_and_dependent_hashes(self):
        base = {"selection.json": dumps({"kept": True}),
            "plan.json": dumps({"version": "account-1", "kept": True}),
            "premis-plan.json": dumps({"linkedArtPlanHash": H, "kept": True}),
            "iiif-plan.json": dumps({"linkedArtPlanHash": H, "premisPlanHash": H, "kept": True}),
            "lido-plan.json": dumps({"linkedArtPlanHash": H, "premisPlanHash": H, "iiifPlanHash": H, "kept": True})}
        source = SimpleNamespace(profile=SimpleNamespace(version="account-2"))
        with patch("tools.museum.current_authority_capture.selected_plans", return_value=base):
            result = typed_media_plans(source)
        self.assertEqual(result["selection.json"], base["selection.json"])
        self.assertEqual(loads(result["plan.json"])["version"], "account-2")
        self.assertEqual(loads(result["premis-plan.json"])["linkedArtPlanHash"], keccak256(result["plan.json"]))
        self.assertEqual(loads(result["iiif-plan.json"])["premisPlanHash"], keccak256(result["premis-plan.json"]))
        self.assertEqual(loads(result["lido-plan.json"])["iiifPlanHash"], keccak256(result["iiif-plan.json"]))

    def test_cli_inputs_are_all_or_none_and_checked_before_capture(self):
        empty = dict(authority_descriptor=None, authority_raw=None, authority_descriptor_hash=None,
            publisher_response=None, publisher_response_sha256=None, publisher_retrieved_at=None)
        args = SimpleNamespace(**empty); prepare_arguments(args)
        self.assertEqual(args.authority_input[3], "synthetic_fixture")
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "descriptor.json"; path.write_bytes(self.descriptor)
            partial = SimpleNamespace(**(empty | {"authority_descriptor": path}))
            with self.assertRaisesRegex(MuseumError, "supplied together"): prepare_arguments(partial)
            response = Path(folder) / "response.json"; response.write_bytes(b'{"head":{},"results":{}}')
            wrong = SimpleNamespace(**(empty | {"publisher_response": response,
                "publisher_response_sha256": "00" * 32, "publisher_retrieved_at": "2026-09-16T01:02:03Z"}))
            with self.assertRaisesRegex(MuseumError, "SHA-256"): prepare_arguments(wrong)

    def test_getty_sparql_results_json_is_not_mislabeled_as_rdf_json(self):
        raw = dumps({"head": {"vars": ["Subject", "Predicate", "Object"]}, "results": {"bindings": []}})
        metadata = loads(self.descriptor); metadata["contentHash"]["digest"] = keccak256(raw)
        metadata["byteLength"] = str(len(raw)); descriptor = dumps(metadata)
        with self.assertRaisesRegex(MuseumError, "canonical authority subject missing"):
            validate_snapshot(descriptor, raw, keccak256(descriptor))


if __name__ == "__main__": unittest.main()
