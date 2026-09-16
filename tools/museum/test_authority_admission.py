"""Synthetic unit doubles for the private recorded-authority admission boundary.

These tests isolate ``authority_package._candidates``.  They do not replay a
recorded source and provide no evidence of publication, signatures, chain
state, human identity, or review independence.  The public package route and
the real ``select_recorded`` implementation have separate retained-source
tests.
"""

from copy import deepcopy
import unittest
from unittest.mock import patch

from .authority import RELATION
from .authority_package import _bind_declarations, _candidates
from .canonical import MuseumError, dumps, keccak256, loads
from .semantic_selection import SelectedClaim, SemanticSelection
from .test_authority import fixture


H = "0x" + "11" * 32


class SyntheticSource:
    """Small in-memory shape double; deliberately not a RecordedSemanticSource."""

    def __init__(self, assertion, payload, *, issuer="urn:test:synthetic-account"):
        self._assertion = assertion
        self._payload = payload
        self._issuer = issuer
        self.state = object()
        self.profile_hash = H
        self.declarations = {}

    def assertion(self, selector):
        return deepcopy(self._assertion), self._issuer, (7, 3, 1)

    def record(self, selector):
        return {"syntheticSelector": deepcopy(selector)}

    def payload(self, record):
        return deepcopy(self._payload)

    def entity(self, state, selector, profile_hash):
        assert state is self.state and profile_hash == self.profile_hash
        return deepcopy(self.declarations[dumps(selector)]), None


def admitted_fixture(*, authority="GETTY_TGN", kind="Place"):
    candidate, body, _, _ = fixture(authority=authority, kind=kind,
        local="urn:test:synthetic-local-" + kind.casefold())
    assertion = deepcopy(candidate["assertion"])
    issuer = "urn:test:synthetic-account"
    selector = {"syntheticRecord": "one"}
    payload = {
        "authorityAlignments": [deepcopy(body["alignment"])],
        "entities": [{"id": assertion["subject"],
                      "kind": {"Place": "place", "Person": "person",
                               "Group": "group", "Type": "type"}[kind],
                      "declaringAgent": issuer}],
    }
    policy = dumps({"sourceAuthoritySet": [selector]})
    source = SyntheticSource(assertion, payload, issuer=issuer)
    review = dumps({"reviewRecord": {"syntheticRecord": "review"},
                    "assertionRecord": selector,
                    "assertionRevisionHash": keccak256(dumps(assertion)),
                    "profileHash": H, "mappingRule": assertion["mappingRule"],
                    "reviewer": issuer, "reviewedAt": "2026-09-16T12:35:00Z",
                    "selfReview": True,
                    "qualification": "unit double only; no recorded evidence"})
    claim = SelectedClaim(dumps(selector), dumps(assertion), issuer,
                          "account_confirmed_SELF_review", (review,))
    selection = SemanticSelection(H, H, H, (claim,), (), ())
    return source, policy, selector, claim, selection


def run_candidates(source, policy, selection):
    with patch("tools.museum.authority_package.select_recorded", return_value=selection):
        return _candidates(source, policy, H)


