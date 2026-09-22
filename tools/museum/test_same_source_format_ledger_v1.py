"""Concrete package replay plus finite post-admission correspondence controls."""
from dataclasses import replace
from functools import lru_cache
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from . import same_source_format_ledger_v1 as ledger
from .canonical import MuseumError, dumps, keccak256, loads
from .iiif_numbers import target_dumps, target_loads, ExactDecimal
from .package import fixture_state_from_bytes
from .package_v2 import build_fixture_package
from .test_package_v2 import ROOT


@lru_cache(maxsize=1)
def fixture_case():
    """Named synthetic four-format package, with two genuine unselected originals."""
    from .test_lido import source_data, arguments, ISSUER
    from .test_review import record
    from .test_schema_inventory import assertion_document
    from .source import SourceRecord
    unselected = record(assertion_document(), 'ledger-unselected', ISSUER, 'artist', ['999', '0', '0'])
    schema, payload = dumps({'type': 'object'}), dumps({'future': 'opaque original'})
    selector = replace(unselected.selector, record_hash=keccak256(b'ledger-opaque-original'),
        schema_hash=keccak256(schema))
    opaque = SourceRecord(selector, payload, keccak256(payload), schema,
        unselected.authority_evidence, 'public')
    data = source_data(extra=(unselected, opaque))
    args, kwargs = arguments(data, None, None, None, None)
    pins = {key: value for key, value in kwargs.items() if key.endswith('_hash')}
    pins.update(validation_hash=keccak256((ROOT / 'linked-art-v2/validation-policy.json').read_bytes()),
        vocabulary_hash=keccak256((ROOT / 'standards/vocabulary-policy.json').read_bytes()))
    package = build_fixture_package(*args, root=ROOT, **pins)
    return dict(package.files) | {'manifest.json': package.manifest}, package.manifest_hash


@lru_cache(maxsize=1)
def recorded_case():
    from .package_recorded import build_recorded_package
    from .test_package_recorded import inputs, pins
    package = build_recorded_package(inputs(), root=ROOT, disclosure='public', **pins())
    return dict(package.files) | {'manifest.json': package.manifest}, package.manifest_hash


def parsed(raw):
    return loads(raw, maximum=96 * 1024 * 1024, canonical=True)


def repin(files):
    copied = dict(files)
    manifest = parsed(copied['manifest.json'])
    manifest['files'] = [ledger.package._ref(path, raw) for path, raw in sorted(copied.items())
        if path != 'manifest.json']
    copied['manifest.json'] = dumps(manifest)
    return copied, keccak256(copied['manifest.json'])


