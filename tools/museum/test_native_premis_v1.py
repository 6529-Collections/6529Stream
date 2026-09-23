"""Concrete V4 payload replay and real conservation Archive branch vectors."""
from copy import deepcopy
from functools import lru_cache
from hashlib import sha256
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from lxml import etree

from . import native_premis_v1 as native
from .bagit import write_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .object_dossier import _ref
from .package_v2 import _dependencies


def parsed(raw): return loads(raw, maximum=native.dossier.MAX_BYTES, canonical=True)


@lru_cache(maxsize=1)
def supplied():
    from .test_native_work_lido_v1 import supplied as original_case
    original, _ = original_case()
    value = parsed(native.inventory._extract(dict(original.files), original.manifest_hash).inventory)
    chosen = [row for row in value['occurrences'] if row['family'] in ('WORK', 'LOAN', 'OWNER_UNKNOWN')]
    plan = dumps({'version': '1', 'kind': native.PLAN_KIND, 'sourceManifestHash': original.manifest_hash,
        'selected': [{'occurrenceId': r['occurrenceId'], 'selector': r['selector']} for r in chosen]})
    return original, plan


@lru_cache(maxsize=1)
def complete():
    original, plan = supplied()
    with patch('socket.socket', side_effect=AssertionError('network disabled')):
        result = native.build(dict(original.files), original.manifest_hash, plan, keccak256(plan), disclosure='public')
    return original, plan, result


@lru_cache(maxsize=3)
def conservation_case(*, catalog=False, materials=True):
    """Real verified conservation V2, projected through the private family seam.

    This is not relabeled as a V4 package and does not test full V4 conservation
    integration: the separate public payload test exercises that V4 boundary.
    """
    from . import conservation_dossier_v2
    from . import conservation_archive_v1
    from .test_conservation_archive_v1 import complete_case
    source, envelope, files = complete_case('external', fixture_kind='av' if catalog else 'written')
    if not materials:
        envelope = conservation_archive_v1.template(dict(source.files)); files = {}
    original = conservation_dossier_v2.build(dict(source.files), source.manifest_hash,
        envelope, keccak256(envelope), files, disclosure='public')
    checked = conservation_dossier_v2.verify(dict(original.files), original.manifest_hash)
    retained = {native.CONSERVATION + path: raw for path, raw in checked.files}
    builder = native.inventory._Builder(retained, original.manifest_hash); builder.conservation()
    inventory = dumps({'profileHash': native.inventory.PROFILE_HASH, 'sourceManifestHash': original.manifest_hash,
        'occurrences': builder.rows, 'fields': builder.fields})
    plan = dumps({'version': '1', 'kind': native.PLAN_KIND, 'sourceManifestHash': original.manifest_hash,
        'selected': [{'occurrenceId': r['occurrenceId'], 'selector': r['selector']} for r in builder.rows]})
    result = native._project(retained, original.manifest_hash, plan, keccak256(plan), native.MODEL_ROOT, inventory)
    return retained, original.manifest_hash, plan, inventory, result


