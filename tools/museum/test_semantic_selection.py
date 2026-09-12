"""Canonical selector provenance and policy-bound fixture projection admission."""

import copy
from dataclasses import replace
import unittest

from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .semantic_selection import select_canonical_fixture
from .source import FixtureSourceAdapter
from .test_review import case, record, row
from .test_schema_inventory import H, assertion_document


def policy(state, sources, reviewers=(), *, independent=True):
    return {"mode": "synthetic_canonical_assertion_selection", "version": "1", "sourceStateHash": state.commitment,
            "profileHash": H, "sourceAuthoritySet": list(sources), "reviewerAuthoritySet": list(reviewers),
            "singleValuedRelations": ["urn:fixture:dimension"], "independentReviewRequired": independent}


def select(state, p):
    raw = dumps(p)
    return select_canonical_fixture(state, raw, policy_hash=keccak256(raw), profile_hash=H)


class CanonicalSelection(unittest.TestCase):
    def test_review_existence_or_name_does_not_create_selected_authority(self):
        state, evidence, original, _ = case()
        without = select(state, policy(state, [original]))
        self.assertFalse(without.selected)
        self.assertTrue(any("unselected public record" in d.reason for d in without.diagnostics))
        with_review = select(state, policy(state, [original], [evidence["reviewRecord"]]))
        self.assertEqual(len(with_review.selected), 1)
        claim = with_review.selected[0]
        self.assertEqual(claim.selector, dumps(original))
        self.assertEqual(claim.assertion, dumps(loads(state.records[0].payload)["assertions"][0]))
        self.assertEqual(claim.issuer, "urn:fixture:artist")
        self.assertEqual(claim.basis, "reviewed_under_selected_policy")
        self.assertEqual(claim.review_evidence, (dumps(evidence),))

    def test_author_confirmed_self_review_has_separate_policy_effect_and_label(self):
        state, evidence, original, _ = case(self_review=True)
        strict = select(state, policy(state, [original], [evidence["reviewRecord"]]))
        self.assertFalse(strict.selected)
        own = select(state, policy(state, [original], [evidence["reviewRecord"]], independent=False))
        self.assertEqual(len(own.selected), 1)
        self.assertEqual(own.selected[0].basis, "author_confirmed_self_review")
        self.assertTrue(loads(own.selected[0].review_evidence[0])["selfReview"])

    def test_unselected_rejection_cannot_veto_and_selected_conflict_withholds(self):
        state, evidence, original, _ = case()
        rejected_state, _, _, _ = case(disposition="rejected")
        rejection = rejected_state.records[1]
        rejection = replace(rejection, selector=replace(rejection.selector, record_hash=schema_id("fixture:rejection")))
        combined = FixtureSourceAdapter("review-conflict", state.records + (rejection,)).snapshot()
        approved = select(combined, policy(combined, [original], [evidence["reviewRecord"]]))
        self.assertEqual(len(approved.selected), 1)
        both = select(combined, policy(combined, [original], [evidence["reviewRecord"], row(rejection)]))
        self.assertFalse(both.selected)
        self.assertEqual(len(both.withheld), 1)
        self.assertEqual(len(both.withheld[0].review_evidence), 2)
        self.assertTrue(any("conflicting admitted review dispositions" in d.reason for d in both.diagnostics))
        # Policy/source ordering cannot choose the result.
        reversed_state = FixtureSourceAdapter("review-conflict", tuple(reversed(combined.records))).snapshot()
        reversed_result = select(reversed_state, policy(reversed_state, [original], [row(rejection), evidence["reviewRecord"]]))
        self.assertEqual(both.selected, reversed_result.selected)
        self.assertEqual(both.withheld, reversed_result.withheld)

    def test_direct_statement_is_eligible_without_fabricated_review_and_hostile_record_cannot_veto(self):
        document = assertion_document()
        source = record(document, "direct", "urn:fixture:artist", "artist", ["1", "0", "0"])
        bad_document = assertion_document()
        bad_document["assertions"][0] = {"unrecognized": "hostile unselected claim"}
        hostile = record(bad_document, "hostile", "urn:fixture:hostile", "curator", ["2", "0", "0"])
        state = FixtureSourceAdapter("unselected-malformed", (source, hostile)).snapshot()
        result = select(state, policy(state, [row(source)]))
        self.assertEqual(len(result.selected), 1)
        self.assertEqual(result.selected[0].basis, "direct_statement")
        self.assertEqual(result.selected[0].review_evidence, ())
        self.assertTrue(any("unselected public record" in d.reason for d in result.diagnostics))
        with self.assertRaises(MuseumError):
            select(state, policy(state, [row(source), row(hostile)]))

    def test_conflicting_eligible_sources_withhold_without_recency_or_provenance_loss(self):
        first = assertion_document()
        later = copy.deepcopy(first)
        later["assertions"][0]["object"]["literal"]["lexicalValue"] = "41.00"
        later["assertions"][0]["assertingAgent"] = "urn:fixture:other"
        a = record(first, "first", "urn:fixture:artist", "artist", ["1", "0", "0"])
        b = record(later, "later", "urn:fixture:other", "curator", ["100", "0", "0"])
        state = FixtureSourceAdapter("source-conflict", (a, b)).snapshot()
        result = select(state, policy(state, [row(a), row(b)]))
        self.assertFalse(result.selected)
        self.assertEqual({c.selector for c in result.withheld}, {dumps(row(a)), dumps(row(b))})
        self.assertEqual({loads(c.assertion)["object"]["literal"]["lexicalValue"] for c in result.withheld}, {"40.00", "41.00"})
        single = select(state, policy(state, [row(a)]))
        self.assertEqual(len(single.selected), 1)

    def test_policy_exact_pins_and_fixture_state_bindings(self):
        state, evidence, original, _ = case()
        p = policy(state, [original], [evidence["reviewRecord"]])
        for field, value in (("sourceStateHash", schema_id("other")), ("profileHash", schema_id("other")),
                             ("independentReviewRequired", "false"), ("sourceAuthoritySet", [original, original]),
                             ("reviewerAuthoritySet", ["not a selector"])):
            with self.subTest(field=field), self.assertRaises(MuseumError):
                select(state, p | {field: value})
        changed = copy.deepcopy(p)
        changed["reviewerAuthoritySet"][0]["host"] = "0x" + "33" * 20
        with self.assertRaises(MuseumError):
            select(state, changed)
        with self.assertRaisesRegex(MuseumError, "does not bind records"):
            select(replace(state, records=tuple(reversed(state.records))), p)
        with self.assertRaisesRegex(MuseumError, "policy hash mismatch"):
            select_canonical_fixture(state, dumps(p), policy_hash=H, profile_hash=H)
        self.assertEqual(len(select(state, p).selected), 1)

    def test_restricted_records_and_mode_are_not_promoted_into_public_evidence(self):
        state, evidence, original, _ = case()
        secret = record(assertion_document(), "restricted-secret", "urn:fixture:artist", "artist", ["0", "0", "0"], "restricted")
        combined = FixtureSourceAdapter("restricted-sidecar", state.records + (secret,)).snapshot()
        result = select(combined, policy(combined, [original], [evidence["reviewRecord"]]))
        self.assertEqual(len(result.selected), 1)
        diagnostic_bytes = b"".join(d.selector for d in result.diagnostics)
        self.assertNotIn(secret.selector.record_hash.encode(), diagnostic_bytes)
        with self.assertRaises(MuseumError):
            select(combined, policy(combined, [row(secret)]))
        with self.assertRaisesRegex(MuseumError, "recorded canonical selection adapter not implemented"):
            select(replace(combined, mode="recorded_state"), policy(combined, [original]))


if __name__ == "__main__":
    unittest.main()
