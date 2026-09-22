"""Actual V4 replay and exact native WORK to original LIDO correspondence."""
from copy import deepcopy
from functools import lru_cache
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from lxml import etree

from . import canonical_object_dossier_v4 as dossier
from . import native_work_lido_v1 as native
from .bagit import write_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .object_dossier import _ref
from .package_v2 import _dependencies


def context_for(payload):
    author = 'https://example.test/export-operator'
    context = {'documentLanguage': {'value': 'en', 'declaredBy': author},
        'objectWorkType': {'value': 'digital work', 'language': 'en', 'declaredBy': author},
        'exportPublisher': {'id': 'https://example.test/export-publisher',
            'name': 'Explicit export publisher declaration', 'language': 'en', 'declaredBy': author}}
    if payload['form'] == 'description_absent':
        context['workLabel'] = {'value': 'Operator catalogue label', 'language': 'en', 'declaredBy': author}
    elif payload['creator']['kind'] == 'artist':
        context['artistName'] = {'value': 'Operator declared Artist name', 'language': 'en',
            'declaredBy': author, 'artistId': payload['creator']['artistId'],
            'association': deepcopy(payload['creator']['association'])}
    return context


@lru_cache(maxsize=1)
def supplied():
    """Real source package; synthetic original-wire provenance remains explicit."""
    from .canonical_object_dossier_fixture_v4 import canonical_case
    canonical = canonical_case()
    original = dossier.compose(dict(canonical.files), canonical.manifest_hash, disclosure='public')
    files = dict(original.files)
    inventory = loads(files[native.INVENTORY_PATH], maximum=dossier.MAX_BYTES)
    rows = [row for row in inventory['rows'] if row['family'] == 'WORK' and row['semantic'] is not None]
    plan = {'version': '1', 'kind': native.PLAN_KIND, 'sourceManifestHash': original.manifest_hash,
        'selected': [{'occurrenceId': row['occurrenceId'], 'selector': deepcopy(row['selector']),
            'context': context_for(row['semantic'])} for row in rows]}
    return original, dumps(plan)


@lru_cache(maxsize=1)
def complete():
    original, plan = supplied()
    with patch('socket.socket', side_effect=AssertionError('network forbidden')):
        evidence = native.build(dict(original.files), original.manifest_hash, plan, keccak256(plan), disclosure='public')
    return original, plan, evidence


def pointer(value, path):
    for part in path[1:].split('/') if path else ():
        key = part.replace('~1', '/').replace('~0', '~')
        value = value[int(key)] if type(value) is list else value[key]
    return value


def format_vector(name):
    """Pure typed formatting vector; deliberately not a native admission fixture."""
    from .work_lido_fixture import examples
    payload, _, catalog = deepcopy(examples()[name])
    native.work_lido_source.load_work_source(dumps(payload), expected_subject_id=payload['subjectId'],
        catalog=None if catalog is None else dumps(catalog))
    row = {'occurrenceId': '0x' + 'a1' * 32,
        'selector': {'chainId': '31337', 'core': '0x' + '12' * 20, 'host': '0x' + '34' * 20,
            'subjectId': payload['subjectId'], 'recordHash': '0x' + 'a2' * 32},
        'authority': {'mode': 'pure_format_vector_no_native_authority'}}
    plan = {'selected': [{'context': context_for(payload)}]}
    refs = {'original': {'path': 'unit/original.json', 'hash': keccak256(dumps(row)), 'jsonPointer': '', 'encoding': 'json'},
        'payload': {'path': 'unit/payload.json', 'hash': keccak256(dumps(payload)), 'jsonPointer': '', 'encoding': 'bytes'}}
    model = native.PinnedLIDO(native.MODEL_ROOT, native.XSD_PROFILE_BYTES, profile_hash=native.XSD_PROFILE_HASH)
    return row, payload, plan, refs, model


