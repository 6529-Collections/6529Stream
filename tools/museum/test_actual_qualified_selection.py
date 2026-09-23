"""Execute selection on retained actual publications; historical local EVM scope."""
from copy import deepcopy
from pathlib import Path
import unittest
from unittest.mock import patch

from .account_profile import account_iri
from .canonical import MuseumError, dumps, keccak256, loads
from .qualified_review_capture_v1 import profile_for_hash
from .qualified_review_fixture_v1 import read, verify_capture
from .qualified_recorded_selection import (
    MODE, QUALIFICATION, source_admission, select_qualified_recorded,
    project_qualified_recorded, resolve_qualified_review,
)
from .projection_v2 import CONTENT, CONTENT_KIND

ROOT = Path(__file__).resolve().parents[2] / 'schemas/museum'
PIN = '0x618ade1b0c337fef6f4cfb5d85d4a6fb0191f6e323db30087d4b57f57202f88a'


class ActualQualifiedSelectionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.files, cls.manifest = read(ROOT / 'qualified-account-review-profile/local-fixture', PIN)
        cls.profile = profile_for_hash(cls.manifest['profileHash'])
        with patch('socket.socket', side_effect=AssertionError('offline selection opened a socket')):
            cls.source = verify_capture(cls.files, cls.profile)
        cls.cases = loads(cls.files['qualified-cases.json'], canonical=True)
        cls.choices = cls.cases['selectors']

    def policy(self, reviews=('approved',), *, allow_self=False):
        s = self.source
        mapping = self.choices['mapping']
        selected_reviews = [self.choices[name] for name in reviews]
        admissions = []
        for row in selected_reviews:
            assertion = s.assertion(row)[0]
            body = loads(assertion['object']['literal']['lexicalValue'].encode(), canonical=True)
            admissions.append({**source_admission(s, row), 'targetSelector': body['assertionRecord'],
                'targetRevisionHash': body['assertionRevisionHash'], 'targetProfileHash': body['profileHash'],
                'mappingRule': body['mappingRule'], 'allowSelfReview': allow_self})
        return {'mode': MODE, 'version': '1', 'sourceStateHash': s.state.commitment,
            'profileHash': s.profile_hash, 'sourceAuthoritySet': [mapping],
            'reviewerAuthoritySet': selected_reviews, 'sourceAdmissions': [source_admission(s, mapping)],
            'reviewAdmissions': admissions, 'singleValuedRelations': sorted({s.assertion(mapping)[0]['relation'], CONTENT, CONTENT_KIND}),
            'independentReviewRequired': False, 'qualification': QUALIFICATION}

    def select(self, policy):
        raw = dumps(policy)
        with patch('socket.socket', side_effect=AssertionError('offline selection opened a socket')):
            return select_qualified_recorded(self.source, raw, policy_hash=keccak256(raw))

    def test_actual_distinct_account_approval_selects_original_unchanged(self):
        result = self.select(self.policy())
        claim, = result.selected
        original, issuer, _ = self.source.assertion(self.choices['mapping'])
        self.assertEqual(loads(claim.assertion), original)
        self.assertEqual(original['reviewStatus'], 'unreviewed')
        self.assertEqual(original['reviewEvidence'], [])
        self.assertEqual(claim.issuer, issuer)
        self.assertEqual(claim.basis, 'policy_admitted_account_review')
        evidence, = [loads(item) for item in claim.review_evidence]
        self.assertEqual(evidence['reviewer'], account_iri('31337', self.cases['reviewer']))
        self.assertFalse(evidence['selfReview'])
        self.assertFalse(evidence['humanIndependenceEstablished'])
        self.assertFalse(result.withheld)

    def test_actual_mapping_without_selected_approval_is_omitted(self):
        result = self.select(self.policy(()))
        self.assertFalse(result.selected)
        self.assertTrue(any('lacks an admitted approving review' in row.reason for row in result.diagnostics))

    def test_actual_opposing_selected_reviews_withhold_in_either_policy_order(self):
        for names in [('approved', 'rejected'), ('rejected', 'approved'), ('rejected',)]:
            with self.subTest(names=names):
                result = self.select(self.policy(names))
                self.assertFalse(result.selected)
                claim, = result.withheld
                self.assertEqual(loads(claim.selector), self.choices['mapping'])

    def test_actual_unselected_later_rejection_has_no_veto(self):
        result = self.select(self.policy())
        self.assertEqual(len(result.selected), 1)
        records = {loads(row.selector)['recordHash']: row.reason for row in result.diagnostics}
        self.assertIn('sidecar only, no veto', records[self.choices['rejected']['recordHash']])

    def test_actual_self_review_requires_explicit_permission_and_labels_self(self):
        with self.assertRaisesRegex(MuseumError, 'SELF review requires explicit admission'):
            self.select(self.policy(('self_review',)))
        claim, = self.select(self.policy(('self_review',), allow_self=True)).selected
        self.assertEqual(claim.basis, 'account_confirmed_SELF_review')
        self.assertTrue(loads(claim.review_evidence[0])['selfReview'])

    def test_native_publication_order_is_used_despite_equal_claimed_timestamps(self):
        mapping = self.source.assertion(self.choices['mapping'])[0]
        for name, block in [('approved', 720), ('rejected', 721), ('self_review', 722)]:
            admission, = self.policy((name,), allow_self=True)['reviewAdmissions']
            result = resolve_qualified_review(self.source, self.choices[name], admission,
                profile_hash=self.source.profile_hash)
            self.assertEqual(result['reviewedAt'], mapping['createdAt'])
            self.assertEqual(int(result['originalPublicationPosition'][0]), 719)
            self.assertEqual(int(result['reviewPublicationPosition'][0]), block)

    def test_actual_reviewer_facts_and_target_revision_cannot_be_substituted(self):
        mutations = [lambda row: row.update(principal=account_iri('31337', self.cases['publisher'])),
            lambda row: row['scope'].update(collectionId='2'),
            lambda row: row.update(targetRevisionHash='0x' + 'ff' * 32)]
        for mutate in mutations:
            policy = deepcopy(self.policy()); mutate(policy['reviewAdmissions'][0])
            with self.subTest(mutation=mutate), self.assertRaises(MuseumError): self.select(policy)

    def test_actual_projection_retains_all_originals_and_explicit_scope(self):
        s = self.source; mapping = self.choices['mapping']
        payload = s.payload(s.record(mapping))
        policy = dumps(self.policy())
        plan = dumps({'mode': 'qualified_recorded_account_projection', 'version': s.profile.version,
            'sourceStateHash': s.state.commitment, 'profileHash': s.profile_hash,
            'selectionPolicyHash': keccak256(policy), 'crosswalkHash': s.profile.crosswalk_hash,
            'entityAuthoritySet': [{**mapping, 'pointer': '/entities/' + str(i)} for i in range(len(payload['entities']))],
            'externalEntities': [{'id': item, 'kind': 'account'} for item in sorted(s.accounts)]})
        with patch('socket.socket', side_effect=AssertionError('offline projection opened a socket')):
            result = project_qualified_recorded(s, policy, plan, policy_hash=keccak256(policy), plan_hash=keccak256(plan))
        self.assertTrue(result.resources)
        sidecar = loads(result.sidecar, maximum=67108864, canonical=True)
        retained = {row['selector']['recordHash']: row for row in sidecar['publicSources']}
        self.assertEqual(set(retained), set(s.records))
        self.assertEqual(len(retained), 5)
        for record in s.state.records:
            row = retained[record.selector.record_hash]
            self.assertEqual(row['payloadHex'], '0x' + record.payload.hex())
            self.assertEqual(row['schemaHex'], '0x' + record.schema.hex())
            self.assertEqual(row['authorityEvidenceHex'], '0x' + record.authority_evidence.hex())
        claim, = sidecar['selectedClaims']
        self.assertEqual(claim['assertion'], s.assertion(mapping)[0])
        review, = claim['reviewEvidence']
        self.assertEqual(review['reviewRecord'], self.choices['approved'])
        facts = loads(result.report, maximum=67108864, canonical=True)['sourceEvidence']
        self.assertEqual(facts['qualification'], QUALIFICATION)
        self.assertEqual(facts['sourceCaptureHash'], keccak256(self.files['source-capture.json']))
        self.assertFalse(facts['humanIdentityEstablished'])
        self.assertFalse(facts['independentReviewEstablished'])
        self.assertFalse(facts['protocolAuthorityGranted'])
        self.assertFalse(self.manifest['selectionPolicyExecuted'])  # Original capture stays immutable.


if __name__ == '__main__': unittest.main()
