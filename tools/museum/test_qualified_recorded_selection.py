"""Synthetic semantic-admission controls; no registered or chain capture claim."""
from copy import deepcopy
from pathlib import Path
from types import MappingProxyType
import unittest

from .account_profile import JCS_ID, account_iri
from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .qualified_review_profile import QualifiedAccountReviewProfile, NAMES
from .qualified_recorded_selection import (MODE, QUALIFICATION, source_admission,
    select_qualified_recorded, resolve_qualified_review, project_qualified_recorded)
from .recorded_semantic import RecordedSemanticSource, CLASS, RECORD_TYPE
from .projection_v2 import CONTENT_KIND, CONTENT, STRING
from .review import REVIEW_RELATION, REVIEW_MAPPING_RULE, review_literal, _selector
from .source import BoundSourceState, RecordSelector, RetainedSourceRecord
from .test_schema_inventory import assertion_document

ROOT = Path(__file__).resolve().parents[2] / "schemas/museum"
def h(number): return "0x" + format(number, "064x")
def address(number): return "0x" + format(number, "040x")


class SyntheticRecordedFixture:
    """Exercise concrete semantic methods on explicitly fabricated input facts.

    Bypasses capture construction only, never a production semantic verifier.
    Actual registered capture and replay belong to a separate integration suite.
    """
    def __init__(self, profile):
        self.source = object.__new__(RecordedSemanticSource)
        s = self.source
        s.profile = profile; s.profile_hash = profile.profile_hash
        s.anchor = MappingProxyType({"chainId": "31337", "core": address(3), "host": address(4),
                                     "environment": "local_evm_fixture"})
        self.records = []; self.capture = []; self.positions = {}; self.serial = 0
        s.publication_bytes = s.interpretation_bytes = dumps({"mode": "synthetic_unit_only"})
        self.seed = self.add(b'{"fixture":"synthetic documentary source"}', 1, schema=b'{"type":"object"}')

    def add(self, raw, actor, *, schema=None, subject=100, position=None):
        self.serial += 1
        schema = schema or self.source.profile.assertion_schema_bytes
        selector = RecordSelector(address(4), h(self.serial), h(subject),
            schema_id(NAMES[1]) if schema == self.source.profile.assertion_schema_bytes else h(700),
            keccak256(schema), RECORD_TYPE, address(actor), CLASS, str(self.serial), h(1000 + self.serial))
        facts = dumps({"mode": "synthetic_unit_only", "subjectKind": "token",
                       "agentIri": account_iri("31337", address(actor))})
        record = RetainedSourceRecord(selector, raw, keccak256(raw), schema, facts, "public")
        self.records.append(record)
        self.capture.append({"recordHash": selector.record_hash, "subject": ["1", "1", str(subject), h(0)]})
        self.positions[selector.record_hash] = (self.serial, 0, 0) if position is None else position
        self.sync()
        return _selector(record, "")

    def sync(self):
        s = self.source
        s.records = MappingProxyType({r.selector.record_hash: r for r in self.records})
        s.positions = MappingProxyType(dict(self.positions)); s._payloads = set()
        s.canonicalizations = MappingProxyType({r.selector.record_hash: JCS_ID for r in self.records})
        s.capture_bytes = dumps({"records": self.capture, "mode": "synthetic_unit_only"})
        s.accounts = frozenset(account_iri("31337", r.selector.recorder) for r in self.records)
        s._state = BoundSourceState("recorded_state", dumps({"synthetic": True,
            "payloads": [r.payload_hash for r in self.records]}), tuple(self.records))

    def claim(self, *, actor=1, origin="automated_mapping", status="unreviewed", subject=100,
              value="first", amend=None, entity=False):
        payload = assertion_document()
        payload.update(profileSchemaId=schema_id(NAMES[0]), profileHash=self.source.profile_hash,
                       anchorSubject={"kind": "token", "subjectId": h(subject)}, sourceRecords=[self.seed])
        assertion = payload["assertions"][0]
        assertion.update(id="urn:test:assertion:" + str(self.serial + 1), subject="urn:test:work",
            assertingAgent=account_iri("31337", address(actor)), origin=origin, reviewStatus=status,
            evidence=[{"source": {"algorithm": "1", "digest": self.records[0].payload_hash,
                "canonicalizationId": JCS_ID}, "selectorType": "whole_document", "selector": "",
                "basis": "documentary_evidence"}])
        assertion["object"]["literal"]["lexicalValue"] = value
        if entity:
            payload["entities"] = [{"id": "urn:test:work", "kind": entity if isinstance(entity, str) else "abstract_work", "names": [],
                "declaringAgent": assertion["assertingAgent"], "sourceRecords": [self.seed],
                "predecessors": [], "continuation": None}]
        if amend: amend(assertion)
        row = self.add(dumps(payload), actor, subject=subject)
        row["pointer"] = "/assertions/0"
        return row

    def review(self, target, *, actor=2, disposition="reviewed", status="unreviewed", amend=None, subject=100):
        original = self.source.assertion(target)[0]
        body = {"assertionRecord": target, "assertionRevisionHash": keccak256(dumps(original)),
                "profileHash": self.source.profile_hash, "mappingRule": original["mappingRule"], "disposition": disposition}
        if amend: amend(body)
        return self.claim(actor=actor, origin="direct_statement", status=status, subject=subject,
            amend=lambda assertion: assertion.update(subject=original["id"], relation=REVIEW_RELATION,
                mappingRule=REVIEW_MAPPING_RULE, object={"literal": review_literal(body)}))

    def policy(self, sources, reviews=(), *, self_review=False):
        s = self.source
        admissions = []
        for row in reviews:
            assertion = s.assertion(row)[0]; body = loads(assertion["object"]["literal"]["lexicalValue"].encode())
            admissions.append({**source_admission(s, row), "targetSelector": body["assertionRecord"],
                "targetRevisionHash": body["assertionRevisionHash"], "targetProfileHash": body["profileHash"],
                "mappingRule": body["mappingRule"], "allowSelfReview": self_review})
        return {"mode": MODE, "version": "1", "sourceStateHash": s.state.commitment, "profileHash": s.profile_hash,
            "sourceAuthoritySet": sources, "reviewerAuthoritySet": list(reviews),
            "sourceAdmissions": [source_admission(s, row) for row in sources], "reviewAdmissions": admissions,
            "singleValuedRelations": ["urn:fixture:dimension", CONTENT_KIND, CONTENT], "independentReviewRequired": False,
            "qualification": QUALIFICATION}


class QualifiedRecordedTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls): cls.profile = QualifiedAccountReviewProfile(ROOT)

    def setUp(self): self.f = SyntheticRecordedFixture(self.profile)

    def select(self, policy):
        raw = dumps(policy)
        return select_qualified_recorded(self.f.source, raw, policy_hash=keccak256(raw))

    def pair(self, **kwargs):
        original = self.f.claim(); review = self.f.review(original, **kwargs)
        return original, review, self.f.policy([original], [review])

    def test_different_accounts_qualify_exact_revision_without_human_independence(self):
        original, review, policy = self.pair()
        result = self.select(policy); self.assertEqual(len(result.selected), 1)
        evidence = loads(result.selected[0].review_evidence[0])
        self.assertEqual(evidence["assertionRecord"], original); self.assertEqual(evidence["reviewRecord"], review)
        self.assertFalse(evidence["selfReview"]); self.assertFalse(evidence["humanIndependenceEstablished"])
        self.assertEqual(evidence["originalPublicationPosition"], ["2", "0", "0"])

    def test_self_review_requires_explicit_per_record_admission(self):
        _, _, policy = self.pair(actor=1)
        with self.assertRaisesRegex(MuseumError, "SELF review"): self.select(policy)
        policy["reviewAdmissions"][0]["allowSelfReview"] = True
        result = self.select(policy)
        self.assertTrue(loads(result.selected[0].review_evidence[0])["selfReview"])
        self.assertEqual(result.selected[0].basis, "account_confirmed_SELF_review")

    def test_bare_accounts_never_replace_exact_admissions(self):
        _, _, policy = self.pair()
        for key in ("sourceAdmissions", "reviewAdmissions"):
            bad = deepcopy(policy); bad[key] = []
            with self.subTest(key=key), self.assertRaisesRegex(MuseumError, "admission set"): self.select(bad)

    def test_forged_principal_family_scope_and_original_profile_refuse(self):
        _, _, policy = self.pair()
        for field in ("principal", "family", "authorizationClass", "profileHash", "scope"):
            bad = deepcopy(policy); item = bad["reviewAdmissions"][0]
            if field == "scope": item[field]["tokenId"] = "999"
            else: item[field] = "forged"
            with self.subTest(field=field), self.assertRaisesRegex(MuseumError, "authenticated facts"): self.select(bad)

    def test_review_admission_cannot_change_target_revision_profile_or_rule(self):
        _, _, policy = self.pair()
        for field in ("targetRevisionHash", "targetProfileHash", "mappingRule", "targetSelector"):
            bad = deepcopy(policy); item = bad["reviewAdmissions"][0]
            if field == "targetSelector": item[field]["recordHash"] = h(800)
            else: item[field] = h(900)
            with self.subTest(field=field), self.assertRaisesRegex(MuseumError, "target mismatch"): self.select(bad)

    def test_forged_literal_revision_refuses_even_when_admission_repeats_it(self):
        original = self.f.claim(); review = self.f.review(original, amend=lambda body: body.update(assertionRevisionHash=h(99)))
        with self.assertRaisesRegex(MuseumError, "revision/profile/rule"): self.select(self.f.policy([original], [review]))

    def test_same_or_prior_publication_position_cannot_review_original(self):
        original, review, policy = self.pair()
        for position in ((2, 0, 0), (1, 0, 1)):
            self.f.positions[review["recordHash"]] = position; self.f.sync()
            with self.subTest(position=position), self.assertRaisesRegex(MuseumError, "follow original"):
                self.select(policy)

    def test_wrong_subject_scope_cannot_become_review_authority(self):
        original = self.f.claim(); review = self.f.review(original, subject=101)
        with self.assertRaisesRegex(MuseumError, "retain target scope"): self.select(self.f.policy([original], [review]))

    def test_request_for_human_independence_refuses(self):
        _, _, policy = self.pair(); policy["independentReviewRequired"] = True
        with self.assertRaisesRegex(MuseumError, "human review"): self.select(policy)

    def test_withdrawn_or_disputed_reviews_never_qualify_mapping(self):
        original = self.f.claim()
        for status in ("withdrawn", "disputed"):
            review = self.f.review(original, status=status)
            with self.subTest(status=status): self.assertFalse(self.select(self.f.policy([original], [review])).selected)

    def test_withdrawn_source_stays_out_and_disputed_source_is_withheld(self):
        for status in ("withdrawn", "disputed"):
            original = self.f.claim(status=status, origin="direct_statement")
            result = self.select(self.f.policy([original]))
            self.assertFalse(result.selected); self.assertEqual(bool(result.withheld), status == "disputed")

    def test_opposing_selected_dispositions_withhold_without_recency_winner(self):
        original = self.f.claim(); rejection = self.f.review(original, disposition="rejected")
        approval = self.f.review(original, actor=3)
        result = self.select(self.f.policy([original], [rejection, approval]))
        self.assertFalse(result.selected); self.assertEqual(len(result.withheld), 1)
        result = self.select(self.f.policy([original], [rejection]))
        self.assertFalse(result.selected); self.assertEqual(len(result.withheld), 1)

    def test_unselected_opposing_and_opaque_records_have_no_veto(self):
        original, approval, _ = self.pair()
        self.f.review(original, disposition="rejected")
        self.f.add(b'opaque invalid semantic payload', 4)
        result = self.select(self.f.policy([original], [approval]))
        self.assertEqual(len(result.selected), 1)
        self.assertTrue(any("sidecar only" in item.reason for item in result.diagnostics))

    def test_single_value_conflicts_apply_only_inside_same_exact_scope(self):
        one = self.f.claim(origin="direct_statement")
        two = self.f.claim(origin="direct_statement", value="second")
        other = self.f.claim(origin="direct_statement", value="third", subject=101)
        result = self.select(self.f.policy([one, two, other]))
        self.assertEqual([loads(row.selector) for row in result.selected], [other]); self.assertEqual(len(result.withheld), 2)

    def test_direct_statement_does_not_need_mapping_approval(self):
        row = self.f.claim(origin="direct_statement")
        self.assertEqual(len(self.select(self.f.policy([row])).selected), 1)

    def test_duplicate_admission_and_hash_substitution_refuse(self):
        _, _, policy = self.pair()
        bad = deepcopy(policy); bad["reviewAdmissions"].append(bad["reviewAdmissions"][0])
        with self.assertRaisesRegex(MuseumError, "duplicated"): self.select(bad)
        with self.assertRaisesRegex(MuseumError, "policy hash"):
            select_qualified_recorded(self.f.source, dumps(policy), policy_hash=h(9))

    def test_existing_registered_profile_is_not_silently_upgraded(self):
        from .test_recorded_account import load_source
        old = load_source()
        with self.assertRaisesRegex(MuseumError, "registered qualified"):
            select_qualified_recorded(old, b'{}', policy_hash=keccak256(b'{}'))

    def test_projection_reports_account_qualification_and_retains_original_sidecars(self):
        original = self.f.claim(entity=True); review = self.f.review(original)
        policy = dumps(self.f.policy([original], [review])); s = self.f.source
        entity = {**original, "pointer": "/entities/0"}
        plan = dumps({"mode": "qualified_recorded_account_projection", "version": s.profile.version,
            "sourceStateHash": s.state.commitment, "profileHash": s.profile_hash,
            "selectionPolicyHash": keccak256(policy), "crosswalkHash": s.profile.crosswalk_hash,
            "entityAuthoritySet": [entity], "externalEntities": [{"id": item, "kind": "account"} for item in sorted(s.accounts)]})
        result = project_qualified_recorded(s, policy, plan, policy_hash=keccak256(policy), plan_hash=keccak256(plan))
        self.assertEqual(len(result.resources), 1)
        facts = loads(result.report)["sourceEvidence"]
        self.assertFalse(facts["humanIdentityEstablished"]); self.assertFalse(facts["protocolAuthorityGranted"])
        self.assertEqual(facts["qualification"], QUALIFICATION)
        sidecar = loads(result.sidecar, maximum=67108864)
        retained = {row["selector"]["recordHash"]: row for row in sidecar["publicSources"]}
        self.assertEqual(set(retained), set(s.records))
        for record in s.state.records:
            row = retained[record.selector.record_hash]
            self.assertEqual(row["selector"], _selector(record, ""))
            self.assertEqual(row["payloadHex"], "0x" + record.payload.hex())
            self.assertEqual(row["schemaHex"], "0x" + record.schema.hex())
            self.assertEqual(row["authorityEvidenceHex"], "0x" + record.authority_evidence.hex())
        claim, = sidecar["selectedClaims"]
        self.assertEqual(claim["assertion"], s.assertion(original)[0])
        evidence, = claim["reviewEvidence"]
        self.assertEqual(evidence["assertionRecord"], original)
        self.assertEqual(evidence["reviewRecord"], review)
        self.assertEqual(evidence["assertionRevisionHash"], keccak256(dumps(s.assertion(original)[0])))

    def test_legacy_entrypoints_cannot_apply_old_rules_under_new_profile_hash(self):
        from .recorded_selection import select_recorded, project_recorded
        row = self.f.claim(origin="direct_statement", status="disputed"); s = self.f.source
        policy = dumps({"mode": "recorded_account_selection", "version": "1", "sourceStateHash": s.state.commitment,
            "profileHash": s.profile_hash, "sourceAuthoritySet": [row], "reviewerAuthoritySet": [],
            "singleValuedRelations": [CONTENT, CONTENT_KIND], "independentReviewRequired": False,
            "allowAccountSelfReview": True})
        with self.assertRaisesRegex(MuseumError, "own exact-admission"):
            select_recorded(s, policy, policy_hash=keccak256(policy))
        with self.assertRaisesRegex(MuseumError, "own exact-admission"):
            project_recorded(s, policy, b'{}', selection_hash=keccak256(policy), plan_hash=keccak256(b'{}'))

    def test_projection_rejects_same_iri_multiscope_content_and_declaration_mismatch(self):
        def content(relation, value):
            return lambda assertion: assertion.update(relation=relation, object={"literal": {
                "lexicalValue": value, "datatype": STRING, "language": None, "unit": None, "precision": None}})
        one = self.f.claim(origin="direct_statement", entity="information_object", amend=content(CONTENT, "original"))
        kind = self.f.claim(origin="direct_statement", amend=content(CONTENT_KIND, "linguistic"))
        two = self.f.claim(origin="direct_statement", subject=101, amend=content(CONTENT, "foreign"))
        s = self.f.source

        def project(rows):
            policy = dumps(self.f.policy(rows))
            plan = dumps({"mode": "qualified_recorded_account_projection", "version": s.profile.version,
                "sourceStateHash": s.state.commitment, "profileHash": s.profile_hash,
                "selectionPolicyHash": keccak256(policy), "crosswalkHash": s.profile.crosswalk_hash,
                "entityAuthoritySet": [{**one, "pointer": "/entities/0"}],
                "externalEntities": [{"id": value, "kind": "account"} for value in sorted(s.accounts)]})
            return project_qualified_recorded(s, policy, plan, policy_hash=keccak256(policy), plan_hash=keccak256(plan))

        self.assertEqual(len(self.select(self.f.policy([one, kind, two])).selected), 3)
        with self.assertRaisesRegex(MuseumError, "crosses native scopes"): project([one, kind, two])
        with self.assertRaisesRegex(MuseumError, "crosses native scopes"): project([two])
        restored = project([one, kind])
        self.assertEqual(loads(restored.resources[0].content)["content"], "original")
        self.assertEqual(len(loads(restored.sidecar, maximum=67108864)["selectedClaims"]), 2)



if __name__ == "__main__": unittest.main()