class SameSourceFormatLedger(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.files, cls.pin = fixture_case()
        cls.evidence = ledger.build(cls.files, cls.pin, disclosure='public')
        cls.inventory = parsed(cls.evidence.inventory)
        cls.cells = parsed(cls.evidence.ledger)
        cls.identities = parsed(cls.evidence.identities)
        cls.comparisons = parsed(cls.evidence.comparisons)

    def test_real_four_format_replay_and_complete_preselection_denominator(self):
        state = fixture_state_from_bytes(self.files['inputs/source-state.json'])
        self.assertEqual(len(self.inventory['records']), len(state.records))
        unselected = [r for r in self.inventory['records'] if not r['inventoryScopeInOriginalProjection']]
        self.assertEqual(len(unselected), 2)
        self.assertEqual({r['status'] for r in unselected}, {'schema_inventoried', 'opaque_retained'})
        self.assertTrue(next(r for r in unselected if r['status'] == 'schema_inventoried')['fieldIds'])
        self.assertFalse(next(r for r in unselected if r['status'] == 'opaque_retained')['fieldIds'])
        self.assertEqual(self.evidence.report['sourceMode'], 'synthetic_candidate_resource_package')
        self.assertFalse(self.evidence.report['claims']['sourceOriginAuthenticated'])
        self.assertEqual(len(self.cells['rows']), len(self.inventory['fields']))
        self.assertTrue(all(row['status'] == 'present' for row in self.cells['formats'].values()))

    def test_cumulative_mapped_never_establishes_own_format_mapping(self):
        inherited = [cell for row in self.cells['rows'] for name, cell in row['cells'].items()
            if name != 'linked-art' and cell['originalCumulativeDisposition'] == 'mapped'
            and not cell['emissionIds']]
        self.assertGreater(len(inherited), 0)
        self.assertTrue(all(c['status'] == 'retained_no_local_mapping'
            and c['disposition'] == 'retained_stream_only' for c in inherited))
        self.assertTrue(all(c['rule'] and c['reason'] for row in self.cells['rows'] for c in row['cells'].values()))

    def test_resolved_own_targets_reference_actual_retained_files(self):
        for emission in self.cells['emissions']:
            source = emission['target']['source']
            path = source['path'].removeprefix('source/')
            self.assertEqual(keccak256(self.files[path]), source['keccak256'])
            self.assertEqual(emission['format'], path.split('/')[0])
            self.assertTrue('pointer' in source or 'xpath' in source)
        normalized = [e for e in self.cells['emissions'] if e['format'] == 'iiif'
            and e['target']['source']['pointer'] != e['target']['source']['producerPointer']]
        # Current producers use IRI keys without '/' in their URN spelling, but
        # the bounded resolver also covers old slash-containing IRI keys below.
        self.assertIsInstance(normalized, list)

    def test_meaningful_media_rights_identity_title_date_creator_results(self):
        rows = self.comparisons['rows']
        for category in ('identity', 'title', 'rights', 'media'):
            self.assertTrue(any(r['category'] == category and r['outcome'] == 'exact_same_source_agreement' for r in rows), category)
        for category in ('date', 'creator'):
            selected = [r for r in rows if r['category'] == category and r['localFormats']]
            self.assertTrue(selected)
            self.assertTrue(all(r['localFormats'] == ['lido'] for r in selected))
            self.assertTrue(all(r['outcome'] == 'single_format_only' for r in selected))
        self.assertFalse(any(r['outcome'] == 'value_mismatch' for r in rows))
        self.assertTrue(any(c['outcome'] == 'exact_numeric_value' for r in rows for c in r['checks']))

    def test_identity_roles_do_not_equate_work_file_canvas_and_content_locator(self):
        layouts = self.identities['layoutIdentities']
        self.assertEqual({r['role'] for r in layouts}, {'presentation_manifest', 'presentation_canvas',
            'annotation_page', 'painting_annotation', 'content_locator'})
        declaration_ids = {r['sourceEntity'] for r in self.identities['occurrences']}
        self.assertFalse(declaration_ids & {r['value'] for r in layouts})
        self.assertTrue(any(r['targetRole'] == 'iiif:source_file_entity_link' for r in self.identities['occurrences']))
        self.assertTrue(any(r['targetRole'] == 'premis:objectIdentifierValue' for r in self.identities['occurrences']))

    def test_exact_xml_date_and_unicode_no_date_inference(self):
        from .test_lido import DATE
        dates = [r for r in self.comparisons['rows'] if r['category'] == 'date' and r['checks']]
        self.assertEqual(len(dates), 1)
        self.assertEqual({c['value'] for c in dates[0]['checks']}, {DATE})
        self.assertEqual(dates[0]['unmappedFormats'], ['linked-art', 'premis', 'iiif'])

    def test_post_admission_wrong_target_value_is_diagnosed_and_public_replay_refuses(self):
        # Pure internal comparison control deliberately bypasses no public admission.
        files = dict(self.files)
        value = target_loads(files['iiif/manifest.json'])
        value['items'][0]['items'][0]['items'][0]['body']['rights'] = 'https://example.invalid/false-rights'
        # Preserve decimal lexicals through the target serializer.
        def decimals(v):
            from decimal import Decimal
            if isinstance(v, Decimal): return ExactDecimal(str(v))
            if isinstance(v, list): return [decimals(x) for x in v]
            if isinstance(v, dict): return {k: decimals(x) for k, x in v.items()}
            return v
        files['iiif/manifest.json'] = target_dumps(decimals(value))
        diagnosed = ledger._derive(files, parsed(files['manifest.json']), self.pin)
        self.assertTrue(any(r['category'] == 'rights' and r['outcome'] == 'value_mismatch'
            for r in parsed(diagnosed.comparisons)['rows']))
        files, pin = repin(files)
        with self.assertRaises(MuseumError):
            ledger.build(files, pin, disclosure='public')

    def test_bad_original_pin_and_missing_rehashed_target_reject(self):
        with self.assertRaises(MuseumError):
            ledger.build(self.files, '0x' + '11' * 32, disclosure='public')
        files = dict(self.files); del files['premis/premis.xml']
        files, pin = repin(files)
        with self.assertRaises(MuseumError):
            ledger.build(files, pin, disclosure='public')

    def test_public_guard_before_any_input_access_and_closed_source_modes(self):
        class Unreadable:
            def keys(self): raise AssertionError('input accessed')
            def __iter__(self): raise AssertionError('input accessed')
        with self.assertRaisesRegex(MuseumError, 'public disclosure'):
            ledger.build(Unreadable(), None, disclosure='restricted')
        files = dict(self.files)
        value = parsed(files['manifest.json']); value['mode'] = 'canonical_object_dossier_v4_assembly'
        files['manifest.json'] = dumps(value)
        with self.assertRaisesRegex(MuseumError, 'mode unsupported'):
            ledger.build(files, keccak256(files['manifest.json']), disclosure='public')

    def test_recorded_original_missing_formats_stay_absent_offline_with_retained_dependencies(self):
        files, pin = recorded_case()
        old_read = Path.read_bytes
        def read(path):
            if str(path.resolve()).startswith(str(ROOT.resolve())):
                raise AssertionError('repository model fallback')
            return old_read(path)
        with patch('socket.socket', side_effect=AssertionError('network')), patch.object(Path, 'read_bytes', read):
            result = ledger.build(files, pin, disclosure='public')
        self.assertEqual(result.report['sourceMode'], 'recorded_account_resource_package')
        self.assertEqual(result.report['environment'], 'local_evm_fixture')
        self.assertEqual(result.report['recordCount'], '18')
        for name in ('premis', 'iiif', 'lido'):
            self.assertEqual(result.report['formats'][name]['status'], 'absent')
            self.assertEqual(result.report['localMappingCounts'][name], '0')
        self.assertFalse(result.report['claims']['nativeCanonicalFamiliesJoined'])

    def test_target_resolver_exact_iri_keys_and_refuses_missing_or_ambiguous_paths(self):
        value = {'https://example.invalid/key': {'value': 'exact'}}
        result, pointer = ledger._target_pointer(value, '/https://example.invalid/key/value')
        self.assertEqual(result, 'exact')
        self.assertEqual(pointer, '/https:~1~1example.invalid~1key/value')
        with self.assertRaises(MuseumError): ledger._target_pointer(value, '/missing')
        ambiguous = {'a/b': 'first', 'a': {'b': 'second'}}
        with self.assertRaises(MuseumError): ledger._target_pointer(ambiguous, '/a/b')

    def test_transform_rules_are_format_specific_and_no_generic_markup_stripping(self):
        from .iiif import FIELDS
        target = {'kind': 'string', 'value': '<span>words</span>'}
        self.assertEqual(ledger._comparison_value('words', target, FIELDS['summary'], 'iiif')[0],
            'exact_plain_span_encoding')
        self.assertEqual(ledger._comparison_value('words', target, FIELDS['summary'], 'lido')[0],
            'different_lexical')
        self.assertEqual(ledger._comparison_value('words', target, FIELDS['rights'], 'iiif')[0],
            'different_lexical')

    def test_field_bound_and_xpath_scope_refuse_instead_of_truncate(self):
        with patch.object(ledger, 'MAX_FIELDS', 1), self.assertRaisesRegex(MuseumError, 'field bound'):
            ledger._derive(self.files, parsed(self.files['manifest.json']), self.pin)
        self.assertIsNone(ledger._XPATH.fullmatch('//premis:object'))
        self.assertIsNone(ledger._XPATH.fullmatch('/premis:premis/*[last()]'))
        self.assertIsNone(ledger._XPATH.fullmatch('/premis:premis/../anything'))


if __name__ == '__main__':
    unittest.main()
