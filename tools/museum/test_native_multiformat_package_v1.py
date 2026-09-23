"""Concrete V4 four-format replay and portable exact-source evidence."""
from functools import lru_cache
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import native_multiformat_package_v1 as package
from . import native_multiformat_ledger_v1 as ledger
from . import canonical_field_inventory_v1 as inventory
from .bagit import MAX_BYTES, MAX_MANIFEST, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .object_dossier import _ref
from .package_v2 import verify_package
from .test_native_work_lido_v1 import supplied


def decoded(raw):
    return loads(raw, maximum=MAX_BYTES, canonical=True)


@lru_cache(maxsize=1)
def complete():
    original, lido_plan = supplied(); files = dict(original.files)
    full = decoded(inventory._extract(files, original.manifest_hash).inventory)
    old = {r['occurrenceId']: r for r in decoded(files['canonical/inputs/source-inventory.json'])['rows']}
    selected = [r for r in full['occurrences'] if r['family'] == 'WORK'
        and old[r['originalOccurrenceId']]['semantic'] is not None
        and old[r['originalOccurrenceId']]['semantic']['form'] == 'full']
    choices = [{'occurrenceId': r['occurrenceId'], 'selector': r['selector']} for r in selected]
    plans = {name: {'version': '1', 'kind': 'native_' + name.replace('-', '_'),
        'sourceManifestHash': original.manifest_hash, 'selected': choices}
        for name in ('linked-art', 'premis')}
    plans['iiif'] = {'version': '1', 'kind': 'native_iiif', 'sourceManifestHash': original.manifest_hash,
        'selected': [{**row, 'context': {
            'manifestId': 'https://example.test/native-museum/' + row['occurrenceId'][2:],
            'manifestRights': None, 'attributionLabel': 'Declared native WORK credit',
            'canvasLabel': 'Declared WORK extent',
            'declaredBy': 'https://example.test/synthetic-export-operator'}} for row in choices]}
    plans['lido'] = decoded(lido_plan)
    raw = dumps({'version': '1', 'sourceManifestHash': original.manifest_hash, 'adapters': plans})
    with patch('socket.socket', side_effect=AssertionError('network forbidden')):
        result = package.compose(files, original.manifest_hash, raw, keccak256(raw), disclosure='public')
    return original, raw, result


