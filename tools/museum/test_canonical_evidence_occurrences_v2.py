"""Post-verification extraction controls plus concrete native PREMIS replay.

Small V4-shaped maps below test only the internal projection contract. They are
not source admission fixtures and never claim native replay. PREMIS cases use
the actual existing native catalogue fixture and complete package verifier.
"""
from copy import deepcopy
from functools import lru_cache
import unittest

from . import canonical_evidence_occurrences_v2 as occurrences
from . import premis_retained
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id


def H(label): return schema_id('occurrence projection test ' + label)


def small_media(*, mask='1', status='PRESENT'):
    """A labelled post-verification projection input, not native evidence."""
    scope = {'status': status, 'head': [status], 'history': [[status]] if status != 'ABSENT' else [],
        'events': [], 'currentEligibility': {'eligible': False, 'reasons': ['not_checked']}}
    snapshot = {'profile': 'STREAM_MUSEUM_PUBLIC_MEDIA_MASTER_SOURCE_V1',
        'sourceState': {'collectionId': '9'}, 'currentAssociation': [H('artist')],
        'mediaContext': {'occupiedMask': mask, 'manifestHash': H('manifest')},
        'historyCoverage': {'basis': 'post_verification_test_only'},
        'slots': {'1': scope, '2': {**scope, 'status': 'ABSENT', 'history': []},
            '3': {**scope, 'status': 'ABSENT', 'history': []}},
        'manifests': [{'manifestHash': H('manifest'), 'manifest': ['typed original tuple']}],
        'manifestSelections': [{'manifestHash': H('manifest'), 'supportedHost': True}],
        'records': [] if status == 'ABSENT' else [{'recordHash': H('master'), 'record': [],
            'receipt': [], 'value': {'masterRole': 'SOURCE_MASTER'}, 'payloadHex': '0x7b7d'}],
        'coverage': [], 'historicalCandidates': []}
    return {occurrences.MEDIA + 'source/' + name + '.json': dumps(value)
        for name, value in (('snapshot', snapshot), ('anchor', {'synthetic': True}), ('transcript', {'calls': []}))}


def small_render(*, empty=False, current='not_evaluated'):
    """A labelled projection input, with exact binary derivative correspondence."""
    prefix = occurrences.RENDER; original = ['0'] * 16; original[15] = '0x616263'
    row = {'index': '0', 'recordHash': H('reference'), 'receipt': ['native receipt'],
        'receiptFields': {'recordedAt': '11'}, 'nativePublication': ['publication'], 'publication': {'block': '3'},
        'evidenceHash': H('original evidence'),
        'payloadHex': '0x0102', 'publicationAbiHex': '0x0304', 'environmentHex': '0x7b7d',
        'originalSource': original, 'captures': [{'vectorHash': H('vector'), 'animationHTMLHex': '0x3c683e',
            'executionHex': '0x0506'}]}
    snapshot = {'profile': 'STREAM_MUSEUM_PUBLIC_PROSPECTIVE_REFERENCE_SOURCE_V1',
        'sourceState': {'collectionId': '9'}, 'provenance': 'synthetic_fixture', 'historyCoverage': {},
        'currentSource': {'status': current, 'reasons': ['not_evaluated'] if current == 'not_evaluated' else [],
            'source': None, 'sourceHash': None},
        'history': {'count': '0' if empty else '1', 'head': H('none') if empty else row['recordHash'], 'chainHash': H('chain')},
        'records': [] if empty else [row]}
    files = {prefix + 'source/' + name + '.json': dumps(value)
        for name, value in (('snapshot', snapshot), ('anchor', {'synthetic': True}), ('transcript', {'calls': []}))}
    if not empty:
        base = prefix + 'prospective/records/000/'
        files.update({base + key: value for key, value in {'payload.abi': b'\x01\x02', 'publication.abi': b'\x03\x04',
            'environment.json': b'{}', 'script.js': b'abc', 'captures/0.html': b'<h>', 'captures/0.abi': b'\x05\x06'}.items()})
    return files


