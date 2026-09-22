"""Pure policy cases only; native source admission is tested separately."""
import copy
import unittest

from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .native_artist_review_profile import (REVIEW_DATATYPE, REVIEW_MAPPING_RULE, REVIEW_RELATION,
    review_literal)
from .native_artist_review_selection import PROFILE, _select, select_artist_reviews
from .test_native_attribution_semantics import SyntheticNativeAttributionFixture, a, h


class PolicyFixture(SyntheticNativeAttributionFixture):
    def __init__(self):
        super().__init__()
        self.scope = {'chainId': '31337', 'core': a(700), 'collectionId': '7',
            'artistRegistry': a(701), 'host': a(704)}

    def statement(self, **kwargs):
        row = super().statement(**kwargs)
        history = row['historicalAuthority']
        row['source']['recorder'] = history['signer']
        row['source']['recordType'] = schema_id('ARTIST_SEMANTIC_ASSERTION')
        row['nativeAuthority'] = {key: history[key] for key in ('artistId', 'signer', 'authorityClass',
            'bindingHash', 'bindingGeneration')} | {'attestationRecordHash': h(1000 + self.next_record),
            'operationEvidenceId': h(2000 + self.next_record), 'operationEvidenceHash': h(3000 + self.next_record),
            'actor': history['signer'], 'grantRecordHash': h(0)}
        row['reasonCode'] = None
        row['assertionInterpretations'] = [{'pointer': '/assertions/0', 'status': 'supported', 'reasonCode': None}]
        row['value']['anchorSubject'] = {'kind': 'collection', 'subjectId': row['source']['subjectId']}
        return row

    def review(self, original, *, mutate=None, disposition='reviewed', **kwargs):
        row = self.statement(relation=REVIEW_RELATION, rule=REVIEW_MAPPING_RULE,
            position=kwargs.pop('position', (11, 0, 0)), **kwargs)
        assertion = original['value']['assertions'][0]
        body = {'assertionRecord': self.assertion_selector(original),
            'assertionRevisionHash': keccak256(dumps(assertion)), 'profileHash': original['value']['profileHash'],
            'mappingRule': assertion['mappingRule'], 'disposition': disposition,
            'sourceScope': copy.deepcopy(self.scope), 'assertionAuthority': copy.deepcopy(original['nativeAuthority'])}
        if mutate: mutate(body)
        row['value']['assertions'][0].update(subject=assertion['id'], object={'literal': review_literal(body)})
        return row

    def snapshot(self):
        return {'profile': 'STREAM_MUSEUM_NATIVE_ARTIST_REVIEW_SOURCE_V1', 'version': '1',
            'interpretationProfileHash': h(900), 'sourceScope': self.scope, 'mode': 'synthetic_fixture',
            'statements': self.rows}

    def run(self, sources, reviewers=(), *, allow_self=False, single=(), mutate=None):
        snapshot = self.snapshot()
        policy = {'profile': PROFILE, 'interpretationProfileHash': h(900),
            'sourceSnapshotHash': keccak256(dumps(snapshot)),
            'sourceAuthoritySet': [self.assertion_selector(row) for row in sources],
            'reviewerAuthoritySet': [self.assertion_selector(row) for row in reviewers],
            'singleValuedRelations': list(single), 'allowSelfReview': allow_self, 'independentHumanReviewRequired': False}
        if mutate: mutate(policy)
        raw = dumps(policy)
        return _select(snapshot, raw, keccak256(raw))


