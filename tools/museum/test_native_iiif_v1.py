"""Exact verified native WORK to descriptive IIIF Presentation 3 tests."""
from copy import deepcopy
from functools import lru_cache
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import canonical_field_inventory_v1 as field_inventory
from . import canonical_object_dossier_v4 as dossier
from . import native_iiif_v1 as native
from .bagit import write_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .iiif_numbers import target_loads
from .object_dossier import _ref
from .package_v2 import _dependencies


def context_for(occurrence_id, *, rights=None):
    """Explicit unsigned export context for real and combined fixture tests."""
    return {'manifestId': 'https://example.test/native-iiif/' + occurrence_id[2:] + '/manifest',
        'manifestRights': rights, 'attributionLabel': 'Attribution',
        'canvasLabel': 'Original declared extent',
        'declaredBy': 'https://example.test/native-iiif-export-operator'}


@lru_cache(maxsize=1)
def supplied():
    from .test_native_work_lido_v1 import supplied as lido_source
    original, _ = lido_source()
    inventory_raw = field_inventory._extract(dict(original.files), original.manifest_hash).inventory
    inventory = loads(inventory_raw, maximum=dossier.MAX_BYTES)
    rows = [row for row in inventory['occurrences']
        if row['family'] == 'WORK' and row['interpretation']['status'] == 'interpreted']
    plan = {'version': '1', 'kind': native.PLAN_KIND,
        'sourceManifestHash': original.manifest_hash,
        'selected': [{'occurrenceId': row['occurrenceId'], 'selector': deepcopy(row['selector']),
            'context': context_for(row['occurrenceId'])} for row in rows]}
    return original, inventory_raw, dumps(plan)


@lru_cache(maxsize=1)
def complete():
    original, inventory_raw, plan_raw = supplied()
    with patch('socket.socket', side_effect=AssertionError('network forbidden')):
        result = native.build(dict(original.files), original.manifest_hash,
            plan_raw, keccak256(plan_raw), disclosure='public')
    return original, inventory_raw, plan_raw, result


def pointer(value, path):
    for part in path[1:].split('/') if path else ():
        part = part.replace('~1', '/').replace('~0', '~')
        value = value[int(part)] if type(value) is list else value[part]
    return value