class NativeMultiformatPackageTests(unittest.TestCase):
    def test_all_four_actual_formats_share_exact_original_fields(self):
        original, plan, result = complete(); files = dict(result.files)
        self.assertEqual({p[7:]: body for p, body in files.items() if p.startswith('source/')}, dict(original.files))
        self.assertTrue(any(p.startswith('linked-art/resources/') for p in files))
        self.assertTrue(any(p.startswith('premis/') and p.endswith('.xml') for p in files))
        self.assertTrue(any(p.startswith('iiif/manifests/') for p in files))
        self.assertTrue(any(p.startswith('lido/records/') and p.endswith('.xml') for p in files))
        full = decoded(files[ledger.INVENTORY_PATH]); mapped = decoded(files[ledger.LEDGER_PATH])
        self.assertEqual(len(mapped['rows']), len(full['fields']))
        comparisons = decoded(files[ledger.COMPARISONS_PATH])['rows']
        titles = [r for r in comparisons if r['domain'] == 'payload' and r['pointer'] == '/title']
        self.assertTrue(titles)
        for row in titles:
            same = next(p for p in row['pairs'] if p['formats'] == ['linked-art', 'lido'])
            self.assertEqual(same['status'], 'equal_target_representations')
            different = next(p for p in row['pairs'] if p['formats'] == ['iiif', 'lido'])
            self.assertEqual(different['status'], 'different_target_representations')
            from .iiif_model import plain_span
            self.assertEqual(different['targets']['iiif'][0]['value']['value'],
                plain_span(different['targets']['lido'][0]['value']['value']))
        self.assertEqual(original.report['packetRequirementCount'], '19')
        self.assertEqual(original.report['dossierRequirementCount'], '49')
        self.assertFalse(result.report['claims']['allNativeFormatsMapped'])
        self.assertFalse(result.report['claims']['fullSemanticAgreementProven'])
        self.assertFalse(result.report['claims']['institutionalAcceptance'])

    def test_family_coverage_keeps_unselected_originals_and_derived_bytes_separate(self):
        _, _, result = complete(); files = dict(result.files)
        full = decoded(files[ledger.INVENTORY_PATH]); coverage = decoded(files[ledger.FAMILIES_PATH])
        self.assertEqual(sum(r['occurrenceCount'] for r in coverage['families']), len(full['occurrences']))
        self.assertEqual(sum(r['fieldCount'] for r in coverage['families']), len(full['fields']))
        self.assertTrue(any(r['family'] != 'WORK' for r in coverage['families']))
        self.assertTrue(all(not any(r['mappedFields'].values()) for r in coverage['families'] if r['family'] != 'WORK'))
        counts = decoded(files[ledger.LEDGER_PATH])['separateEvidenceReferenceCounts']
        self.assertGreater(counts['premis'], 0)
        self.assertGreater(counts['iiif'], 0)

    def test_generic_reopen_replays_using_only_retained_dependencies(self):
        _, _, result = complete(); original_read = Path.read_bytes
        def retained_only(path):
            if path.resolve().is_relative_to(package.MODEL_ROOT.resolve()):
                raise AssertionError('repository dependency fallback')
            return original_read(path)
        with TemporaryDirectory() as temporary:
            target = Path(temporary) / 'package'; write_tree(dict(result.files), target)
            with patch.object(Path, 'read_bytes', retained_only), patch('socket.socket', side_effect=AssertionError('network')):
                reopened = verify_package(target, result.manifest_hash)
            self.assertEqual(dict(reopened.files), dict(result.files))

    def test_rehashed_altered_comparisons_fail_complete_reconstruction(self):
        _, _, result = complete(); files = dict(result.files)
        comparison = decoded(files[ledger.COMPARISONS_PATH]); comparison['rows'] = []
        comparison['fieldsWithAtLeastTwoMappedFormats'] = '0'
        files[ledger.COMPARISONS_PATH] = dumps(comparison)
        manifest = loads(files['manifest.json'], maximum=MAX_MANIFEST, canonical=True)
        manifest['files'] = [_ref(p, raw) for p, raw in sorted(files.items()) if p != 'manifest.json']
        files['manifest.json'] = dumps(manifest)
        with self.assertRaisesRegex(MuseumError, 'full reconstruction'):
            package.verify(files, keccak256(files['manifest.json']))

    def test_external_pin_and_closed_four_plan_source_are_required(self):
        original, raw, result = complete()
        with self.assertRaisesRegex(MuseumError, 'external manifest'):
            package.verify(dict(result.files), '0x' + '12' * 32)
        for change in ('missing_format', 'wrong_source', 'extra'):
            plan = decoded(raw)
            if change == 'missing_format': del plan['adapters']['premis']
            elif change == 'wrong_source': plan['adapters']['iiif']['sourceManifestHash'] = '0x' + '12' * 32
            else: plan['invented'] = True
            changed = dumps(plan)
            with self.subTest(change=change), self.assertRaises(MuseumError):
                package._plan(changed, keccak256(changed), original.manifest_hash)

    def test_public_and_output_overlap_guards_precede_original_reads(self):
        class Trap:
            def __iter__(self): raise AssertionError('private input read')
        with self.assertRaisesRegex(MuseumError, 'public disclosure'):
            package.compose(Trap(), 'bad', b'bad', 'bad', disclosure='restricted')
        with TemporaryDirectory() as temporary:
            root = Path(temporary); source = root / 'source'; source.mkdir()
            plan = root / 'plan.json'; plan.write_bytes(b'{}')
            argv = ['assemble', '--source', str(source), '--source-hash', 'bad', '--plan', str(plan),
                '--plan-hash', 'bad', '--disclosure', 'public', '--output', str(source / 'nested')]
            with patch.object(package, 'read_tree', side_effect=AssertionError('source read')):
                with self.assertRaises(SystemExit) as error: package.main(argv)
            self.assertEqual(error.exception.code, 2)


if __name__ == '__main__':
    unittest.main()