class NativePremisTests(unittest.TestCase):
    def test_concrete_native_payload_files_preserve_all_family_denominator_and_exact_bytes(self):
        original, _, result = complete(); retained = dict(original.files)
        value = parsed(result.files['premis/inventory.json'])
        self.assertGreater(len(value['occurrences']), int(result.report['selectedOccurrenceCount']))
        self.assertTrue(any(r['family'] == 'OWNER_UNKNOWN' and r['objects'] for r in value['occurrences']))
        self.assertEqual(result.report['materialFileCount'], '0')
        self.assertEqual(original.report['packetRequirementCount'], '19')
        self.assertEqual(original.report['dossierRequirementCount'], '49')
        resolver = native._Sources(retained)
        for obj in value['objects']:
            raw = resolver.resolve(obj['bytesSource'])
            self.assertEqual(obj['role'], 'original_record_payload_file')
            self.assertEqual(obj['measured'], {'byteSize': str(len(raw)), 'sha256': '0x' + sha256(raw).hexdigest(),
                'keccak256': keccak256(raw)})
        root = etree.fromstring(result.files['premis/objects.xml']); ns = {'premis': native.NS}
        self.assertFalse(root.xpath('//premis:event | //premis:agent | //premis:rights', namespaces=ns))
        self.assertFalse(result.report['claims']['artworkMediaIdentityInferred'])
        self.assertFalse(result.report['claims']['historicalFixityEventProven'])

    def test_each_native_mapping_resolves_exact_source_and_final_xpath(self):
        original, _, result = complete(); self._provenance(dict(original.files), result)

    def test_generated_labels_do_not_count_as_native_value_mappings(self):
        _, _, payload_result = complete()
        _, _, _, _, material_result = conservation_case(catalog=True)
        labels = {'canonicalization-type', 'original-schema-namespace',
            'declared-format-namespace', 'declared-locator-type'}
        seen, original_algorithms, material_algorithms = set(), set(), set()
        for result in (payload_result, material_result):
            proofs = parsed(result.files['premis/provenance.json'])['rows']
            for proof in proofs:
                rule = proof['rule'].removeprefix(native.RULE)
                if rule in labels:
                    seen.add(rule)
                    self.assertEqual({s['domain'] for s in proof['sources']}, {'original_identity'})
                elif rule == 'original-payload-digest-algorithm':
                    self.assertEqual(len(proof['sources']), 1)
                    source = proof['sources'][0]; original_algorithms.add(source['pointer'])
                    self.assertEqual(source['domain'], 'original')
                    self.assertIn(source['pointer'], ('/record/2/0', '/record/3/0'))
                    self.assertEqual(proof['targetValue'], {1: 'Keccak-256', 2: 'SHA-256'}[int(parsed(hex_bytes(source['exactHex'])))])
                elif rule == 'original-material-digest-algorithm':
                    self.assertEqual(len(proof['sources']), 1)
                    source = proof['sources'][0]; material_algorithms.add(source['pointer'])
                    self.assertTrue(source['pointer'].endswith('/hash/algorithm'))
                    self.assertEqual(proof['targetValue'], {1: 'Keccak-256', 2: 'SHA-256', 3: 'BLAKE3'}[int(parsed(hex_bytes(source['exactHex'])))])
                elif rule.endswith('-digest-hex-without-prefix'):
                    self.assertEqual(len(proof['sources']), 1)
                    self.assertTrue(proof['sources'][0]['pointer'].endswith(('/1', '/hash/digest')))
        self.assertEqual(seen, labels)
        self.assertEqual(original_algorithms, {'/record/2/0', '/record/3/0'})
        self.assertTrue(material_algorithms)

        # Private formatting control only: General's original ABI has no
        # algorithm field. It must not acquire one through digest attribution.
        raw = dumps({'documentary': 'general original payload'})
        original = {'value': [None] * 9}
        original['value'][5:9] = ['0x' + '11' * 32, '0x' + '22' * 32, None, keccak256(raw)]
        files = {'original.json': dumps(original)}; sources = native._Sources(files)
        reference = sources.ref('original.json')
        row = {'occurrenceId': '0x' + '33' * 32, 'family': 'GENERAL',
            'selector': {'kind': 'native_general_attestation'}, 'authority': {},
            'original': reference, 'domains': [{'name': 'original', 'source': reference}]}
        declaration = native._payload_declarations(row, original)
        self.assertIsNone(declaration[4])
        obj = {'id': 'urn:example:general-source-payload', 'row': row, 'raw': raw,
            'role': 'original_record_payload_file', 'bytesSource': reference,
            'domain': 'original', 'referenceIndex': None, 'declarations': declaration, 'material': None}
        model = native.PinnedPremis(native.MODEL_ROOT, native.XSD_PROFILE_BYTES, profile_hash=native.XSD_PROFILE_HASH)
        _, proofs, _ = native._render(sources, [obj], model)
        algorithm = next(p for p in proofs if p['rule'] == native.RULE + 'original-payload-digest-algorithm')
        digest = next(p for p in proofs if p['rule'] == native.RULE + 'original-payload-digest-hex-without-prefix')
        self.assertEqual(algorithm['sources'][0]['domain'], 'original_identity')
        self.assertEqual(digest['sources'][0]['pointer'], '/value/8')

    def _provenance(self, files, result):
        sources = native._Sources(files); root = etree.fromstring(result.files['premis/objects.xml'])
        proofs = parsed(result.files['premis/provenance.json'])['rows']
        for row in proofs:
            target = row['target']; self.assertEqual(target['hash'], keccak256(result.files[target['path']]))
            actual = root.xpath(target['xpath'], namespaces={'premis': native.NS})
            self.assertEqual([v.text for v in actual], [row['targetValue']])
            for source in row['sources']:
                value = sources.resolve(source['sourceReference'])
                if source['domain'] == 'derived_bytes':
                    self.assertIsNone(source['exactHex'])
                    self.assertEqual(source['measurement']['sha256'], '0x' + sha256(value).hexdigest())
                elif source['domain'] == 'original_identity':
                    self.assertIsInstance(value, dict)
                else:
                    if type(value) is bytes: value = parsed(value)
                    scalar = native.pointers._resolve_value(value, source['pointer'], 'json')
                    self.assertEqual('0x' + dumps(scalar).hex(), source['exactHex'])
        fields = parsed(result.files['premis/coverage.json'])['fields']
        native_fields = {(p['occurrenceId'], s['domain'], s['pointer']) for p in proofs for s in p['sources']
            if s['domain'] not in ('derived_bytes', 'original_identity')}
        self.assertEqual({(f['occurrenceId'], f['domain'], f['pointer']) for f in fields if f['disposition'] == 'mapped'}, native_fields)

    def test_real_archive_materials_use_declared_reference_and_received_bytes(self):
        files, _, _, _, result = conservation_case()
        value = parsed(result.files['premis/inventory.json'])
        materials = [o for o in value['objects'] if o['role'] == 'retained_conservation_reference_material']
        self.assertGreater(len(materials), 10)
        self.assertTrue(all(o['correspondenceSource'] is not None for o in materials))
        self.assertEqual(int(result.report['materialFileCount']), len(materials))
        self.assertEqual(result.report['diagnosticCount'], '0')
        self._provenance(files, result)

    def test_real_av_catalog_reference_occurrences_keep_duplicate_object_identities(self):
        files, _, _, _, result = conservation_case(catalog=True)
        value = parsed(result.files['premis/inventory.json']); materials = [o for o in value['objects'] if o['referenceIndex'] is not None]
        self.assertTrue(any(o['domain'].startswith('catalog_') for o in materials))
        self.assertEqual(len({o['id'] for o in materials}), len(materials))
        duplicate_bytes = {}
        for obj in materials: duplicate_bytes.setdefault(obj['measured']['keccak256'], []).append(obj['id'])
        self.assertTrue(any(len(ids) > 1 for ids in duplicate_bytes.values()))
        root = etree.fromstring(result.files['premis/objects.xml'])
        self.assertTrue(root.xpath('//premis:formatRegistry[premis:formatRegistryName="PRONOM"]', namespaces={'premis': native.NS}))
        self._provenance(files, result)

    def test_real_missing_archive_material_keeps_all_reference_diagnostics(self):
        _, _, _, _, result = conservation_case(materials=False)
        value = parsed(result.files['premis/inventory.json'])
        self.assertGreater(len(value['diagnostics']), 10)
        self.assertEqual(result.report['materialFileCount'], '0')
        self.assertTrue(all(o['role'] == 'original_record_payload_file' for o in value['objects']))
        self.assertTrue(all(d['status'] == 'unresolved' for d in value['diagnostics']))
        self.assertFalse(result.report['claims']['archiveDeliveryProven'])

    def test_changed_material_bytes_and_wrong_reference_scope_are_not_rewritten(self):
        files, digest, plan, inventory, result = conservation_case()
        material = next(o for o in parsed(result.files['premis/inventory.json'])['objects'] if o['referenceIndex'] is not None)
        changed = dict(files); changed[material['bytesSource']['path'][7:]] += b'changed'
        with self.assertRaisesRegex(MuseumError, 'material bytes differ'):
            native._project(changed, digest, plan, keccak256(plan), native.MODEL_ROOT, inventory)
        changed = dict(files); path = native.CONSERVATION + 'archive/correspondence.json'; v = parsed(changed[path])
        v['occurrences'][0]['occurrence']['sourceRecord']['recordHash'] = '0x' + '12' * 32; changed[path] = dumps(v)
        with self.assertRaisesRegex(MuseumError, 'Archive occurrence differs'):
            native._project(changed, digest, plan, keccak256(plan), native.MODEL_ROOT, inventory)

    def test_empty_selection_has_no_invented_file_or_fixity(self):
        original, plan, _ = complete(); value = parsed(plan); value['selected'] = []; plan = dumps(value)
        result = native._derive(dict(original.files), original.manifest_hash, plan, keccak256(plan))
        self.assertEqual(result.report['status'], 'empty_selection')
        self.assertEqual(result.report['objectCount'], '0')
        self.assertNotIn('premis/objects.xml', result.files)
        self.assertFalse(any(f['disposition'] == 'mapped' for f in parsed(result.files['premis/coverage.json'])['fields']))

    def test_exact_whole_occurrence_selection_pins_and_no_operator_file_override(self):
        original, plan, _ = complete()
        for mutation in ('selector', 'occurrence', 'path', 'duplicate'):
            value = parsed(plan)
            if mutation == 'selector': value['selected'][0]['selector']['host'] = '0x' + '12' * 20
            elif mutation == 'occurrence': value['selected'][0]['occurrenceId'] = '0x' + '12' * 32
            elif mutation == 'path': value['selected'][0]['path'] = 'caller/file.bin'
            else: value['selected'].append(deepcopy(value['selected'][0]))
            raw = dumps(value)
            with self.subTest(mutation=mutation), self.assertRaises(MuseumError):
                native._derive(dict(original.files), original.manifest_hash, raw, keccak256(raw))
        with self.assertRaisesRegex(MuseumError, 'plan pin'):
            native._derive(dict(original.files), original.manifest_hash, plan, '0x' + '12' * 32)

    def test_rehashed_source_change_still_requires_real_v4_reconstruction(self):
        original, plan, _ = complete(); files = dict(original.files)
        path = 'canonical/inputs/source-inventory.json'; value = parsed(files[path]); value['rows'][0]['authority']['invented'] = True
        files[path] = dumps(value); manifest = parsed(files['manifest.json'])
        manifest['files'] = [_ref(p, raw) for p, raw in sorted(files.items()) if p != 'manifest.json']
        files['manifest.json'] = dumps(manifest); digest = keccak256(files['manifest.json'])
        value = parsed(plan); value['sourceManifestHash'] = digest; plan = dumps(value)
        with self.assertRaises(MuseumError): native.build(files, digest, plan, keccak256(plan), disclosure='public')

    def test_retained_premis_schema_only_and_schema_substitution_rejection(self):
        files, digest, plan, inventory, expected = conservation_case()
        deps = {p.removeprefix('dependencies/'): raw for p, raw in _dependencies(native.MODEL_ROOT, recorded=True, premis=True).items()}
        with TemporaryDirectory() as temporary:
            root = Path(temporary) / 'model'; write_tree(deps, root)
            read = Path.read_bytes
            def retained_only(path):
                if path.resolve().is_relative_to(native.MODEL_ROOT.resolve()): raise AssertionError('repository model fallback')
                return read(path)
            with patch.object(Path, 'read_bytes', retained_only), patch('socket.socket', side_effect=AssertionError('network')):
                self.assertEqual(native._project(files, digest, plan, keccak256(plan), root, inventory), expected)
            # Recommit substituted schema bytes coherently, so the immutable
            # original schema pin (not just chunk integrity) must reject it.
            path = root / 'premis/dependency-index.json'; value = parsed(path.read_bytes())
            document = value['documents'][0]; part = document['chunks'][0]
            chunk = root / part['path']; raw = chunk.read_bytes(); changed = raw[:-1] + bytes([raw[-1] ^ 1])
            chunk.write_bytes(changed); part['sha256'] = '0x' + sha256(changed).hexdigest()
            whole = b''.join((root / p['path']).read_bytes() for p in document['chunks'])
            document['sha256'] = '0x' + sha256(whole).hexdigest(); path.write_bytes(dumps(value))
            with self.assertRaisesRegex(MuseumError, 'original schema mismatch'):
                native._project(files, digest, plan, keccak256(plan), root, inventory)

    def test_public_guard_precedes_source_reads(self):
        class Trap:
            def __iter__(self): raise AssertionError('private read')
        with self.assertRaisesRegex(MuseumError, 'public disclosure'):
            native.build(Trap(), 'bad', b'bad', 'bad', disclosure='restricted')


if __name__ == '__main__': unittest.main()
