"""Prospective document/body tests; no native publication or selection claims."""

from copy import deepcopy
import socket
import unittest
from unittest.mock import patch

from . import native_artist_review_profile as review
from .account_profile import JCS_ID, JCS_NAME
from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .dependencies import Limits, OfflineDocuments
from .independent_wire import RAW_BYTES
from .native_attribution_profile import NativeAttributionProfile
from .review import _validate
from .schemas import NAMES as OLD_NAMES, schemas
from .test_schema_inventory import assertion_document, selector


def h(value):
    return "0x" + format(value, "064x")


def a(value):
    return "0x" + format(value, "040x")


def body():
    selected = selector()
    selected.update(recordType=review.ARTIST_RECORD_TYPE, authorizationClass="ARTIST_SIGNER",
                    pointer="/assertions/0", host=a(11))
    return {"assertionRecord": selected, "assertionRevisionHash": h(1), "profileHash": h(2),
        "mappingRule": "urn:fixture:original-rule", "disposition": "reviewed",
        "sourceScope": {"chainId": "31337", "core": a(10), "collectionId": "1",
                        "artistRegistry": a(12), "host": a(11)},
        "assertionAuthority": {"artistId": h(3), "signer": a(13), "authorityClass": "1",
            "bindingHash": h(4), "bindingGeneration": "1", "attestationRecordHash": h(5),
            "operationEvidenceId": h(6), "operationEvidenceHash": h(7), "actor": a(14),
            "grantRecordHash": h(0)}}


class NativeArtistReviewProfileTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with patch.object(socket, "socket", side_effect=AssertionError("offline documents only")):
            cls.old = NativeAttributionProfile()
            cls.profile = review.NativeArtistReviewProfile()

    def test_every_inherited_document_including_old_profile_is_exact(self):
        before = dict(self.old.documents)
        for name, value in before.items():
            self.assertEqual(self.profile.documents[name], value, name)
        self.assertEqual(self.profile.documents[self.old.name][1], self.old.profile_bytes)
        self.assertEqual(keccak256(self.profile.documents[self.old.name][1]), self.old.profile_hash)
        self.assertNotEqual(self.old.profile_hash, self.profile.profile_hash)
        self.assertEqual(before, dict(self.old.documents))
        with self.assertRaises(TypeError):
            self.profile.documents["change"] = (0, b"changed")

    def test_schema_clones_change_only_explicit_identity_and_profile_binding(self):
        for old_name, new_name in zip(OLD_NAMES, review.NAMES):
            expected = deepcopy(schemas()[old_name])
            if old_name == new_name:
                self.assertEqual(review.SCHEMAS[new_name], dumps(expected))
                self.assertNotIn(new_name, self.profile.document_predecessors)
                continue
            expected.update(title=new_name)
            expected["$id"] = "urn:6529stream:schema:" + new_name
            expected["x-stream-schema-id"] = schema_id(new_name)
            expected.setdefault("x-stream-profile", {})["supersedesSchemaId"] = schema_id(old_name)
            if "profileSchemaId" in expected["properties"]:
                expected["properties"]["profileSchemaId"] = {"const": schema_id(review.NAMES[0])}
            self.assertEqual(loads(review.SCHEMAS[new_name]), expected)
        entity = loads(review.ASSERTION_SCHEMA_BYTES)["$defs"]["entity"]
        self.assertNotIn("continuation", entity["properties"])
        self.assertNotIn("type", entity["properties"]["kind"]["enum"])

    def test_native_assertion_schema_stays_exact_and_profile_hash_carries_opt_in(self):
        from .metadata_catalog_source import ARTIST_SCHEMAS
        payload = assertion_document()
        self.assertEqual(review.NAMES[1], OLD_NAMES[1])
        self.assertEqual(review.ASSERTION_SCHEMA_BYTES, dumps(schemas()[OLD_NAMES[1]]))
        self.assertEqual(self.profile.assertion_schema_name, OLD_NAMES[1])
        self.assertEqual(review.ASSERTION_PROFILE_SCHEMA_ID, schema_id(OLD_NAMES[0]))
        self.assertEqual(ARTIST_SCHEMAS[review.ARTIST_RECORD_TYPE], (schema_id(review.NAMES[1]),))
        _validate(review.ASSERTION_SCHEMA_BYTES, dumps(payload))
        payload.update(profileSchemaId=schema_id(review.NAMES[0]), profileHash=self.profile.profile_hash)
        with self.assertRaises(MuseumError):
            _validate(review.ASSERTION_SCHEMA_BYTES, dumps(payload))
        payload["profileSchemaId"] = review.ASSERTION_PROFILE_SCHEMA_ID
        self.assertEqual(_validate(review.ASSERTION_SCHEMA_BYTES, dumps(payload)), payload)
        payload["entities"] = [{"id": "urn:fixture:entity", "kind": "abstract_work", "names": [],
            "declaringAgent": "urn:fixture:account", "sourceRecords": [selector()], "predecessors": []}]
        _validate(review.ASSERTION_SCHEMA_BYTES, dumps(payload))
        payload["entities"][0]["continuation"] = None
        with self.assertRaises(MuseumError):
            _validate(review.ASSERTION_SCHEMA_BYTES, dumps(payload))

    def test_literal_roundtrip_all_native_authority_classes_and_dispositions(self):
        for authority in ("1", "2", "3", "4"):
            for disposition in ("reviewed", "rejected"):
                value = body()
                value["assertionAuthority"]["authorityClass"] = authority
                value["disposition"] = disposition
                literal = review.review_literal(value)
                self.assertEqual(literal, {"lexicalValue": dumps(value).decode("utf-8"),
                    "datatype": review.REVIEW_DATATYPE, "language": None, "unit": None, "precision": None})
                self.assertEqual(_validate(review.BODY_SCHEMA_BYTES, literal["lexicalValue"].encode()), value)

    def test_body_requires_every_exact_selector_scope_and_authority_field(self):
        original = body()
        for section in (None, "assertionRecord", "sourceScope", "assertionAuthority"):
            for key in original if section is None else original[section]:
                value = deepcopy(original)
                del (value if section is None else value[section])[key]
                with self.subTest(section=section, missing=key), self.assertRaises(MuseumError):
                    review.review_literal(value)

    def test_body_rejects_extra_fields_and_non_artist_selector(self):
        for section in (None, "assertionRecord", "sourceScope", "assertionAuthority"):
            value = body()
            (value if section is None else value[section])["claimedIndependentHuman"] = True
            with self.subTest(section=section), self.assertRaises(MuseumError):
                review.review_literal(value)
        for key, value in (("authorizationClass", "INDEPENDENT_ATTESTOR"),
                           ("recordType", schema_id("GENERAL_ASSERTION")), ("pointer", "/assertions/00"),
                           ("pointer", "/assertions/-1"), ("pointer", "/entities/0"), ("pointer", "")):
            candidate = body()
            candidate["assertionRecord"][key] = value
            with self.subTest(key=key, value=value), self.assertRaises(MuseumError):
                review.review_literal(candidate)

    def test_body_rejects_invalid_integer_hex_and_class_encodings(self):
        controls = [("sourceScope", "chainId", "01"), ("sourceScope", "chainId", str(1 << 256)),
            ("sourceScope", "collectionId", 1), ("sourceScope", "core", "0x12"),
            ("assertionAuthority", "bindingGeneration", str(1 << 64)),
            ("assertionAuthority", "authorityClass", "5"), ("assertionAuthority", "authorityClass", 1),
            ("assertionAuthority", "artistId", "0x" + "AB" * 32),
            ("assertionAuthority", "grantRecordHash", None)]
        for section, key, value in controls:
            candidate = body()
            candidate[section][key] = value
            with self.subTest(section=section, key=key, value=value), self.assertRaises(MuseumError):
                review.review_literal(candidate)
        candidate = body()
        candidate["disposition"] = "approved"
        with self.assertRaises(MuseumError):
            review.review_literal(candidate)

    def test_schema_validation_does_not_claim_cross_record_authentication(self):
        candidate = body()
        candidate["sourceScope"]["host"] = a(999)
        candidate["assertionAuthority"]["operationEvidenceHash"] = h(999)
        # A literal is a statement. The separate native reader/selector must
        # authenticate both mismatching fields; encoding is not source admission.
        self.assertEqual(loads(review.review_literal(candidate)["lexicalValue"].encode()), candidate)
        self.assertIn("Shape only", review.BODY_SCHEMA["x-stream-semantic-checks"])
        self.assertFalse(review.CLAIMS["actualChainAcceptance"])

    def test_policy_explicitly_limits_selection_self_and_distinct_accounts(self):
        policy = loads(review.POLICY_BYTES)
        self.assertIn("OR", policy["reviewer"]["SELF"])
        self.assertIn("allowSelfReview", policy["reviewer"]["SELF"])
        self.assertIn("Both", policy["reviewer"]["distinct"])
        self.assertIn("Both", policy["optIn"]["bothRecords"])
        self.assertEqual(policy["optIn"]["assertionProfileSchemaId"], schema_id(OLD_NAMES[0]))
        self.assertEqual(policy["optIn"]["interpretationProfileSchemaId"], schema_id(review.NAMES[0]))
        self.assertIn("cannot veto", policy["selection"]["unselected"])
        self.assertIn("fail selection", policy["selection"]["selected"])
        self.assertIn("transactionIndex", policy["publicationOrder"])
        self.assertIn("createdAt is not", policy["publicationOrder"])
        for key in ("humanIndependenceProven", "institutionalStandingProven", "currentAuthorityProven",
                    "reviewCreatesProtocolVeto", "typedContinuationSupported"):
            self.assertFalse(policy["claims"][key])

    def test_registered_original_dependency_bytes_reconstruct_without_network(self):
        dependency = loads(self.profile.documents[review.DEPENDENCY_NAME][1], maximum=524288)
        originals = {}
        for subroot, path in ((review.DEFAULT_ROOT, "linked-art-v2/validation-index.json"),
                              (review.DEFAULT_ROOT / "standards", "vocabulary-index.json")):
            index = loads((subroot / path).read_bytes(), maximum=524288)
            retained = OfflineDocuments(subroot, index)
            originals.update({row["sourceUri"]: retained.load(row["sourceUri"]) for row in index["documents"]})
        self.assertEqual({row["sourceUri"] for row in dependency["documents"]}, set(originals))
        for row in dependency["documents"]:
            raw = originals[row["sourceUri"]]
            self.assertEqual(self.profile.documents[row["documentName"]], (3, raw))
            self.assertEqual(row["documentId"], schema_id(row["documentName"]))
            self.assertEqual(row["contentHash"], {"algorithm": "1", "digest": keccak256(raw), "canonicalizationId": RAW_BYTES})
            self.assertEqual(row["byteLength"], str(len(raw)))

    def test_complete_acyclic_document_commitments_predecessors_and_bounds(self):
        p = self.profile
        dependency = loads(p.documents[review.DEPENDENCY_NAME][1], maximum=524288)
        indexed = {row["name"] for row in dependency["interpretationDocuments"]}
        self.assertEqual(indexed, set(p.documents) - {review.NAME, review.DEPENDENCY_NAME})
        for row in dependency["interpretationDocuments"]:
            kind, raw = p.documents[row["name"]]
            self.assertEqual((row["kind"], row["byteLength"]), (str(kind), str(len(raw))))
            self.assertEqual(row["contentHash"], {"algorithm": "1", "digest": keccak256(raw),
                "canonicalizationId": p.document_canonicalizations[row["name"]]})
        ids = {schema_id(name) for name in p.documents}
        self.assertLessEqual(set(p.document_predecessors.values()), ids)
        self.assertEqual(set(p.document_canonicalizations), set(p.documents))
        self.assertEqual(p.document_canonicalizations[JCS_NAME], RAW_BYTES)
        self.assertEqual(p.document_canonicalizations[review.NAME], JCS_ID)
        limits = Limits()
        self.assertLessEqual(len(p.documents), limits.documents)
        self.assertLessEqual(sum(len(raw) for _, raw in p.documents.values()), limits.aggregate_bytes)
        self.assertLessEqual(sum((len(raw) + 8191) // 8192 for _, raw in p.documents.values()), limits.chunks)
        self.assertTrue(all(len(raw) <= 524288 for _, raw in p.documents.values()))

    def test_profile_exact_pin_and_profile_references(self):
        self.assertEqual(review.NativeArtistReviewProfile(expected_hash=self.profile.profile_hash).profile_bytes,
                         self.profile.profile_bytes)
        with self.assertRaisesRegex(MuseumError, "profile pin mismatch"):
            review.NativeArtistReviewProfile(expected_hash=self.old.profile_hash)
        value = loads(self.profile.profile_bytes)
        self.assertEqual(value["supersedesSchemaId"], schema_id(self.old.name))
        for ref in [value["dependencyIndex"], value["selectionRules"], *value["crosswalkDocuments"],
                    *value["validationDocuments"], *value["classPropertyTables"]]:
            name = ref["path"][:-5]
            raw = self.profile.documents[name][1]
            self.assertEqual(ref["contentHash"]["digest"], keccak256(raw))
            self.assertEqual(ref["byteLength"], str(len(raw)))

    def test_generated_new_documents_and_check_mode(self):
        generated = review.generated_documents()
        self.assertEqual(len(generated), 7)
        self.assertNotIn(OLD_NAMES[1] + ".json", generated)
        self.assertNotIn("STREAM_NATIVE_ARTIST_REVIEW_ASSERTION_V1", self.profile.documents)
        for name, raw in generated.items():
            self.assertEqual((review.DEFAULT_ROOT / "native-artist-review-profile" / name).read_bytes(), raw)
            self.assertEqual(raw, self.profile.documents[name[:-5]][1])
        # The CLI consumes actual retained dependencies from the normal root;
        # testing --check against checked-in bytes is independent of a writer.
        with patch("sys.argv", ["native_artist_review_profile", "--check"]):
            review.main()


if __name__ == "__main__":
    unittest.main()