def small_conservation(*, waived=False):
    """Two duplicate original References with distinct occurrence pointers."""
    prefix = occurrences.CONSERVATION
    ref = {'hash': {'algorithm': 1, 'digest': H('properties'), 'canonicalizationId': H('raw')},
        'uri': 'https://example.invalid/properties.json'}
    records = ([{'family': 'intent_waiver', 'semantic': {'reason': 'authored waiver'}}] if waived else
        [{'family': 'intent', 'semantic': {'significantProperties': ref}} for _ in range(2)])
    dossier = {'source': {'mode': 'synthetic_fixture'}, 'scopes': [{'scope': 'collection', 'status': 'waived' if waived else 'present'}],
        'records': records}
    refs = [] if waived else [{'occurrence': i, 'sourceKind': 'record', 'sourceRecord': {'recordHash': H('original' + str(i))},
        'dossierPath': 'conservation/dossier.json', 'jsonPointer': '/records/' + str(i) + '/semantic/significantProperties',
        'relation': 'significant_properties', **ref} for i in range(2)]
    correspondence = [{'occurrence': r, 'materialPath': None, 'material': None, 'originalHashRefChecked': False,
        'archive': None, 'status': 'unresolved', 'reasons': ['material_not_supplied']} for r in refs]
    return {prefix + 'source/conservation/dossier.json': dumps(dossier),
        prefix + 'source/conservation/reference-occurrences.json': dumps({'profileHash': H('conservation projection'),
            'scope': 'all_closed_reference_occurrences_in_projected_semantics', 'occurrences': refs}),
        prefix + 'archive/correspondence.json': dumps({'occurrences': correspondence})}


@lru_cache(maxsize=5)
def real_premis(mode='matches'):
    from .test_premis_retained import Fixture

    class EmptyProperties(Fixture):
        def _object(self, *args):
            value = super()._object(*args); value['significantProperties'] = []; return value

    fixture = EmptyProperties() if mode == 'empty_properties' else Fixture()
    a = fixture.artifacts(); material = a['files']
    if mode == 'missing': material = {}
    elif mode == 'mismatch': material = {p: b'contradictory local bytes' for p in material}
    elif mode == 'empty_selection':
        plan = loads(a['plan'], canonical=True); plan['objects'] = []
        a['plan'] = dumps(plan); a['planHash'] = keccak256(a['plan']); material = {}
    pins = {'anchor_hash': a['anchorHash'], 'transcript_hash': a['transcriptHash'], 'source_hash': a['sourceHash'],
        'plan_hash': a['planHash'], 'profile_hash': a['profileHash'], 'provenance': 'synthetic_fixture', 'disclosure': 'public'}
    result = premis_retained.build(a['anchor'], a['transcript'], a['plan'], material, **pins)
    premis_retained.verify(result, keccak256(result['manifest.json']))
    return result