class NativeWorkLidoTests(unittest.TestCase):
    def test_actual_native_package_maps_title_creator_creation_measurements_and_preserves_original_assessments(self):
        original, plan, result = complete(); files = dict(original.files)
        source = loads(files[native.INVENTORY_PATH], maximum=dossier.MAX_BYTES)
        rows = [r for r in source['rows'] if r['family'] == 'WORK']
        inv = loads(result.files['lido/inventory.json'], maximum=native.MAX_OUTPUT)
        self.assertEqual([r['occurrenceId'] for r in inv['occurrences']], [r['occurrenceId'] for r in rows])
        self.assertEqual(result.report['originalWorkCount'], str(len(rows)))
        row = next(r for r in rows if r['semantic'] is not None and r['semantic']['form'] == 'full')
        xml = etree.fromstring(result.files['lido/records/' + row['occurrenceId'][2:] + '.xml'])
        ns = {'lido': native.NS}
        self.assertEqual(xml.xpath('//lido:titleSet[@lido:type="work-title"]/lido:appellationValue/text()', namespaces=ns)[0], row['semantic']['title'])
        self.assertEqual(xml.xpath('//lido:eventDate/lido:date/lido:earliestDate/text()', namespaces=ns)[0],
            row['semantic']['creation'].get('date', row['semantic']['creation'].get('start')))
        self.assertTrue(xml.xpath('//lido:actorInRole/lido:actor', namespaces=ns))
        self.assertFalse(xml.xpath('//lido:rightsType', namespaces=ns))
        self.assertFalse(result.report['claims']['rightsLicenseInferred'])
        self.assertEqual(original.report['packetRequirementCount'], '19')
        self.assertEqual(original.report['dossierRequirementCount'], '49')
        self.assertNotIn('fixture', result.files['lido/records/' + row['occurrenceId'][2:] + '.xml'].decode())

    def test_every_emitted_correspondence_resolves_original_source_and_final_xpath(self):
        original, plan, result = complete(); files = dict(original.files)
        proofs = loads(result.files['lido/provenance.json'], maximum=native.MAX_OUTPUT)['rows']
        parsed = {}; hashes = {}
        payload_pointers = set()
        for row in proofs:
            target = row['target']; raw = result.files[row['targetPath']]
            self.assertEqual(target['hash'], keccak256(raw))
            root = etree.fromstring(raw)
            found = root.xpath(row['targetXPath'], namespaces={'lido': native.NS, 'xml': native.XML})
            values = [str(v) if not hasattr(v, 'text') else v.text for v in found]
            self.assertEqual(values, [row['targetValue']])
            for ref in row['sources']:
                if ref['domain'] == 'original_identity': continue
                source = ref['sourceReference']
                path = source['path']; raw = plan if path == 'inputs/plan.json' else files[path.removeprefix('source/')]
                if path not in hashes: hashes[path] = keccak256(raw)
                self.assertEqual(source['hash'], hashes[path])
                if path not in parsed: parsed[path] = loads(raw, maximum=dossier.MAX_BYTES)
                value = pointer(parsed[path], source['jsonPointer'])
                if source['encoding'] == 'hex': value = loads(hex_bytes(value), maximum=32768)
                elif source['encoding'] == 'bytes': value = loads(raw, maximum=32768)
                self.assertEqual('0x' + dumps(pointer(value, ref['pointer'])).hex(), ref['exactHex'])
                if ref['domain'] == 'payload': payload_pointers.add(ref['pointer'])
                else: self.assertEqual(ref['qualification'], 'unsigned_operator_record_metadata')
        self.assertIn('/title', payload_pointers)
        self.assertIn('/medium', payload_pointers)
        self.assertTrue(any(p.startswith('/creator/') for p in payload_pointers))

    def test_mapped_field_ledger_only_uses_resolved_own_target_provenance(self):
        _, _, result = complete()
        proofs = loads(result.files['lido/provenance.json'], maximum=native.MAX_OUTPUT)['rows']
        fields = loads(result.files['lido/coverage.json'], maximum=native.MAX_OUTPUT)['fields']
        mapped = {(p['occurrenceId'], s['domain'], s['pointer']) for p in proofs for s in p['sources'] if s['domain'] in ('payload', 'catalog')}
        actual = {(f['occurrenceId'], f['domain'], f['pointer']) for f in fields if f['disposition'] == 'mapped' and f['domain'] != 'operator_plan'}
        self.assertEqual(actual, mapped)
        self.assertTrue(all(f['rule'] and f['reason'] for f in fields))
        self.assertTrue(any(f['domain'] == 'original' and f['disposition'] == 'retained_stream_only' for f in fields))
        self.assertTrue(any(f['presence'] == 'absent' and f['disposition'] == 'not_applicable' for f in fields))

    def test_empty_selection_retains_complete_denominator_without_xml(self):
        original, raw, _ = complete(); plan = loads(raw); plan['selected'] = []; raw = dumps(plan)
        result = native._derive(dict(original.files), original.manifest_hash, raw, keccak256(raw), native.MODEL_ROOT)
        self.assertEqual(result.report['xmlCount'], '0')
        self.assertFalse(any(p.endswith('.xml') for p in result.files))
        self.assertEqual(result.report['originalWorkCount'], complete()[2].report['originalWorkCount'])
        self.assertFalse(any(f['disposition'] == 'mapped' for f in loads(result.files['lido/coverage.json'], maximum=native.MAX_OUTPUT)['fields']))

    def test_exact_occurrence_selector_and_operator_context_are_not_relabelable(self):
        original, raw, _ = complete()
        for mutation in ('selector', 'occurrence', 'publisher_absent', 'language_absent', 'extra', 'duplicate'):
            plan = loads(raw); chosen = plan['selected'][0]
            if mutation == 'selector': chosen['selector']['host'] = '0x' + '11' * 20
            elif mutation == 'occurrence': chosen['occurrenceId'] = '0x' + '11' * 32
            elif mutation == 'publisher_absent': del chosen['context']['exportPublisher']
            elif mutation == 'language_absent': del chosen['context']['documentLanguage']
            elif mutation == 'extra': chosen['context']['rights'] = 'invented'
            else: plan['selected'].append(deepcopy(chosen))
            changed = dumps(plan)
            with self.subTest(mutation=mutation), self.assertRaises(MuseumError):
                native._derive(dict(original.files), original.manifest_hash, changed, keccak256(changed), native.MODEL_ROOT)

    def test_xml_unsafe_operator_text_rejects_without_stripping_and_plan_is_externally_pinned(self):
        original, raw, _ = complete(); plan = loads(raw)
        plan['selected'][0]['context']['exportPublisher']['name'] = 'bad\u0001publisher'
        changed = dumps(plan)
        with self.assertRaises((MuseumError, ValueError)):
            native._derive(dict(original.files), original.manifest_hash, changed, keccak256(changed), native.MODEL_ROOT)
        with self.assertRaisesRegex(MuseumError, 'plan pin'):
            native._derive(dict(original.files), original.manifest_hash, raw, '0x' + '11' * 32, native.MODEL_ROOT)

    def test_retained_xsd_closure_is_used_and_substitution_rejects(self):
        original, plan, expected = complete()
        deps = {p.removeprefix('dependencies/'): raw for p, raw in _dependencies(native.MODEL_ROOT, recorded=True, lido=True).items()}
        with TemporaryDirectory() as temporary:
            root = Path(temporary) / 'model'; write_tree(deps, root)
            original_read = Path.read_bytes
            def retained_only(path):
                if path.resolve().is_relative_to(native.MODEL_ROOT.resolve()): raise AssertionError('repo model read')
                return original_read(path)
            with patch.object(Path, 'read_bytes', retained_only), patch('socket.socket', side_effect=AssertionError('network')):
                self.assertEqual(native._derive(dict(original.files), original.manifest_hash, plan, keccak256(plan), root), expected)
            path = root / 'lido/dependency-index.json'; value = loads(path.read_bytes(), maximum=524288)
            value['invented'] = True; path.write_bytes(dumps(value))
            with self.assertRaisesRegex(MuseumError, 'dependency inventory'):
                native._derive(dict(original.files), original.manifest_hash, plan, keccak256(plan), root)

    def test_rehashed_original_derived_source_cannot_bypass_full_native_replay(self):
        original, raw, _ = complete(); files = dict(original.files)
        inventory = loads(files[native.INVENTORY_PATH], maximum=dossier.MAX_BYTES)
        row = next(r for r in inventory['rows'] if r['family'] == 'WORK' and r['semantic'] is not None)
        row['semantic']['title'] = 'Forged title'; files[native.INVENTORY_PATH] = dumps(inventory)
        manifest = loads(files['manifest.json'], maximum=dossier.MAX_MANIFEST)
        manifest['files'] = [_ref(p, body) for p, body in sorted(files.items()) if p != 'manifest.json']
        files['manifest.json'] = dumps(manifest); digest = keccak256(files['manifest.json'])
        plan = loads(raw); plan['sourceManifestHash'] = digest; raw = dumps(plan)
        with self.assertRaises(MuseumError):
            native.build(files, digest, raw, keccak256(raw), disclosure='public')

    def test_public_guard_precedes_input_inspection(self):
        class Trap:
            def __iter__(self): raise AssertionError('private input read')
        with self.assertRaisesRegex(MuseumError, 'public disclosure'):
            native.build(Trap(), 'bad', b'bad', 'bad', disclosure='restricted')

    def test_pure_formatter_keeps_repeated_titles_variants_large_numbers_and_exact_rationals(self):
        row, payload, plan, refs, model = format_vector('complete')
        _, raw, proofs, _, _ = native._xml(row, payload, plan, dumps(plan), 0, refs, model)
        root = etree.fromstring(raw); ns = {'lido': native.NS}
        self.assertEqual(root.xpath('//lido:titleSet[@lido:type="alternate-title"]/lido:appellationValue/text()', namespaces=ns),
            ['Titre', 'Titre', 'Autre'])
        self.assertEqual(root.xpath('//lido:displayEdition/text()', namespaces=ns),
            [payload['edition']['number'] + ' / ' + payload['edition']['total']])
        self.assertEqual(root.xpath('//lido:displayObjectMeasurements/text()', namespaces=ns),
            ['aspect ratio: 2/4', 'duration in seconds: ' + payload['measurements']['durationSeconds']['numerator']
                + '/' + payload['measurements']['durationSeconds']['denominator']])
        duplicates = [s['pointer'] for proof in proofs for s in proof['sources']
            if s['domain'] == 'payload' and s['pointer'].startswith('/alternateTitles/')]
        self.assertEqual(duplicates, ['/alternateTitles/0', '/alternateTitles/1'])
        self.assertFalse(root.xpath('//lido:resourceWrap | //lido:rightsType', namespaces=ns))

    def test_pure_formatter_artist_context_must_bind_exact_original_association(self):
        row, payload, plan, refs, model = format_vector('complete')
        for change in ('artistId', 'bindingHash', 'bindingGeneration', 'missing'):
            altered = deepcopy(plan); context = altered['selected'][0]['context']
            if change == 'missing': del context['artistName']
            elif change == 'artistId': context['artistName']['artistId'] = '0x' + 'ff' * 32
            else: context['artistName']['association'][change] = '1' if change == 'bindingGeneration' else '0x' + 'ff' * 32
            with self.subTest(change=change), self.assertRaisesRegex(MuseumError, 'exact artist context'):
                native._xml(row, payload, altered, dumps(altered), 0, refs, model)

    def test_pure_formatter_authored_absence_has_label_and_reason_without_creation_or_credit(self):
        row, payload, plan, refs, model = format_vector('absent')
        _, raw, proofs, _, _ = native._xml(row, payload, plan, dumps(plan), 0, refs, model)
        root = etree.fromstring(raw); ns = {'lido': native.NS}
        self.assertEqual(root.xpath('//lido:titleSet/lido:appellationValue/text()', namespaces=ns), ['Operator catalogue label'])
        self.assertFalse(root.xpath('//lido:eventWrap | //lido:rightsWorkWrap | //lido:objectMeasurementsWrap', namespaces=ns))
        self.assertEqual({s['pointer'] for proof in proofs for s in proof['sources'] if s['domain'] == 'payload'},
            {'/absence/reason', '/absence/date'})
        del plan['selected'][0]['context']['workLabel']
        with self.assertRaisesRegex(MuseumError, 'absence needs explicit work label'):
            native._xml(row, payload, plan, dumps(plan), 0, refs, model)


if __name__ == '__main__':
    unittest.main()
