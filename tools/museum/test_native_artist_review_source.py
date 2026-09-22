"""Complete synthetic native originals and exact offline Artist review replay."""
import copy
import unittest
from unittest.mock import patch

from .account_profile import JCS_ID, account_iri
from .artist_attestation_source import ArtistAttestationSource
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .chain_rpc import MAX_TRANSCRIPT, ReplayTransport
from .independent_wire import RAW_BYTES
from .metadata_catalog_source import MetadataCatalogSource
from .native_artist_review_profile import (NAME, NativeArtistReviewProfile, REVIEW_MAPPING_RULE,
    REVIEW_RELATION, review_literal)
from .native_artist_review_selection import PROFILE, select_artist_reviews
from .native_artist_review_source import NativeArtistReviewSource, review_body
from .native_artist_review_test_fixture import NativeArtistReviewFixture
from .native_attribution_profile import NativeAttributionProfile
from .native_attribution_semantics import selector
from .test_metadata_catalog_source import A, H
from .test_schema_inventory import assertion_document

PROFILE_HASH = '0x5388a2d86f23ffd75f9ec089a88d081fa41812d797d66ca2b8af5d89306de407'


def payload(context, *, origin='human_mapping', review=False, mutate=None, disposition='reviewed'):
    value = assertion_document()
    original = context['previous'][0] if review else None
    prior = original['original'] if review else context['documentary']
    reference = selector(prior, context['scope']['host'])
    value.update(profileHash=PROFILE_HASH, anchorSubject={'kind': 'collection', 'subjectId': context['subjectId']},
        sourceRecords=[reference])
    assertion = value['assertions'][0]
    assertion.update(id='urn:fixture:artist-review:' + str(context['index']), origin=origin,
        assertingAgent=account_iri(context['scope']['chainId'], context['signer']),
        evidence=[{'source': {'algorithm': '1', 'digest': keccak256(hex_bytes(prior['payloadHex'])),
            'canonicalizationId': JCS_ID if review else RAW_BYTES}, 'selectorType': 'json_pointer',
            'selector': '/assertions/0' if review else '/statement', 'basis': 'documentary_evidence'}])
    if review:
        original_assertion = loads(hex_bytes(prior['payloadHex']))['assertions'][0]
        body = {'assertionRecord': reference | {'pointer': '/assertions/0'},
            'assertionRevisionHash': keccak256(dumps(original_assertion)), 'profileHash': PROFILE_HASH,
            'mappingRule': original_assertion['mappingRule'], 'disposition': disposition,
            'sourceScope': context['scope'], 'assertionAuthority': original['nativeAuthority']}
        assertion.update(subject=original_assertion['id'], origin='direct_statement', relation=REVIEW_RELATION,
            mappingRule=REVIEW_MAPPING_RULE, object={'literal': review_literal(body)})
    if mutate: mutate(value)
    return dumps(value)


def policy(source, *, sources=(0,), reviewers=(1,), allow_self=False):
    snapshot = loads(source.snapshot(), maximum=MAX_TRANSCRIPT, canonical=True)
    ordered = sorted(snapshot['statements'], key=lambda row: tuple(map(int, row['publicationPosition'])))
    def reference(item):
        record, assertion = item if type(item) is tuple else (item, 0)
        return ordered[record]['source'] | {'pointer': '/assertions/' + str(assertion)}
    return dumps({'profile': PROFILE, 'interpretationProfileHash': source.profile.profile_hash,
        'sourceSnapshotHash': keccak256(source.snapshot()), 'sourceAuthoritySet': [reference(i) for i in sources],
        'reviewerAuthoritySet': [reference(i) for i in reviewers], 'singleValuedRelations': [],
        'allowSelfReview': allow_self, 'independentHumanReviewRequired': False})


class NativeArtistReviewSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.profile = NativeArtistReviewProfile(expected_hash=PROFILE_HASH)

    def fixture(self, **kwargs):
        return NativeArtistReviewFixture([{'payload': payload}, {'payload': lambda c: payload(c, review=True)}],
            profile=self.profile, **kwargs)

    def select(self, source, **kwargs):
        raw = policy(source, **kwargs)
        return select_artist_reviews(source, raw, keccak256(raw))

    def test_full_original_publications_select_distinct_review_and_replay_offline(self):
        f = self.fixture(); source = f.semantic(); raw = source.snapshot()
        result = self.select(source)
        self.assertEqual(len(result['selected']), 1)
        self.assertFalse(result['reviews'][0]['selfReview'])
        self.assertEqual(result['sourceMode'], 'synthetic_fixture')
        self.assertFalse(result['claims']['actualChainAcceptance'])
        self.assertEqual(result['selected'][0]['assertion']['reviewStatus'], 'unreviewed')
        self.assertEqual(result['reviews'][0]['reviewerAuthority'], f.publications[1]['nativeAuthority'])
        self.assertEqual(result['reviews'][0]['assertionAuthority'], f.publications[0]['nativeAuthority'])
        reference = result['selected'][0]['source']
        body = review_body(source, reference, 'reviewed')
        self.assertEqual(body['assertionAuthority'], f.publications[0]['nativeAuthority'])
        metadata_raw, artist_raw, semantic_raw = (source.catalogue.transcript(), source.artist.transcript(), source.transcript())
        with patch('socket.socket', side_effect=AssertionError('offline Artist replay used a network')):
            catalogue = MetadataCatalogSource(source.anchor_bytes, ReplayTransport(metadata_raw, keccak256(metadata_raw)))
            artist = ArtistAttestationSource(catalogue, ReplayTransport(artist_raw, keccak256(artist_raw)))
            replay = NativeArtistReviewSource(artist, ReplayTransport(semantic_raw, keccak256(semantic_raw)), profile=self.profile)
            self.assertEqual(replay.snapshot(), raw)
            self.assertEqual(self.select(replay), result)

    def test_same_original_artist_or_signer_remains_self_in_concrete_source(self):
        for mode in ('same_artist', 'same_signer'):
            source = self.fixture(mode=mode).semantic()
            self.assertEqual(self.select(source)['selected'], [])
            result = self.select(source, allow_self=True)
            self.assertEqual(len(result['selected']), 1)
            self.assertTrue(result['reviews'][0]['selfReview'])

    def test_original_actor_and_delegated_grant_do_not_replace_signer(self):
        for options in ({'relayed': True}, {'delegated': True}):
            f = self.fixture(**options); source = f.semantic(); result = self.select(source)
            self.assertEqual(len(result['selected']), 1)
            original = result['reviews'][0]['reviewerAuthority']
            self.assertEqual(original, f.publications[1]['nativeAuthority'])
            if options.get('relayed'): self.assertNotEqual(original['actor'], original['signer'])
            else: self.assertNotEqual(original['grantRecordHash'], '0x' + '00' * 32)

    def test_unselected_forged_revision_or_malformed_body_cannot_veto_valid_mapping(self):
        def wrong_revision(value):
            literal = value['assertions'][0]['object']['literal']
            body = loads(literal['lexicalValue'].encode()); body['assertionRevisionHash'] = H('forged revision')
            value['assertions'][0]['object']['literal'] = review_literal(body)
        def wrong_target(value):
            literal = value['assertions'][0]['object']['literal']
            body = loads(literal['lexicalValue'].encode()); body['assertionRecord']['recordHash'] = H('forged target')
            value['assertions'][0]['object']['literal'] = review_literal(body)
        def malformed(value): value['assertions'][0]['object']['literal']['lexicalValue'] = '{bad'
        for change in (wrong_revision, wrong_target, malformed):
            f = NativeArtistReviewFixture([{'payload': payload}, {'payload': lambda c: payload(c, review=True)},
                {'payload': lambda c: payload(c, review=True, mutate=change)}], profile=self.profile)
            source = f.semantic(); snapshot = loads(source.snapshot(), maximum=MAX_TRANSCRIPT)
            self.assertEqual(len(snapshot['statements']), 3)
            self.assertEqual(len(self.select(source)['selected']), 1)
            with self.assertRaises(MuseumError): self.select(source, reviewers=(1, 2))

    def test_semantic_impersonation_and_schema_errors_are_retained_nonveto_diagnostics(self):
        changes = (lambda value: value['assertions'][0].__setitem__('assertingAgent', account_iri('31337', A(99))),
            lambda value: value['assertions'][0].__setitem__('origin', 'invalid'))
        for change in changes:
            f = NativeArtistReviewFixture([{'payload': payload}, {'payload': lambda c: payload(c, review=True)},
                {'payload': lambda c: payload(c, review=True, mutate=change)}], profile=self.profile)
            source = f.semantic(); result = self.select(source)
            self.assertEqual(len(result['selected']), 1)
            self.assertEqual(len(result['interpretationDiagnostics']), 1)
            self.assertEqual(result['interpretationDiagnostics'][0]['status'], 'invalid')
            with self.assertRaisesRegex(MuseumError, 'unavailable or invalid'): self.select(source, reviewers=(2,))

    def test_same_original_invalid_source_sibling_does_not_veto_exact_valid_selector(self):
        changes = {
            'not_an_assertion': lambda assertion: None,
            'missing_field': lambda assertion: {k: v for k, v in assertion.items() if k != 'assertingAgent'},
            'bad_origin': lambda assertion: assertion | {'origin': 'invalid'},
            'impersonation': lambda assertion: assertion | {'assertingAgent': account_iri('31337', A(99))},
            'forged_evidence': lambda assertion: assertion | {'evidence': [assertion['evidence'][0] | {
                'source': assertion['evidence'][0]['source'] | {'digest': H('forged sibling evidence')}}]},
            'bad_pointer': lambda assertion: assertion | {'evidence': [assertion['evidence'][0] | {
                'selector': '/missing-sibling-evidence'}]},
        }
        for name, change in changes.items():
            def sibling(value): value['assertions'].append(change(copy.deepcopy(value['assertions'][0])))
            f = NativeArtistReviewFixture([{'payload': lambda c: payload(c, mutate=sibling)},
                {'payload': lambda c: payload(c, review=True)}], profile=self.profile)
            source = f.semantic()
            with self.subTest(change=name):
                result = self.select(source)
                self.assertEqual(len(result['selected']), 1)
                valid = result['selected'][0]['source']; invalid = valid | {'pointer': '/assertions/1'}
                assertion, row = source.assertion(valid)
                self.assertEqual(row['payloadHex'], f.publications[0]['original']['payloadHex'])
                self.assertEqual(row['nativeEvidence']['metadataOriginal'], f.publications[0]['original'])
                self.assertEqual(row['value']['assertions'], loads(hex_bytes(row['payloadHex']))['assertions'])
                self.assertEqual([entry['status'] for entry in row['assertionInterpretations']], ['supported', 'invalid'])
                self.assertEqual(result['interpretationDiagnostics'][0]['source'], invalid)
                self.assertEqual(review_body(source, valid, 'reviewed')['assertionRevisionHash'], keccak256(dumps(assertion)))
                with self.assertRaisesRegex(MuseumError, 'unavailable or invalid'): source.assertion(invalid)
                with self.assertRaisesRegex(MuseumError, 'unavailable or invalid'): review_body(source, invalid, 'reviewed')
                with self.assertRaisesRegex(MuseumError, 'unavailable or invalid'):
                    self.select(source, sources=((0, 0), (0, 1)))

    def test_same_original_hostile_review_sibling_is_ignored_until_selected(self):
        def wrong_body(assertion, field):
            literal = assertion['object']['literal']; body = loads(literal['lexicalValue'].encode())
            if field == 'target': body['assertionRecord']['recordHash'] = H('forged sibling target')
            else: body['assertionRevisionHash'] = H('forged sibling revision')
            literal['lexicalValue'] = dumps(body).decode()
        changes = {
            'schema': lambda assertion: assertion.__setitem__('origin', 'invalid'),
            'signer': lambda assertion: assertion.__setitem__('assertingAgent', account_iri('31337', A(99))),
            'evidence': lambda assertion: assertion['evidence'][0]['source'].__setitem__('digest', H('forged sibling evidence')),
            'malformed_body': lambda assertion: assertion['object']['literal'].__setitem__('lexicalValue', '{bad'),
            'forged_target': lambda assertion: wrong_body(assertion, 'target'),
            'forged_revision': lambda assertion: wrong_body(assertion, 'revision'),
        }
        for name, change in changes.items():
            def sibling(value):
                assertion = copy.deepcopy(value['assertions'][0]); assertion['id'] += ':sibling'
                change(assertion); value['assertions'].append(assertion)
            f = NativeArtistReviewFixture([{'payload': payload},
                {'payload': lambda c: payload(c, review=True, mutate=sibling)}], profile=self.profile)
            source = f.semantic()
            with self.subTest(change=name):
                result = self.select(source)
                self.assertEqual(len(result['selected']), 1)
                snapshot = loads(source.snapshot(), maximum=MAX_TRANSCRIPT)
                row = next(row for row in snapshot['statements']
                    if row['source']['recordHash'] == f.publications[1]['original']['recordHash'])
                self.assertEqual(row['payloadHex'], f.publications[1]['original']['payloadHex'])
                self.assertEqual(len(row['value']['assertions']), 2)
                with self.assertRaises(MuseumError): self.select(source, reviewers=((1, 1),))
                with self.assertRaises(MuseumError): self.select(source, reviewers=((1, 0), (1, 1)))

    def test_same_original_sibling_diagnostics_replay_without_payload_rewriting(self):
        def sibling(value): value['assertions'].append({'id': 'urn:invalid:sibling'})
        f = NativeArtistReviewFixture([{'payload': lambda c: payload(c, mutate=sibling)},
            {'payload': lambda c: payload(c, review=True)}], profile=self.profile)
        source = f.semantic(); raw = source.snapshot(); result = self.select(source)
        metadata_raw, artist_raw, semantic_raw = (source.catalogue.transcript(), source.artist.transcript(), source.transcript())
        with patch('socket.socket', side_effect=AssertionError('offline Artist replay used a network')):
            catalogue = MetadataCatalogSource(source.anchor_bytes, ReplayTransport(metadata_raw, keccak256(metadata_raw)))
            artist = ArtistAttestationSource(catalogue, ReplayTransport(artist_raw, keccak256(artist_raw)))
            replay = NativeArtistReviewSource(artist, ReplayTransport(semantic_raw, keccak256(semantic_raw)), profile=self.profile)
            self.assertEqual(replay.snapshot(), raw)
            self.assertEqual(self.select(replay), result)

    def test_registered_definition_gate_is_fatal_even_for_invalid_assertion(self):
        def invalid(value): value['assertions'][0]['origin'] = 'invalid'
        f = NativeArtistReviewFixture([{'payload': lambda c: payload(c, mutate=invalid)}], profile=self.profile)
        kind, raw = self.profile.documents[NAME]
        value = loads(raw); value['wrong'] = 'changed registered definition'
        f.install_document(NAME, kind, dumps(value), predecessor=self.profile.document_predecessors[NAME])
        with self.assertRaisesRegex(MuseumError, 'registered interpretation differs'): f.semantic().snapshot()

    def test_shared_envelope_scope_and_assertion_array_remain_required(self):
        changes = (
            lambda value: value.__setitem__('profileSchemaId', H('wrong schema')),
            lambda value: value['anchorSubject'].__setitem__('subjectId', H('wrong subject')),
            lambda value: value.__setitem__('assertions', []),
            lambda value: value.__setitem__('assertions', None),
            lambda value: value.pop('assertions'),
        )
        for change in changes:
            f = NativeArtistReviewFixture([{'payload': lambda c: payload(c, mutate=change)}], profile=self.profile)
            source = f.semantic(); snapshot = loads(source.snapshot(), maximum=MAX_TRANSCRIPT)
            self.assertEqual(snapshot['statements'][0]['status'], 'invalid')
            self.assertEqual(snapshot['statements'][0]['payloadHex'], f.publications[0]['original']['payloadHex'])
            with self.assertRaisesRegex(MuseumError, 'unavailable or invalid'):
                self.select(source, sources=(0,), reviewers=())

    def test_duplicate_sibling_id_does_not_override_exact_selected_pointer(self):
        def sibling(value):
            assertion = copy.deepcopy(value['assertions'][0])
            assertion['object'] = {'entity': 'urn:fixture:different-object'}
            value['assertions'].append(assertion)
        f = NativeArtistReviewFixture([{'payload': lambda c: payload(c, origin='direct_statement', mutate=sibling)}],
            profile=self.profile)
        source = f.semantic(); first = self.select(source, sources=((0, 0),), reviewers=())['selected'][0]
        second = self.select(source, sources=((0, 1),), reviewers=())['selected'][0]
        self.assertEqual(first['assertion']['id'], second['assertion']['id'])
        self.assertNotEqual(first['assertion']['object'], second['assertion']['object'])
        self.assertNotEqual(first['source'], second['source'])
        self.assertNotEqual(review_body(source, first['source'], 'reviewed')['assertionRevisionHash'],
            review_body(source, second['source'], 'reviewed')['assertionRevisionHash'])

    def test_wrong_profile_record_stays_unsupported_and_cannot_be_selected(self):
        old_hash = NativeAttributionProfile().profile_hash
        f = NativeArtistReviewFixture([{'payload': payload}, {'payload': lambda c: payload(c, review=True,
            mutate=lambda value: value.__setitem__('profileHash', old_hash))}], profile=self.profile)
        source = f.semantic(); result = self.select(source, reviewers=())
        self.assertEqual(result['selected'], [])
        self.assertEqual(result['interpretationDiagnostics'][0]['status'], 'unsupported')
        with self.assertRaisesRegex(MuseumError, 'unavailable or invalid'): self.select(source)

    def test_changed_registered_profile_or_predecessor_rejects_interpretation(self):
        for changed in ('bytes', 'predecessor'):
            f = self.fixture(); kind, raw = self.profile.documents[NAME]
            if changed == 'bytes':
                value = loads(raw); value['wrong'] = 'replaced profile'; raw = dumps(value)
            f.install_document(NAME, kind, raw, predecessor=H('wrong predecessor') if changed == 'predecessor'
                else self.profile.document_predecessors[NAME])
            with self.subTest(changed=changed), self.assertRaises(MuseumError): f.semantic().snapshot()

    def test_current_observations_do_not_change_original_target_body(self):
        f = self.fixture(mode='same_artist'); source = f.semantic(); result = self.select(source, allow_self=True)
        selected = result['selected'][0]
        self.assertNotEqual(selected['currentQualification']['identity'][0], selected['nativeAuthority']['signer'])
        body = review_body(source, selected['source'], 'reviewed')
        self.assertEqual(body['assertionAuthority']['signer'], selected['nativeAuthority']['signer'])
        self.assertNotIn('currentQualification', body['assertionAuthority'])

    def test_concrete_review_record_cannot_be_selected_as_source_or_both_roles(self):
        source = self.fixture().semantic()
        with self.assertRaisesRegex(MuseumError, 'roles overlap'): self.select(source, sources=(0, 1), reviewers=(1,))
        with self.assertRaisesRegex(MuseumError, 'ordinary source assertion'): self.select(source, sources=(1,), reviewers=())


if __name__ == '__main__': unittest.main()
