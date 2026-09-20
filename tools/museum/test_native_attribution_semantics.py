"""Synthetic-only boundary tests for native Artist attribution selection.

These rows exercise the pure selector after the native source adapter boundary.
They are not RPC evidence and make no actual-chain acceptance claim.
"""

import copy
import unittest

from .account_profile import account_iri
from .canonical import MuseumError, dumps, keccak256, loads
from .native_attribution_semantics import PROFILE, select
from .review import (ASSERTION_SCHEMA_BYTES, REVIEW_MAPPING_RULE, REVIEW_RELATION,
                     _validate, review_literal)
from .test_schema_inventory import assertion_document


def h(value):
    return "0x" + format(value, "064x")


def a(value):
    return "0x" + format(value, "040x")


PROFILE_HASH = h(900)
RELATION = "urn:fixture:native-attribution:relation"
RULE = "urn:fixture:native-attribution:rule"


class SyntheticNativeAttributionFixture:
    """Adapter-shaped synthetic rows, never a substitute for native capture."""

    def __init__(self):
        self.rows = []
        self.next_record = 1

    def _selector(self, pointer=""):
        value = self.next_record
        self.next_record += 1
        return {"recordHash": h(value), "subjectId": h(700), "schemaId": h(701),
                "schemaHash": h(702), "recordType": h(703), "host": a(704),
                "recorder": a(705), "authorizationClass": "ARTIST_SIGNER",
                "recordIndex": str(value), "recordChainHash": h(800 + value), "pointer": pointer}

    @staticmethod
    def assertion_selector(row, index=0):
        return {**row["source"], "pointer": "/assertions/" + str(index)}

    def statement(self, *, artist=1, signer=1, origin="direct_statement", value="first",
                  position=(10, 0, 0), review_status="unreviewed", relation=RELATION,
                  rule=RULE, created_at="2026-09-12T00:00:00Z"):
        document = assertion_document()
        document["profileHash"] = PROFILE_HASH
        assertion = document["assertions"][0]
        assertion.update({"id": "urn:fixture:native-assertion:" + str(self.next_record),
                          "subject": "urn:fixture:native-work", "relation": relation,
                          "object": {"literal": {"lexicalValue": value,
                              "datatype": "urn:fixture:exact-text", "language": "en",
                              "unit": None, "precision": None}},
                          "assertingAgent": account_iri("31337", a(signer)),
                          "createdAt": created_at, "origin": origin,
                          "reviewStatus": review_status, "mappingRule": rule,
                          "rationale": "Synthetic selector boundary only; no chain claim",
                          "reviewEvidence": [], "corrects": [], "disputes": []})
        _validate(ASSERTION_SCHEMA_BYTES, dumps(document))
        row = {"source": self._selector(), "status": "supported", "value": document,
               "historicalAuthority": {"artistId": h(artist), "bindingHash": h(100 + artist),
                   "bindingGeneration": "1", "signer": a(signer), "authorityClass": "1",
                   "requiredCapability": "1", "signedAt": "1757635200"},
               "currentQualification": {"syntheticOnly": True, "currentAuthorityProven": False},
               "publicationPosition": [str(v) for v in position]}
        self.rows.append(row)
        return row

    def review(self, original, *, artist=1, signer=1, position=(11, 0, 0),
               disposition="reviewed", status="reviewed", created_at="2026-09-12T00:01:00Z"):
        original_selector = self.assertion_selector(original)
        original_assertion = original["value"]["assertions"][0]
        body = {"assertionRecord": original_selector,
                "assertionRevisionHash": keccak256(dumps(original_assertion)),
                "profileHash": original["value"]["profileHash"],
                "mappingRule": original_assertion["mappingRule"], "disposition": disposition}
        row = self.statement(artist=artist, signer=signer, position=position,
                             review_status=status, relation=REVIEW_RELATION,
                             rule=REVIEW_MAPPING_RULE, created_at=created_at)
        assertion = row["value"]["assertions"][0]
        assertion["subject"] = original_assertion["id"]
        assertion["object"] = {"literal": review_literal(body)}
        _validate(ASSERTION_SCHEMA_BYTES, dumps(row["value"]))
        return row

    def snapshot(self):
        return {"profile": PROFILE, "version": "1", "mode": "synthetic_fixture",
                "actualChainAcceptance": False, "statements": self.rows}

    def run(self, sources, reviewers=(), *, allow_self=True, single=(RELATION,), mutate=None):
        snapshot = self.snapshot()
        policy = {"profile": PROFILE, "sourceSnapshotHash": keccak256(dumps(snapshot)),
                  "sourceAuthoritySet": [self.assertion_selector(row) for row in sources],
                  "reviewerAuthoritySet": [self.assertion_selector(row) for row in reviewers],
                  "singleValuedRelations": list(single), "allowSelfReview": allow_self,
                  "independentHumanReviewRequired": False}
        if mutate is not None:
            mutate(policy)
        raw = dumps(policy)
        return select(snapshot, raw, keccak256(raw))