class NativeArtistReviewSelectionTests(unittest.TestCase):
    def test_distinct_admitted_artist_and_account_review_selects_mapping(self):
        f = PolicyFixture(); original = f.statement(artist=1, signer=10, origin='human_mapping')
        review = f.review(original, artist=2, signer=20)
        result = f.run([original], [review])
        self.assertEqual(len(result['selected']), 1)
        self.assertEqual(result['reviews'][0]['qualification'], 'distinct_native_artist_and_signing_account')
        self.assertFalse(result['reviews'][0]['independentHumanReviewProven'])
        self.assertFalse(result['reviews'][0]['institutionalAuthorityProven'])
        self.assertEqual(original['value']['assertions'][0]['reviewStatus'], 'unreviewed')

    def test_either_shared_artist_or_signer_is_self_and_requires_opt_in(self):
        for artist, signer in ((1, 20), (2, 10), (1, 10)):
            f = PolicyFixture(); original = f.statement(artist=1, signer=10, origin='human_mapping')
            review = f.review(original, artist=artist, signer=signer)
            self.assertEqual(f.run([original], [review])['selected'], [])
            result = f.run([original], [review], allow_self=True)
            self.assertEqual(len(result['selected']), 1)
            self.assertTrue(result['reviews'][0]['selfReview'])

    def test_every_original_authority_and_scope_word_is_exact(self):
        for group in ('sourceScope', 'assertionAuthority'):
            f = PolicyFixture(); original = f.statement(origin='human_mapping')
            template = f.review(original, artist=2, signer=2)
            body = loads(template['value']['assertions'][0]['object']['literal']['lexicalValue'].encode())
            for key, value in body[group].items():
                changed = copy.deepcopy(body)
                changed[group][key] = ('2' if value == '1' else '1') if value.isdecimal() else (
                    a(999) if len(value) == 42 else h(999))
                template['value']['assertions'][0]['object']['literal'] = review_literal(changed)
                with self.subTest(group=group, key=key), self.assertRaisesRegex(MuseumError, 'scope/authority'):
                    f.run([original], [template])

    def test_revision_profile_rule_and_selector_are_exact(self):
        for field in ('assertionRevisionHash', 'profileHash', 'mappingRule', 'assertionRecord'):
            f = PolicyFixture(); original = f.statement(origin='human_mapping')
            def mutate(body):
                if field == 'assertionRecord': body[field]['recordIndex'] = '999'
                else: body[field] = 'urn:wrong:rule' if field == 'mappingRule' else h(999)
            review = f.review(original, artist=2, signer=2, mutate=mutate)
            with self.subTest(field=field), self.assertRaises(MuseumError): f.run([original], [review])

    def test_review_uses_native_order_not_claimed_dates(self):
        for position in ((10, 0, 0), (9, 0, 0)):
            f = PolicyFixture(); original = f.statement(origin='human_mapping')
            review = f.review(original, artist=2, signer=2, position=position, created_at='2099-01-01T00:00:00Z')
            with self.assertRaisesRegex(MuseumError, 'follow original'): f.run([original], [review])

    def test_cross_subject_review_is_rejected(self):
        f = PolicyFixture(); original = f.statement(origin='human_mapping')
        review = f.review(original, artist=2, signer=2); review['source']['subjectId'] = h(777)
        with self.assertRaisesRegex(MuseumError, 'publication scope'): f.run([original], [review])

    def test_unselected_malformed_or_forged_review_cannot_veto_selected_mapping(self):
        f = PolicyFixture(); original = f.statement(origin='human_mapping')
        approved = f.review(original, artist=2, signer=2)
        hostile = f.review(original, artist=3, signer=3, position=(12, 0, 0),
            mutate=lambda body: body.__setitem__('assertionRevisionHash', h(999)))
        self.assertEqual(len(f.run([original], [approved])['selected']), 1)
        with self.assertRaises(MuseumError): f.run([original], [approved, hostile])
        hostile['value']['assertions'][0]['object']['literal']['lexicalValue'] = '{malformed'
        self.assertEqual(len(f.run([original], [approved])['selected']), 1)
        with self.assertRaises(MuseumError): f.run([original], [approved, hostile])

    def test_selected_rejection_withholds_mapping_but_unselected_rejection_does_not(self):
        f = PolicyFixture(); original = f.statement(origin='human_mapping')
        approved = f.review(original, artist=2, signer=2)
        rejected = f.review(original, artist=3, signer=3, disposition='rejected', position=(12, 0, 0))
        self.assertEqual(len(f.run([original], [approved])['selected']), 1)
        result = f.run([original], [approved, rejected])
        self.assertEqual(result['selected'], [])
        self.assertIn('selected_native_review_rejected', result['withheld'][0]['reasons'])

    def test_selected_rejection_does_not_veto_direct_statement(self):
        f = PolicyFixture(); original = f.statement()
        rejected = f.review(original, artist=2, signer=2, disposition='rejected')
        self.assertEqual(len(f.run([original], [rejected])['selected']), 1)

    def test_disputed_or_withdrawn_review_is_not_an_approval(self):
        for status in ('disputed', 'withdrawn'):
            f = PolicyFixture(); original = f.statement(origin='human_mapping')
            review = f.review(original, artist=2, signer=2, review_status=status)
            result = f.run([original], [review])
            self.assertEqual(result['selected'], [])
            self.assertEqual(result['diagnostics'][0]['reason'], 'review_revision_disputed_or_withdrawn')

    def test_literal_qualifier_cannot_change_review_meaning(self):
        f = PolicyFixture(); original = f.statement(origin='human_mapping'); review = f.review(original, artist=2, signer=2)
        review['value']['assertions'][0]['object']['literal']['language'] = 'en'
        with self.assertRaisesRegex(MuseumError, 'datatype/qualifier'): f.run([original], [review])

    def test_conflicts_do_not_merge_subjects_or_pick_recency(self):
        f = PolicyFixture(); first = f.statement(value='first'); other = f.statement(value='other', position=(11, 0, 0))
        relation = first['value']['assertions'][0]['relation']
        self.assertEqual(f.run([first, other], single=[relation])['selected'], [])
        other['source']['subjectId'] = h(778)
        self.assertEqual(len(f.run([first, other], single=[relation])['selected']), 2)

    def test_policy_pins_shape_and_human_requirement_fail_closed(self):
        for key, value in (('interpretationProfileHash', h(999)), ('sourceSnapshotHash', h(999)),
                ('allowSelfReview', 1), ('independentHumanReviewRequired', True)):
            f = PolicyFixture(); original = f.statement()
            with self.subTest(key=key), self.assertRaises(MuseumError):
                f.run([original], mutate=lambda policy: policy.__setitem__(key, value))

    def test_public_selector_rejects_synthetic_snapshot_as_source(self):
        with self.assertRaisesRegex(MuseumError, 'concrete Artist review source'):
            select_artist_reviews(PolicyFixture().snapshot(), b'{}', keccak256(b'{}'))

    def test_review_statement_cannot_fill_source_or_overlapping_roles(self):
        f = PolicyFixture(); original = f.statement(); review = f.review(original, artist=2, signer=2)
        with self.assertRaisesRegex(MuseumError, 'roles overlap'): f.run([original, review], [review])
        with self.assertRaisesRegex(MuseumError, 'ordinary source assertion'): f.run([review])


if __name__ == '__main__': unittest.main()