class EvidenceOccurrencesTest(unittest.TestCase):
    def rows(self, value, kind):
        return [r for group in value.values() for r in group['occurrences'] if r['kind'] == kind]

    def test_missing_sources_are_not_empty_histories(self):
        result = occurrences.extract({})
        self.assertEqual(set(result), {'media', 'render', 'properties'})
        self.assertTrue(all(g['status'] == 'source_missing' and g['occurrences'] == [] for g in result.values()))

    def test_media_zero_mask_and_absent_head_are_separate(self):
        result = occurrences.extract(small_media(mask='0', status='ABSENT'))
        self.assertEqual(result['media']['status'], 'retained_empty')
        row = self.rows(result, 'media_slot')[0]
        self.assertEqual(row['status'], 'ABSENT'); self.assertFalse(row['value']['occupiedAtSource'])
        self.assertEqual(len(self.rows(result, 'media_manifest')), 1)

    def test_media_waiver_retains_scope_history_and_unknown_eligibility(self):
        result = occurrences.extract(small_media(status='WAIVED'))
        row = self.rows(result, 'media_slot')[0]
        self.assertEqual(row['status'], 'WAIVED'); self.assertTrue(row['value']['occupiedAtSource'])
        self.assertEqual(row['value']['history'], [['WAIVED']])
        self.assertFalse(row['value']['currentEligibility']['eligible'])
        self.assertIn('not a waiver of the whole slot', row['qualification'])
        self.assertNotIn('payloadHex', self.rows(result, 'media_original_record')[0]['value'])

    def test_prospective_empty_keeps_unevaluated_current_source(self):
        result = occurrences.extract(small_render(empty=True))
        self.assertEqual(result['render']['status'], 'retained_empty')
        row = self.rows(result, 'prospective_source_context')[0]
        self.assertEqual(row['status'], 'not_evaluated')
        self.assertEqual(row['value']['history']['count'], '0')
        self.assertEqual(self.rows(result, 'prospective_reference'), [])

    def test_prospective_exact_original_bytes_and_scope(self):
        files = small_render(); result = occurrences.extract(files)
        row = self.rows(result, 'prospective_reference')[0]
        self.assertEqual(row['value']['scope'], 'pre_sale_prospective_simulation')
        self.assertEqual(len(row['sourceReferences']), 5)
        self.assertNotIn('payloadHex', row['value'])
        capture = self.rows(result, 'prospective_capture')[0]
        self.assertEqual(capture['status'], 'retained_html_and_execution_declaration')
        self.assertFalse(capture['value']['pngBytesRetained'])
        self.assertNotIn('nativePublication', row['value'])
        self.assertTrue(capture['sourceReferences'][1]['path'].endswith('/captures/0.html'))

    def test_prospective_missing_or_changed_local_derivative_rejected(self):
        for missing in (False, True):
            files = small_render(); key = occurrences.RENDER + 'prospective/records/000/script.js'
            if missing: del files[key]
            else: files[key] = b'changed script'
            with self.subTest(missing=missing), self.assertRaises(MuseumError): occurrences.extract(files)

    def test_conservation_duplicate_references_remain_two_occurrences(self):
        result = occurrences.extract(small_conservation())
        rows = self.rows(result, 'conservation_significant_properties_reference')
        self.assertEqual(len(rows), 2); self.assertNotEqual(rows[0]['occurrenceId'], rows[1]['occurrenceId'])
        self.assertEqual(rows[0]['value']['reference']['hash'], rows[1]['value']['reference']['hash'])
        self.assertTrue(all(r['status'] == 'unresolved' for r in rows))

    def test_conservation_waiver_is_retained_not_missing_package(self):
        result = occurrences.extract(small_conservation(waived=True))
        self.assertEqual(result['properties']['status'], 'retained_empty')
        self.assertEqual(self.rows(result, 'conservation_properties_context')[0]['value']['recordFamilies'], ['intent_waiver'])
        self.assertEqual(self.rows(result, 'conservation_significant_properties_reference'), [])

    def test_conservation_contradictory_occurrence_pointer_rejected(self):
        files = small_conservation(); path = occurrences.CONSERVATION + 'source/conservation/reference-occurrences.json'
        value = loads(files[path], canonical=True); value['occurrences'][0]['jsonPointer'] = '/records/1/semantic/notPresent'
        files[path] = dumps(value)
        with self.assertRaises(MuseumError): occurrences.extract(files)

    def test_real_conservation_v2_reference_and_material_file_correspondence(self):
        from . import conservation_dossier_v2
        from .test_conservation_archive_v1 import complete_case
        source, envelope, material = complete_case('external')
        built = conservation_dossier_v2.build(dict(source.files), source.manifest_hash,
            envelope, keccak256(envelope), material, disclosure='public')
        checked = conservation_dossier_v2.verify(dict(built.files), built.manifest_hash)
        dossier = {occurrences.CONSERVATION + p: raw for p, raw in checked.files}
        result = occurrences.extract(dossier)
        rows = self.rows(result, 'conservation_significant_properties_reference')
        self.assertTrue(rows)
        for row in rows:
            self.assertEqual(row['status'], 'complete')
            self.assertTrue(row['value']['correspondence']['originalHashRefChecked'])
            local = row['sourceReferences'][-1]
            self.assertIn('/materials/data/', local['path'])
            raw = dossier[local['path'].removeprefix('dossier/')]
            self.assertEqual(local['keccak256'], keccak256(raw))
            self.assertEqual(row['value']['correspondence']['material']['keccak256'], keccak256(raw))

    def test_real_premis_exact_selection_scope_and_decoded_property(self):
        files = real_premis(); result = occurrences.extract({}, files)
        objects = self.rows(result, 'retained_premis_object'); rows = self.rows(result, 'retained_premis_significant_property')
        self.assertEqual((len(objects), len(rows)), (2, 2))
        self.assertEqual([r['value']['selector']['recordHash'] for r in objects],
            [r['recordHash'] for r in loads(files['input/plan.json'], canonical=True)['objects']])
        self.assertTrue(all(r['status'] == 'matches' and r['value']['scope'] == 'declared_object_media' for r in rows))
        self.assertEqual(rows[0]['value']['property'], {'type': 'urn:test:property', 'value': 'retained exact'})
        ref = rows[0]['sourceReferences'][0]
        self.assertTrue(ref['pointer'].endswith('/payloadHex'))
        self.assertEqual(ref['derivation']['jsonPointer'], '/significantProperties/0')

    def test_real_premis_missing_and_mismatching_local_bytes_remain_diagnostics(self):
        for mode in ('missing', 'mismatch'):
            with self.subTest(mode=mode):
                rows = self.rows(occurrences.extract({}, real_premis(mode)), 'retained_premis_significant_property')
                self.assertEqual(len(rows), 2); self.assertTrue(all(r['status'] == mode for r in rows))

    def test_real_premis_empty_properties_retains_whole_original_object(self):
        result = occurrences.extract({}, real_premis('empty_properties'))
        self.assertEqual(result['properties']['status'], 'retained_empty')
        self.assertEqual(len(self.rows(result, 'retained_premis_object')), 2)
        self.assertTrue(all(r['status'] == 'properties_empty' and r['value']['propertyCount'] == '0'
            for r in self.rows(result, 'retained_premis_object')))
        self.assertEqual(self.rows(result, 'retained_premis_significant_property'), [])

    def test_real_premis_empty_selection_preserves_plan_and_full_catalogue(self):
        files = real_premis('empty_selection'); result = occurrences.extract({}, files)
        group = result['properties']
        self.assertEqual(group['status'], 'retained_empty'); self.assertEqual(group['occurrences'], [])
        self.assertEqual(loads(files['input/plan.json'], canonical=True)['objects'], [])
        self.assertEqual(len(loads(files['source/snapshot.json'], maximum=occurrences.MAX_BYTES, canonical=True)['records']), 2)
        plan_ref = next(r for r in group['sourceReferences'] if r['path'] == 'properties/input/plan.json')
        self.assertEqual(plan_ref['keccak256'], keccak256(files['input/plan.json']))
        snapshot_ref = next(r for r in group['sourceReferences'] if r['path'] == 'properties/source/snapshot.json')
        self.assertEqual(snapshot_ref['keccak256'], keccak256(files['source/snapshot.json']))

    def test_real_premis_reordered_or_tampered_selection_and_bytes_rejected(self):
        files = dict(real_premis()); plan = loads(files['input/plan.json'], canonical=True)
        plan['objects'].reverse(); files['input/plan.json'] = dumps(plan)
        with self.assertRaises(MuseumError): occurrences.extract({}, files)
        files = dict(real_premis()); files['retained/media/shared.png'] += b'x'
        with self.assertRaises(MuseumError): occurrences.extract({}, files)

    def test_every_source_pointer_and_hash_resolves_without_mutating_inputs(self):
        dossier = {**small_media(), **small_render(), **small_conservation()}; props = real_premis()
        before = (deepcopy(dossier), deepcopy(props)); result = occurrences.extract(dossier, props)
        combined = {'dossier/' + p: b for p, b in dossier.items()} | {'properties/' + p: b for p, b in props.items()}
        for group in result.values():
            refs = group['sourceReferences'] + [r for row in group['occurrences'] for r in row['sourceReferences']]
            for ref in refs:
                raw = combined[ref['path']]; self.assertEqual(keccak256(raw), ref['keccak256'])
                if ref['derivation']['kind'] != 'raw_bytes':
                    value = occurrences._pointer(loads(raw, maximum=occurrences.MAX_BYTES, canonical=True), ref['pointer'])
                    if ref['derivation']['kind'] == 'hex_decode_then_rfc8785_jcs':
                        decoded = hex_bytes(value); self.assertEqual(keccak256(decoded), ref['derivation']['decodedKeccak256'])
                        occurrences._pointer(loads(decoded, canonical=True), ref['derivation']['jsonPointer'])
        self.assertEqual((dossier, props), before)


if __name__ == '__main__': unittest.main()