class NativeAttributionSelectionTests(unittest.TestCase):
    def test_exact_snapshot_pin_and_complete_selectors_are_required(self):
        f = SyntheticNativeAttributionFixture()
        source = f.statement()
        result = f.run([source])
        self.assertEqual(result["selected"][0]["source"], f.assertion_selector(source))

        with self.assertRaisesRegex(MuseumError, "source"):
            f.run([source], mutate=lambda p: p.__setitem__("sourceSnapshotHash", h(999)))
        with self.assertRaisesRegex(MuseumError, "selector absent"):
            f.run([source], mutate=lambda p: p["sourceAuthoritySet"][0].__setitem__("recordHash", h(999)))
        with self.assertRaisesRegex(MuseumError, "duplicate"):
            f.run([source], mutate=lambda p: p["sourceAuthoritySet"].append(copy.deepcopy(p["sourceAuthoritySet"][0])))
        with self.assertRaisesRegex(MuseumError, "human review unavailable"):
            f.run([source], mutate=lambda p: p.__setitem__("independentHumanReviewRequired", True))

    def test_rotated_signing_accounts_for_one_artist_are_self_review(self):
        f = SyntheticNativeAttributionFixture()
        source = f.statement(artist=8, signer=80, origin="human_mapping")
        review = f.review(source, artist=8, signer=81)
        result = f.run([source], [review])
        resolved = result["reviews"][0]
        self.assertTrue(resolved["selfReview"])
        self.assertTrue(resolved["sameArtistIdentity"])
        self.assertFalse(resolved["sameSigningAccount"])
        self.assertFalse(resolved["independentHumanReviewProven"])
        self.assertEqual(result["selected"][0]["basis"], "explicit_artist_SELF_confirmation")

    def test_same_account_with_different_artist_ids_is_still_self_review(self):
        f = SyntheticNativeAttributionFixture()
        source = f.statement(artist=8, signer=80, origin="human_mapping")
        review = f.review(source, artist=9, signer=80)
        resolved = f.run([source], [review])["reviews"][0]
        self.assertTrue(resolved["selfReview"])
        self.assertFalse(resolved["sameArtistIdentity"])
        self.assertTrue(resolved["sameSigningAccount"])
        self.assertFalse(resolved["independentHumanReviewProven"])

    def test_distinct_protocol_identities_do_not_become_qualified_reviewers(self):
        f = SyntheticNativeAttributionFixture()
        source = f.statement(artist=8, signer=80, origin="human_mapping")
        review = f.review(source, artist=9, signer=90)
        result = f.run([source], [review])
        self.assertEqual(result["selected"], [])
        self.assertEqual(result["withheld"][0]["reasons"], ["mapping_requires_selected_SELF_confirmation"])
        self.assertEqual(result["diagnostics"][0]["reason"],
                         "distinct_protocol_identities_do_not_establish_qualified_review")
        self.assertFalse(result["reviews"][0]["independentHumanReviewProven"])

    def test_named_reviewer_and_backlink_cannot_forge_native_review_facts(self):
        f = SyntheticNativeAttributionFixture()
        source = f.statement(artist=8, signer=80, origin="human_mapping")
        review = f.review(source, artist=8, signer=81)
        # The authored name is retained but native artistId, not a name, establishes SELF.
        review["value"]["assertions"][0]["assertingAgent"] = "urn:fixture:named-reviewer"
        result = f.run([source], [review])
        self.assertTrue(result["reviews"][0]["selfReview"])
        self.assertFalse(result["reviews"][0]["independentHumanReviewProven"])

        # A supplied backlink is checked against the review statement and native classification.
        reference = f.assertion_selector(review)
        original_reference = f.assertion_selector(source)
        original = source["value"]["assertions"][0]
        original["reviewEvidence"] = [{"reviewRecord": reference, "assertionRecord": original_reference,
            "assertionRevisionHash": h(123), "profileHash": PROFILE_HASH, "mappingRule": RULE,
            "reviewer": "urn:fixture:forged-reviewer", "reviewedAt": "2026-09-12T00:02:00Z",
            "selfReview": False}]
        _validate(ASSERTION_SCHEMA_BYTES, dumps(source["value"]))
        body = {"assertionRecord": original_reference, "assertionRevisionHash": keccak256(dumps(original)),
                "profileHash": PROFILE_HASH, "mappingRule": RULE, "disposition": "reviewed"}
        review["value"]["assertions"][0]["object"] = {"literal": review_literal(body)}
        with self.assertRaisesRegex(MuseumError, "forged reviewer backlink"):
            f.run([source], [review])

    def test_review_revision_profile_rule_and_publication_order_are_exact(self):
        for field in ("assertionRevisionHash", "profileHash", "mappingRule"):
            f = SyntheticNativeAttributionFixture()
            source = f.statement(origin="human_mapping")
            review = f.review(source)
            body = copy.deepcopy(review["value"]["assertions"][0]["object"]["literal"])
            value = loads(body["lexicalValue"].encode("utf-8"), canonical=True)
            value[field] = h(999) if field != "mappingRule" else "urn:fixture:wrong-rule"
            review["value"]["assertions"][0]["object"] = {"literal": review_literal(value)}
            with self.subTest(field=field), self.assertRaisesRegex(MuseumError, "revision/profile/rule"):
                f.run([source], [review])

        f = SyntheticNativeAttributionFixture()
        source = f.statement(origin="human_mapping", position=(10, 1, 0))
        review = f.review(source, position=(10, 1, 0))
        with self.assertRaisesRegex(MuseumError, "does not follow"):
            f.run([source], [review])

    def test_unselected_dispute_cannot_suppress_selected_direct_claim(self):
        f = SyntheticNativeAttributionFixture()
        chosen = f.statement(value="chosen")
        f.statement(value="hostile", review_status="disputed")
        result = f.run([chosen])
        self.assertEqual([row["assertion"]["object"]["literal"]["lexicalValue"]
                          for row in result["selected"]], ["chosen"])
        self.assertEqual(result["withheld"], [])

    def test_mapping_requires_selected_opted_in_self_confirmation(self):
        f = SyntheticNativeAttributionFixture()
        source = f.statement(origin="human_mapping")
        review = f.review(source)
        self.assertEqual(f.run([source])["withheld"][0]["reasons"],
                         ["mapping_requires_selected_SELF_confirmation"])
        self.assertEqual(f.run([source], [review], allow_self=False)["withheld"][0]["reasons"],
                         ["mapping_requires_selected_SELF_confirmation"])
        self.assertEqual(len(f.run([source], [review], allow_self=True)["selected"]), 1)

        rejected = f.review(source, position=(12, 0, 0), disposition="rejected")
        result = f.run([source], [review, rejected], allow_self=True)
        self.assertIn("selected_SELF_review_rejected", result["withheld"][0]["reasons"])

    def test_conflicting_values_have_no_recency_winner(self):
        f = SyntheticNativeAttributionFixture()
        early = f.statement(value="early", position=(10, 0, 0))
        late = f.statement(value="late", position=(999, 0, 0))
        result = f.run([late, early])
        self.assertEqual(result["selected"], [])
        self.assertEqual(len(result["withheld"]), 2)
        self.assertTrue(all(row["reasons"] == ["conflicting_selected_source_values"]
                            for row in result["withheld"]))


if __name__ == "__main__":
    unittest.main()