class NativeIiifV1Tests(unittest.TestCase):
    def test_real_v4_work_emits_exact_descriptive_empty_manifest_and_retains_native_scope(self):
        original, inventory_raw, plan_raw, result = complete()
        inventory = loads(inventory_raw, maximum=dossier.MAX_BYTES)
        row = next(row for row in inventory['occurrences'] if row['family'] == 'WORK')
        path = 'iiif/manifests/' + row['occurrenceId'][2:] + '.json'
        manifest = target_loads(result.files[path])
        _, payload = native._Sources(dict(original.files)).domain(row, 'payload')
        self.assertEqual(manifest['label']['none'], [native.iiif.plain_span(payload['title'])])
        self.assertEqual(manifest['summary']['none'], [native.iiif.plain_span(payload['medium'])])
        self.assertEqual(manifest['requiredStatement']['value']['none'],
            [native.iiif.plain_span(payload['creditLine'])])
        self.assertEqual(manifest['items'], [])
        self.assertNotIn('rights', manifest)
        self.assertEqual(result.report['paintingBodyCount'], '0')
        self.assertEqual(result.report['canvasCount'], '0')
        scope = loads(result.files['iiif/source-scope.json'], maximum=native.MAX_OUTPUT)
        self.assertEqual(scope['media']['status'], 'retained_occurrences')
        self.assertEqual(scope['render']['status'], 'retained_occurrences')
        self.assertEqual(scope['paintableCorrespondence']['status'], 'not_established')
        self.assertEqual(result.files['iiif/target-schema.json'], native.TARGET_SCHEMA_BYTES)

    def test_every_mapping_resolves_exact_inventory_domain_and_final_target(self):
        original, inventory_raw, plan_raw, result = complete()
        source_files = dict(original.files); inventory = loads(inventory_raw, maximum=dossier.MAX_BYTES)
        by_id = {row['occurrenceId']: row for row in inventory['occurrences']}
        selected_id = loads(plan_raw)['selected'][0]['occurrenceId']
        source_reader = native._Sources(source_files)
        fields = {(row['occurrenceId'], row['domain'], row['pointer']): row for row in inventory['fields']}
        proofs = loads(result.files['iiif/provenance.json'], maximum=native.MAX_OUTPUT)['rows']
        mapped = set()
        for proof in proofs:
            target = target_loads(result.files[proof['target']['path']])
            actual = pointer(target, proof['target']['pointer'])
            declared = proof['targetValue']
            if type(declared) is dict and set(declared) == {'kind', 'lexical'}:
                self.assertEqual(str(actual), declared['lexical'])
            else: self.assertEqual(actual, declared)
            self.assertEqual(proof['target']['hash'], keccak256(result.files[proof['target']['path']]))
            for source in proof['sources']:
                if source['domain'] in ('operator_context', 'original_identity'): continue
                row = by_id[proof['occurrenceId']]
                domain = next(domain for domain in row['domains'] if domain['name'] == source['domain'])
                self.assertEqual(source['sourceReference'], domain['source'])
                _, source_value = source_reader.domain(row, source['domain'])
                scalar = pointer(source_value, source['pointer'])
                self.assertEqual(source['exactHex'], '0x' + dumps(scalar).hex())
                key = (proof['occurrenceId'], source['domain'], source['pointer'])
                self.assertEqual(fields[key]['exactHex'], source['exactHex']); mapped.add(key)
        coverage = loads(result.files['iiif/coverage.json'], maximum=native.MAX_OUTPUT)['fields']
        self.assertEqual({(r['occurrenceId'], r['domain'], r['pointer']) for r in coverage
            if r['disposition'] == 'mapped'}, mapped)
        self.assertEqual(mapped, {(selected_id, 'payload', '/title'),
            (selected_id, 'payload', '/medium'),
            (selected_id, 'payload', '/creditLine')})

    def test_explicit_manifest_rights_remain_operator_context_not_native_rights(self):
        original, inventory_raw, raw, _ = complete(); plan = loads(raw)
        right = native.iiif.RIGHTS[0]; plan['selected'][0]['context']['manifestRights'] = right
        raw = dumps(plan); result = native._derive(dict(original.files), original.manifest_hash,
            raw, keccak256(raw), native.MODEL_ROOT, inventory_raw=inventory_raw)
        manifest = target_loads(next(body for path, body in result.files.items()
            if path.startswith('iiif/manifests/')))
        self.assertEqual(manifest['rights'], right)
        proof = next(row for row in loads(result.files['iiif/provenance.json'], maximum=native.MAX_OUTPUT)['rows']
            if row['target']['pointer'] == '/rights')
        self.assertEqual(proof['sources'][0]['domain'], 'operator_context')
        self.assertEqual(proof['sources'][0]['declaredBy'], plan['selected'][0]['context']['declaredBy'])
        plan['selected'][0]['context']['manifestRights'] = 'https://example.test/invented-rights'
        changed = dumps(plan)
        with self.assertRaisesRegex(MuseumError, 'closed plan'):
            native._derive(dict(original.files), original.manifest_hash,
                changed, keccak256(changed), native.MODEL_ROOT, inventory_raw=inventory_raw)

    def test_empty_selection_preserves_full_denominator_without_manifest(self):
        original, inventory_raw, raw, _ = complete(); plan = loads(raw); plan['selected'] = []; raw = dumps(plan)
        result = native._derive(dict(original.files), original.manifest_hash,
            raw, keccak256(raw), native.MODEL_ROOT, inventory_raw=inventory_raw)
        self.assertEqual(result.report['status'], 'empty_selection')
        self.assertEqual(result.report['manifestCount'], '0')
        self.assertFalse(any(path.startswith('iiif/manifests/') for path in result.files))
        self.assertEqual(len(loads(result.files['iiif/index.json'], maximum=native.MAX_OUTPUT)['occurrences']),
            len(loads(inventory_raw, maximum=dossier.MAX_BYTES)['occurrences']))
        self.assertFalse(any(row['disposition'] == 'mapped'
            for row in loads(result.files['iiif/coverage.json'], maximum=native.MAX_OUTPUT)['fields']))

    def test_selection_requires_exact_interpreted_work_and_context_identities(self):
        original, inventory_raw, raw, _ = complete(); source = loads(inventory_raw, maximum=dossier.MAX_BYTES)
        for mutation in ('selector', 'occurrence', 'duplicate', 'owner', 'manifest_query', 'identity_collision'):
            plan = loads(raw); chosen = plan['selected'][0]
            if mutation == 'selector': chosen['selector']['host'] = '0x' + '11' * 20
            elif mutation == 'occurrence': chosen['occurrenceId'] = '0x' + '11' * 32
            elif mutation == 'duplicate': plan['selected'].append(deepcopy(chosen))
            elif mutation == 'owner':
                row = next(row for row in source['occurrences'] if row['family'] != 'WORK')
                chosen.update(occurrenceId=row['occurrenceId'], selector=row['selector'])
            elif mutation == 'manifest_query': chosen['context']['manifestId'] += '?version=1'
            else: chosen['context']['declaredBy'] = chosen['context']['manifestId']
            changed = dumps(plan)
            with self.subTest(mutation=mutation), self.assertRaises(MuseumError):
                native._derive(dict(original.files), original.manifest_hash,
                    changed, keccak256(changed), native.MODEL_ROOT, inventory_raw=inventory_raw)
        with self.assertRaisesRegex(MuseumError, 'cross-selected structural identity collision'):
            native._check_identities([
                ('https://example.test/a/manifest', True, 'https://example.test/operator'),
                ('https://example.test/a/manifest/canvas/0', False, 'https://example.test/other-operator')])
        with self.assertRaisesRegex(MuseumError, 'operator and structural identity collision'):
            native._check_identities([
                ('https://example.test/a/manifest', False, 'https://example.test/a/manifest')])

    def test_exact_rationals_reduce_and_never_round(self):
        half, reason = native._terminating_decimal('3', '6')
        self.assertIsNone(reason); self.assertEqual(half.lexical, '0.5')
        power, reason = native._terminating_decimal('1', str(2 ** 100))
        expected_digits = str(5 ** 100)
        expected = '0.' + ('0' * (100 - len(expected_digits))) + expected_digits
        self.assertIsNone(reason); self.assertEqual(power.lexical, expected)
        missing, reason = native._terminating_decimal('1', '3')
        self.assertIsNone(missing); self.assertEqual(reason,
            'duration_rational_has_no_finite_decimal_representation')
        over, reason = native._terminating_decimal('1', str(2 ** 200))
        self.assertIsNone(over); self.assertEqual(reason,
            'duration_exact_decimal_exceeds_target_lexical_bound')

    def test_pure_explicit_measurements_create_only_unpainted_canvas(self):
        payload = {'measurements': {'kind': 'measured',
            'pixels': {'width': str((1 << 53) - 1), 'height': '2160', 'unit': 'pixels'},
            'durationSeconds': {'numerator': '3', 'denominator': '6'}}}
        extent, used, diagnostics = native._extent(payload)
        self.assertEqual(extent['width'], (1 << 53) - 1)
        self.assertEqual(extent['height'], 2160)
        self.assertEqual(extent['duration'].lexical, '0.5')
        self.assertEqual(set(used), {'/measurements/pixels/width', '/measurements/pixels/height',
            '/measurements/durationSeconds/numerator', '/measurements/durationSeconds/denominator'})
        self.assertEqual(diagnostics, [])
        payload['measurements']['pixels']['width'] = str(1 << 53)
        payload['measurements']['durationSeconds'] = {'numerator': '1', 'denominator': '3'}
        extent, _, diagnostics = native._extent(payload)
        self.assertEqual(extent, {})
        self.assertEqual(set(diagnostics), {'pixel_extent_exceeds_finite_IIIF_integer_profile',
            'duration_rational_has_no_finite_decimal_representation'})

    def test_retained_context_closure_is_used_and_target_schema_is_additive(self):
        original, inventory_raw, raw, expected = complete()
        deps = {path.removeprefix('dependencies/'): body for path, body in
            _dependencies(native.MODEL_ROOT, recorded=True, iiif=True).items()}
        with TemporaryDirectory() as temporary:
            root = Path(temporary) / 'model'; write_tree(deps, root)
            original_read = Path.read_bytes
            def retained_only(path):
                if path.resolve().is_relative_to(native.MODEL_ROOT.resolve()):
                    raise AssertionError('repository model read')
                return original_read(path)
            with patch.object(Path, 'read_bytes', retained_only), patch('socket.socket',
                    side_effect=AssertionError('network used')):
                self.assertEqual(native._derive(dict(original.files), original.manifest_hash,
                    raw, keccak256(raw), root, inventory_raw=inventory_raw), expected)
            path = root / 'iiif/dependency-index.json'; value = loads(path.read_bytes(), maximum=524288)
            value['invented'] = True; path.write_bytes(dumps(value))
            with self.assertRaisesRegex(MuseumError, 'dependency inventory'):
                native._derive(dict(original.files), original.manifest_hash,
                    raw, keccak256(raw), root, inventory_raw=inventory_raw)
        schema = loads(native.TARGET_SCHEMA_BYTES)
        self.assertEqual(schema['properties']['items']['minItems'], 0)
        self.assertNotIn('rights', schema['required'])
        self.assertEqual(schema['$defs']['canvas']['properties']['items']['minItems'], 0)

    def test_rehashed_derived_inventory_tamper_cannot_bypass_public_v4_replay(self):
        original, _, raw, _ = complete(); files = dict(original.files)
        path = 'canonical/inputs/source-inventory.json'; source = loads(files[path], maximum=dossier.MAX_BYTES)
        row = next(row for row in source['rows'] if row['family'] == 'WORK' and row['semantic'] is not None)
        row['semantic']['title'] = 'Forged source title'; files[path] = dumps(source)
        manifest = loads(files['manifest.json'], maximum=dossier.MAX_MANIFEST)
        manifest['files'] = [_ref(name, body) for name, body in sorted(files.items()) if name != 'manifest.json']
        files['manifest.json'] = dumps(manifest); changed_hash = keccak256(files['manifest.json'])
        plan = loads(raw); plan['sourceManifestHash'] = changed_hash; changed = dumps(plan)
        with self.assertRaises(MuseumError):
            native.build(files, changed_hash, changed, keccak256(changed), disclosure='public')

    def test_public_guard_precedes_inputs_and_target_refuses_painting_invention(self):
        class Trap:
            def __iter__(self): raise AssertionError('private input read')
        with self.assertRaisesRegex(MuseumError, 'public disclosure'):
            native.build(Trap(), 'bad', b'bad', 'bad', disclosure='restricted')
        _, _, _, result = complete()
        raw = next(body for path, body in result.files.items() if path.startswith('iiif/manifests/'))
        value = target_loads(raw)
        value['items'] = [{'id': value['id'] + '/canvas/0', 'type': 'Canvas',
            'label': {'none': [native.iiif.plain_span('Invented')]},
            'items': [{'invented': True}]}]
        with self.assertRaises(MuseumError):
            native._validate_target(native.target_dumps(value), native.MODEL_ROOT)


if __name__ == '__main__':
    unittest.main()
