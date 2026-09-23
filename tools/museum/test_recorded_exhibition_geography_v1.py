"""Concrete offline joins; synthetic transcripts do not prove real geography."""
from copy import deepcopy
from functools import lru_cache
import unittest
from unittest.mock import patch

from . import recorded_exhibition_geography_v1 as geography
from .canonical import MuseumError, dumps, keccak256, loads
from .exhibition_geography_owner_fixture_v1 import admit_owner_case
from .object_dossier import _ref
from .recorded_exhibition_geography_fixture_v1 import build_authority_case


def authority_case(match_kind='equivalent_entity', review_status='reviewed', alternate_declaration=False, publication_block='4'):
    return _authority_case(match_kind, review_status, alternate_declaration, publication_block)


@lru_cache(maxsize=8)
def _authority_case(match_kind, review_status, alternate_declaration, publication_block):
    return build_authority_case(match_kind=match_kind, review_status=review_status,
        alternate_declaration=alternate_declaration, publication_block=publication_block)


def owner_case(status='completed', wrong_hash=False):
    return _owner_case(status, wrong_hash)


@lru_cache(maxsize=4)
def _owner_case(status, wrong_hash):
    authority = authority_case()
    return _owner_payload(authority['declarationBytes'], authority['entityId'], status, wrong_hash)


@lru_cache(maxsize=4)
def _owner_payload(payload, venue_id, status, wrong_hash):
    return admit_owner_case(payload, venue_id=venue_id,
        status=status, location_hash=keccak256(b'unrelated original declaration') if wrong_hash else None)


def binding_case(owner, identity, inventory, authority):
    row = next(row for row in inventory['rows'] if row['occurrenceId'] == identity['occurrenceId'])
    return {'version': '1', 'profileHash': geography.PROFILE_HASH,
        'ownerSourceProfileHash': geography.sources.PROFILE_HASH,
        'ownerManifestHash': owner.manifest_hash, 'ownerOccurrenceId': row['occurrenceId'],
        'ownerSelector': deepcopy(row['selector']), 'venuePointer': '/venue', 'locationPointer': '/venue/location',
        'authorityProfileHash': geography.authority.PROFILE_HASH,
        'authorityManifestHash': authority['manifestHash'],
        'declarationSelector': deepcopy(authority['declarationSelector']), 'declarationHash': authority['declarationHash'],
        'role': 'exhibition_location', 'rationale': 'Exact original owner location reference to the retained Place declaration.'}


def build_case(*, status='completed', wrong_hash=False, match_kind='equivalent_entity', review_status='reviewed',
               alternate_declaration=False, publication_block='4', edit=None):
    authority = authority_case(match_kind, review_status, alternate_declaration, publication_block)
    owner, identity, inventory = _owner_payload(authority['declarationBytes'], authority['entityId'], status, wrong_hash)
    binding = binding_case(owner, identity, inventory, authority)
    if edit is not None: edit(binding)
    raw = dumps(binding)
    return geography.build(dict(owner.files), owner.manifest_hash, authority['files'],
        authority['manifestHash'], raw, keccak256(raw), disclosure='public')


@lru_cache(maxsize=1)
def positive():
    return build_case()


def resources(result):
    return {value['type']: value for path, raw in result.files
        if path.startswith('geography/resources/') for value in [loads(raw)]}


def rehash(files):
    manifest = loads(files['manifest.json'], maximum=geography.MAX_MANIFEST, canonical=True)
    manifest['files'] = [_ref(path, raw) for path, raw in sorted(files.items()) if path != 'manifest.json']
    files['manifest.json'] = dumps(manifest)
    return keccak256(files['manifest.json'])


class RecordedExhibitionGeographyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with patch('socket.socket', side_effect=AssertionError('network used')):
            cls.result = positive()

    def test_original_owner_reference_and_separate_reviewed_tgn_identity(self):
        output = resources(self.result); files = dict(self.result.files)
        evidence = loads(files['geography/selected-evidence.json'])
        self.assertEqual(set(output), {'Activity', 'Group', 'Place'})
        self.assertEqual(output['Activity']['took_place_at'], [{'id': output['Place']['id'], 'type': 'Place'}])
        self.assertEqual(output['Place']['equivalent'][0]['id'], evidence['equivalent'])
        self.assertEqual(output['Place']['_label'], evidence['ownerPayload']['venue']['name']['value'])
        self.assertEqual(evidence['ownerPayload']['venue']['location']['hash']['digest'],
            evidence['declarationPayloadHash'])
        self.assertNotEqual(evidence['declarationPayloadHash'], evidence['declaration']['declarationHash'])
        self.assertEqual(evidence['ownerAuthority']['mode'], 'historical_native_owner_receipt')
        self.assertEqual(evidence['declarationAuthority']['mode'], 'historical_independent_account')
        self.assertTrue(evidence['claims']['ownerReferencedDeclarationBytes'])
        self.assertFalse(evidence['claims']['ownerApprovedTgnIdentity'])
        self.assertFalse(evidence['claims']['independentHumanReviewProven'])
        self.assertFalse(evidence['claims']['historicalPerformanceProven'])
        self.assertFalse(evidence['claims']['sharedCanonicalHistoryProven'])
        self.assertEqual(self.result.report['ownerSourceProvenance'], 'synthetic_fixture')
        self.assertEqual(authority_case()['provenance']['mode'], 'externally_admitted_synthetic_transcript')

    def test_complete_original_sources_and_unsupported_owner_denominator_retained(self):
        files = dict(self.result.files); owner, _, inventory = owner_case()
        self.assertEqual({path.removeprefix('sources/owner/'): raw for path, raw in files.items()
            if path.startswith('sources/owner/')}, dict(owner.files))
        self.assertEqual({path.removeprefix('sources/authority/'): raw for path, raw in files.items()
            if path.startswith('sources/authority/')}, authority_case()['files'])
        self.assertEqual(loads(files['source/owner-inventory.json'], maximum=geography.MAX_BYTES), inventory)
        owner_rows = [row for row in inventory['rows'] if row['ownerMeaning'] is not None]
        self.assertEqual(len(owner_rows), 18)
        self.assertTrue(any(row['semantic'] is None for row in owner_rows))
        self.assertIn('sources/authority/authority/snapshot-index.json', files)
        self.assertIn('sources/authority/authority/selection.json', files)
        locations = loads(files['source/locations.json'])
        self.assertEqual(locations['ownerOriginalReferenceBase'], 'sources/owner/')
        self.assertEqual(locations['ownerDefinitionsReferenceBase'], '')

    def test_all_source_and_graph_leaves_have_retained_coverage(self):
        files = dict(self.result.files); evidence = loads(files['geography/selected-evidence.json'])
        coverage = loads(files['geography/coverage.json'], maximum=geography.MAX_BYTES)
        actual = [(row['pointer'], row['value']) for row in coverage if row['source'] == 'owner_payload']
        self.assertEqual(actual, list(geography.exhibitions.fields(evidence['ownerPayload'])))
        actual = [(row['pointer'], row['value']) for row in coverage if row['source'] == 'bound_declaration']
        self.assertEqual(actual, list(geography.exhibitions.fields(evidence['declaration']['value'])))
        provenance = loads(files['geography/provenance.json'], maximum=geography.MAX_BYTES)
        for resource in resources(self.result).values():
            actual = [(row['graphPointer'], row['value']) for row in provenance if row['entity'] == resource['id']]
            self.assertEqual(len(actual), len(dict(actual)))
            self.assertEqual(dict(actual), dict(geography.exhibitions.fields(resource)))
        equivalences = [row for row in provenance if row['graphPointer'].startswith('/equivalent')]
        self.assertTrue(equivalences)
        self.assertTrue(all(row['authorityEvidence'] == 'sources/authority/authority/provenance.json' for row in equivalences))

    def test_complete_package_roundtrip_uses_retained_dependencies_offline(self):
        with patch('socket.socket', side_effect=AssertionError('network used')):
            rebuilt = geography.verify(dict(self.result.files), self.result.manifest_hash)
        self.assertEqual(rebuilt.files, self.result.files)
        self.assertEqual(rebuilt.manifest_hash, self.result.manifest_hash)

    def test_planned_exhibition_has_place_without_performed_activity(self):
        with patch('socket.socket', side_effect=AssertionError('network used')):
            result = build_case(status='planned')
        self.assertEqual(set(resources(result)), {'Place'})
        self.assertEqual(result.report['graph']['disposition'], 'nonperformed_source')
        self.assertTrue(result.report['graph']['boundEquivalentEmitted'])

    def test_weak_match_retains_original_alignment_without_equivalent(self):
        with patch('socket.socket', side_effect=AssertionError('network used')):
            result = build_case(match_kind='close_match')
        self.assertNotIn('equivalent', resources(result)['Place'])
        self.assertFalse(result.report['graph']['boundEquivalentEmitted'])
        rows = loads(dict(result.files)['sources/authority/authority/sidecar.json'])
        self.assertEqual(rows[0]['body']['alignment']['matchKind'], 'close_match')

    def test_missing_review_and_dispute_cannot_promote_original_identity(self):
        for status in ('unreviewed', 'disputed'):
            with self.subTest(status=status), patch('socket.socket', side_effect=AssertionError('network used')):
                result = build_case(review_status=status)
                self.assertNotIn('equivalent', resources(result)['Place'])
                self.assertFalse(result.report['graph']['boundEquivalentEmitted'])
                rows = loads(dict(result.files)['sources/authority/authority/sidecar.json'])
                reason = 'mapping_lacks_selected_authenticated_review' if status == 'unreviewed' else 'withdrawn_or_disputed_alignment'
                self.assertIn(reason, rows[0]['reasons'])

    def test_resolved_same_iri_mapping_cannot_cross_to_another_original_declaration(self):
        with patch('socket.socket', side_effect=AssertionError('network used')):
            result = build_case(alternate_declaration=True)
        files = dict(result.files); selected = loads(files['geography/selected-evidence.json'])
        candidates = loads(files['sources/authority/authority/sidecar.json'], maximum=geography.MAX_BYTES)
        self.assertEqual(selected['authorityResult']['status'], 'resolved')
        self.assertTrue(candidates[0]['eligible'])
        self.assertEqual(candidates[0]['entityDeclaration']['value']['id'], selected['declaration']['value']['id'])
        self.assertNotEqual(candidates[0]['entityDeclaration'], selected['declaration'])
        self.assertEqual(selected['eligibleBoundAssertions'], [])
        self.assertIsNone(selected['equivalent'])
        self.assertNotIn('equivalent', resources(result)['Place'])

    def test_later_original_declaration_cannot_backdate_owner_reference(self):
        with self.assertRaisesRegex(MuseumError, 'declaration must precede owner publication'):
            build_case(publication_block='6')

    def test_matching_venue_iri_cannot_replace_original_owner_hash_commitment(self):
        with self.assertRaisesRegex(MuseumError, 'owner location does not commit'):
            build_case(wrong_hash=True)

    def test_wrong_original_declaration_selector_rejects(self):
        with self.assertRaisesRegex(MuseumError, 'recorded selector mismatch'):
            build_case(edit=lambda value: value['declarationSelector'].update(recordHash=keccak256(b'foreign declaration')))

    def test_changed_entity_hash_with_resealed_binding_rejects(self):
        with self.assertRaisesRegex(MuseumError, 'exact Place declaration differs'):
            build_case(edit=lambda value: value.update(declarationHash=keccak256(b'changed entity')))

    def test_closed_binding_and_external_pins_reject_before_source_reads(self):
        owner, identity, inventory = owner_case(); authority = authority_case()
        binding = binding_case(owner, identity, inventory, authority)
        for field, changed in [('role', 'custody_location'), ('venuePointer', '/institution'),
                ('locationPointer', '/venue/location/uri'), ('ownerSourceProfileHash', keccak256(b'foreign profile')),
                ('authorityManifestHash', keccak256(b'foreign authority')), ('rationale', '')]:
            with self.subTest(field=field):
                value = deepcopy(binding); value[field] = changed; raw = dumps(value)
                with self.assertRaises(MuseumError):
                    geography._binding(raw, keccak256(raw), owner.manifest_hash, authority['manifestHash'])
        value = deepcopy(binding); value['verified'] = True; raw = dumps(value)
        with self.assertRaisesRegex(MuseumError, 'closed binding'):
            geography._binding(raw, keccak256(raw), owner.manifest_hash, authority['manifestHash'])
        raw = dumps(binding)
        with self.assertRaisesRegex(MuseumError, 'external pin'):
            geography._binding(raw, keccak256(b'foreign binding'), owner.manifest_hash, authority['manifestHash'])

    def test_rehashed_proof_claims_fail_full_reconstruction(self):
        files = dict(self.result.files); evidence = loads(files['geography/selected-evidence.json'])
        evidence['claims']['ownerApprovedTgnIdentity'] = True
        files['geography/selected-evidence.json'] = dumps(evidence)
        with self.assertRaisesRegex(MuseumError, 'full reconstruction'):
            geography.verify(files, rehash(files))

    def test_rehashed_place_equivalent_cannot_substitute_another_identity(self):
        files = dict(self.result.files)
        path = next(path for path, raw in files.items() if path.startswith('geography/resources/')
            and loads(raw)['type'] == 'Place')
        value = loads(files[path]); value['equivalent'][0]['id'] = 'http://vocab.getty.edu/tgn/1000074'
        files[path] = dumps(value)
        with self.assertRaisesRegex(MuseumError, 'full reconstruction'):
            geography.verify(files, rehash(files))

    def test_retained_source_bytes_cannot_be_substituted_by_rehashing_outer_manifest(self):
        files = dict(self.result.files)
        path = 'sources/authority/authority/sidecar.json'
        rows = loads(files[path]); rows[0]['eligible'] = False; files[path] = dumps(rows)
        with self.assertRaises(MuseumError): geography.verify(files, rehash(files))

    def test_missing_retained_definition_or_model_cannot_fall_back_to_repository(self):
        for prefix in ('definitions/owner-genesis-plan/definitions/', 'dependencies/'):
            with self.subTest(prefix=prefix):
                files = dict(self.result.files); path = next(p for p in files if p.startswith(prefix))
                del files[path]
                with self.assertRaises((MuseumError, OSError)): geography.verify(files, rehash(files))

    def test_explicit_public_decision_precedes_source_access(self):
        with self.assertRaisesRegex(MuseumError, 'public disclosure before reads'):
            geography.build(None, None, None, None, None, None, disclosure='restricted')


if __name__ == '__main__': unittest.main()