class AuthorityAdmissionUnitDoubles(unittest.TestCase):
    def test_exact_selected_self_review_evidence_is_eligible(self):
        source, policy, selector, claim, selection = admitted_fixture()
        rows, returned = run_candidates(source, policy, selection)
        self.assertIs(returned, selection)
        self.assertEqual(len(rows), 1)
        self.assertTrue(rows[0]["eligible"])
        self.assertEqual(rows[0]["source"], selector)
        self.assertEqual(rows[0]["basis"], "account_confirmed_SELF_review")
        self.assertEqual(rows[0]["reviews"], [loads(claim.review_evidence[0], canonical=True)])

    def test_claimed_review_status_without_selected_review_evidence_is_ineligible(self):
        source, policy, selector, claim, _ = admitted_fixture()
        source._assertion["reviewStatus"] = "reviewed"
        empty = SelectedClaim(claim.selector, dumps(source._assertion), claim.issuer,
                              claim.basis, ())
        selection = SemanticSelection(H, H, H, (empty,), (), ())
        rows, _ = run_candidates(source, policy, selection)
        self.assertFalse(rows[0]["eligible"])
        self.assertEqual(rows[0]["eligibilityReason"],
                         "mapping_lacks_selected_authenticated_review")
        self.assertEqual(rows[0]["reviews"], [])

    def test_rejected_or_withheld_selected_claim_is_not_admitted(self):
        source, policy, _, claim, _ = admitted_fixture()
        selection = SemanticSelection(H, H, H, (), (claim,), ())
        rows, _ = run_candidates(source, policy, selection)
        self.assertFalse(rows[0]["eligible"])
        self.assertEqual(rows[0]["basis"], "not_selected")
        self.assertEqual(rows[0]["reviews"], [])

    def test_original_alignment_must_equal_the_complete_literal_binding(self):
        source, policy, _, _, selection = admitted_fixture()
        source._payload["authorityAlignments"][0]["basis"] = "outside literal changed"
        with self.assertRaisesRegex(MuseumError, "not bound by exact assertion literal"):
            run_candidates(source, policy, selection)

    def test_original_entity_declaration_kind_and_issuer_must_match(self):
        for mutation in (
            lambda payload: payload.update(entities=[]),
            lambda payload: payload["entities"][0].update(kind="person"),
            lambda payload: payload["entities"][0].update(
                declaringAgent="urn:test:different-synthetic-account"),
        ):
            source, policy, _, _, selection = admitted_fixture()
            mutation(source._payload)
            with self.subTest(payload=source._payload):
                rows, _ = run_candidates(source, policy, selection)
                self.assertFalse(rows[0]["eligible"])
                self.assertEqual(rows[0]["eligibilityReason"],
                                 "original_local_entity_declaration_missing_or_incompatible")

    def test_aat_type_is_unsupported_by_the_original_entity_schema(self):
        source, policy, _, _, selection = admitted_fixture(
            authority="GETTY_AAT", kind="Type")
        rows, _ = run_candidates(source, policy, selection)
        self.assertFalse(rows[0]["eligible"])
        self.assertEqual(rows[0]["eligibilityReason"],
                         "recorded_type_declaration_unsupported")

    def test_unselected_unrelated_relation_is_skipped(self):
        source, policy, _, claim, _ = admitted_fixture()
        source._assertion["relation"] = "urn:test:unrelated-relation"
        self.assertNotEqual(source._assertion["relation"], RELATION)
        selection = SemanticSelection(H, H, H, (), (claim,), ())
        rows, _ = run_candidates(source, policy, selection)
        self.assertEqual(rows, [])

    def test_original_selected_declaration_requires_exact_selector_and_bytes(self):
        source, policy, _, _, selection = admitted_fixture()
        rows, _ = run_candidates(source, policy, selection)
        declaration = rows[0]["entityDeclaration"]
        source.declarations[dumps(declaration["source"])] = declaration["value"]
        plan = {"entityAuthoritySet": [declaration["source"]], "externalEntities": []}
        _bind_declarations(source, dumps(plan), rows)
        self.assertTrue(rows[0]["eligible"])
        self.assertEqual(declaration["declarationHash"], keccak256(dumps(declaration["value"])))
        for mutation in ("different_record", "different_bytes"):
            changed = deepcopy(rows)
            if mutation == "different_record":
                changed[0]["entityDeclaration"]["source"]["syntheticRecord"] = "later-same-account"
            else:
                changed[0]["entityDeclaration"]["value"]["declaringAgent"] = "urn:test:other-account"
            with self.subTest(mutation=mutation):
                _bind_declarations(source, dumps(plan), changed)
                self.assertFalse(changed[0]["eligible"])
                self.assertEqual(changed[0]["eligibilityReason"], "original_selected_declaration_reuse_not_established")

    def test_original_external_identity_cannot_be_promoted_by_redeclaration(self):
        source, policy, _, _, selection = admitted_fixture()
        rows, _ = run_candidates(source, policy, selection)
        plan = {"entityAuthoritySet": [], "externalEntities": [{"id": rows[0]["assertion"]["subject"], "kind": "place"}]}
        _bind_declarations(source, dumps(plan), rows)
        self.assertFalse(rows[0]["eligible"])
        self.assertEqual(rows[0]["eligibilityReason"], "original_external_identity_cannot_be_redeclared")

    def test_competing_eligible_new_declarations_withhold_both_without_order_tiebreak(self):
        source, policy, _, _, selection = admitted_fixture()
        rows, _ = run_candidates(source, policy, selection)
        competitor = deepcopy(rows[0])
        competitor["entityDeclaration"]["source"]["syntheticRecord"] = "other"
        for candidates in (rows + [competitor], [competitor] + rows):
            candidates = deepcopy(candidates)
            _bind_declarations(source, dumps({"entityAuthoritySet": [], "externalEntities": []}), candidates)
            self.assertTrue(all(not row["eligible"] for row in candidates))
            self.assertTrue(all(row["eligibilityReason"] == "ambiguous_selected_local_declarations" for row in candidates))

    def test_unselected_collision_does_not_veto_original_selected_declaration(self):
        source, policy, _, _, selection = admitted_fixture()
        rows, _ = run_candidates(source, policy, selection)
        declaration = rows[0]["entityDeclaration"]
        source.declarations[dumps(declaration["source"])] = declaration["value"]
        competitor = deepcopy(rows[0]); competitor["eligible"] = False
        competitor["entityDeclaration"]["source"]["syntheticRecord"] = "unselected"
        _bind_declarations(source, dumps({"entityAuthoritySet": [declaration["source"]], "externalEntities": []}), rows + [competitor])
        self.assertTrue(rows[0]["eligible"])
        self.assertFalse(competitor["eligible"])


if __name__ == "__main__":
    unittest.main()
