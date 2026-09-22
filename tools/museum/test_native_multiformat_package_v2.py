"""Concrete retained V4 replay, separate source coverage and portable reopening."""
from functools import lru_cache
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from lxml import etree

from . import canonical_field_inventory_v1 as inventory
from . import native_multiformat_package_v2 as package
from . import native_multiformat_ledger_v2 as ledger
from .bagit import MAX_BYTES, MAX_MANIFEST, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .object_dossier import _ref
from .package_v2 import verify_package
from .test_native_work_lido_v1 import supplied
from .test_native_premis_v2 import plan_for as premis_plan


def decoded(raw):
    return loads(raw, maximum=MAX_BYTES, canonical=True)


def plans_for(original, lido_raw, iiif_plan):
    files = dict(original.files); full = decoded(inventory._extract(files, original.manifest_hash).inventory)
    old = {row['occurrenceId']: row for row in decoded(files['canonical/inputs/source-inventory.json'])['rows']}
    choices = [{'occurrenceId': row['occurrenceId'], 'selector': row['selector']}
        for row in full['occurrences'] if row['family'] == 'WORK'
        and old[row['originalOccurrenceId']]['semantic'] is not None
        and old[row['originalOccurrenceId']]['semantic']['form'] == 'full']
    return dumps({'version': '2', 'sourceManifestHash': original.manifest_hash, 'adapters': {
        'linked-art': {'version': '1', 'kind': 'native_linked_art',
            'sourceManifestHash': original.manifest_hash, 'selected': choices},
        'premis': decoded(premis_plan(original)), 'iiif': iiif_plan, 'lido': decoded(lido_raw)}})


@lru_cache(maxsize=1)
def complete():
    original, lido_plan = supplied()
    raw = plans_for(original, lido_plan, {'version': '2', 'kind': 'native_iiif_painting',
        'sourceManifestHash': original.manifest_hash, 'selected': []})
    with patch('socket.socket', side_effect=AssertionError('network forbidden')):
        result = package.compose(dict(original.files), original.manifest_hash,
            raw, keccak256(raw), disclosure='public')
    return original, raw, result


@lru_cache(maxsize=1)
def painting_complete():
    from .native_media_dossier_fixture_v1 import supplied as media_supplied
    from .test_native_iiif_v2 import plan_for as painting_plan
    original, lido_plan = media_supplied()
    raw = plans_for(original, lido_plan,
        decoded(painting_plan(dict(original.files), original.manifest_hash)))
    with patch('socket.socket', side_effect=AssertionError('network forbidden')):
        result = package.compose(dict(original.files), original.manifest_hash,
            raw, keccak256(raw), disclosure='public')
    return original, raw, result


def rehash(files):
    manifest = loads(files['manifest.json'], maximum=MAX_MANIFEST, canonical=True)
    manifest['files'] = [_ref(path, raw) for path, raw in sorted(files.items()) if path != 'manifest.json']
    files['manifest.json'] = dumps(manifest)
    return keccak256(files['manifest.json'])


class NativeMultiformatPackageV2Tests(unittest.TestCase):
    def test_coherent_original_view_painting_and_rights_share_retained_v4(self):
        original, _, result = painting_complete(); files = dict(result.files)
        self.assertEqual({path[7:]: raw for path, raw in files.items()
            if path.startswith('source/')}, dict(original.files))
        self.assertEqual(result.report['adapters']['iiif']['paintingBodyCount'], '1')
        self.assertGreater(int(result.report['adapters']['premis']['rightsStatementCount']), 0)
        index = decoded(files['iiif/index.json'])['rows']; self.assertEqual(len(index), 1)
        manifest = decoded(files[index[0]['manifestPath']])
        annotation = manifest['items'][0]['items'][0]['items'][0]
        self.assertEqual(annotation['motivation'], 'painting')
        self.assertEqual(annotation['body']['format'], 'image/png')
        self.assertEqual(index[0]['paintingAuthority']['mode'], 'unsigned_operator_designation')
        self.assertIsNone(index[0]['intrinsicDimensions'])
        native = decoded(files[ledger.INVENTORY_PATH])
        self.assertEqual(files[ledger.INVENTORY_PATH],
            inventory._extract(dict(original.files), original.manifest_hash).inventory)
        self.assertEqual(len(decoded(files[ledger.LEDGER_PATH])['rows']), len(native['fields']))
        field_count = sum(len(decoded(files[name + '/supplemental-source-inventory.json'])['fields'])
            for name in ('premis', 'iiif'))
        self.assertEqual(len(decoded(files[ledger.SUPPLEMENTAL_LEDGER_PATH])['rows']), field_count)
        self.assertEqual(original.report['packetRequirementCount'], '19')
        self.assertEqual(original.report['dossierRequirementCount'], '49')

    def test_full_painting_generic_portable_reopen_uses_only_retained_dependencies(self):
        _, _, result = painting_complete(); original_read = Path.read_bytes
        def retained_only(path):
            if path.resolve().is_relative_to(package.MODEL_ROOT.resolve()):
                raise AssertionError('repository dependency fallback')
            return original_read(path)
        with TemporaryDirectory() as temporary:
            target = Path(temporary) / 'package'; write_tree(dict(result.files), target)
            with patch.object(Path, 'read_bytes', retained_only), \
                    patch('socket.socket', side_effect=AssertionError('network')):
                reopened = verify_package(target, result.manifest_hash)
        self.assertEqual(dict(reopened.files), dict(result.files))

    def test_original_rights_and_publications_export_with_explicit_absent_view(self):
        original, _, result = complete(); files = dict(result.files)
        self.assertEqual({path[7:]: raw for path, raw in files.items() if path.startswith('source/')}, dict(original.files))
        self.assertGreater(int(result.report['adapters']['premis']['rightsStatementCount']), 0)
        self.assertGreater(int(result.report['adapters']['premis']['eventCount']), 0)
        self.assertEqual(result.report['adapters']['iiif']['status'], 'source_unavailable')
        self.assertEqual(result.report['adapters']['iiif']['paintingBodyCount'], '0')
        xml = etree.fromstring(files['premis/objects.xml']); ns = {'p': 'http://www.loc.gov/premis/v3'}
        self.assertFalse(xml.xpath('//p:rightsGranted | //p:termOfGrant', namespaces=ns))
        self.assertTrue(xml.xpath('//p:rightsStatement', namespaces=ns))
        self.assertEqual(original.report['packetRequirementCount'], '19')
        self.assertEqual(original.report['dossierRequirementCount'], '49')

    def test_native_inventory_is_byte_identical_and_supplemental_originals_separate(self):
        original, _, result = complete(); files = dict(result.files)
        expected = inventory._extract(dict(original.files), original.manifest_hash).inventory
        self.assertEqual(files[ledger.INVENTORY_PATH], expected)
        native = decoded(expected)
        self.assertEqual(len(decoded(files[ledger.LEDGER_PATH])['rows']), len(native['fields']))
        self.assertEqual(decoded(files[ledger.FAMILIES_PATH])['denominators'], native['denominators'])
        supplemental = decoded(files['premis/supplemental-source-inventory.json'])
        self.assertTrue(supplemental['fields'])
        self.assertEqual(len(decoded(files[ledger.SUPPLEMENTAL_LEDGER_PATH])['rows']), len(supplemental['fields']))
        counts = decoded(files[ledger.SUPPLEMENTAL_FAMILIES_PATH])
        self.assertFalse(counts['originalNativeDenominatorExpanded'])
        self.assertTrue(any(row['mappedFields']['premis'] > 0 for row in counts['families']))

    def test_generic_reopen_uses_retained_dependencies_and_no_network(self):
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

    def test_rehashed_supplemental_inventory_or_coverage_cannot_hide_original_fields(self):
        _, _, result = complete()
        for path, key in [('premis/supplemental-source-inventory.json', 'fields'),
                (ledger.SUPPLEMENTAL_LEDGER_PATH, 'rows')]:
            files = dict(result.files); value = decoded(files[path]); self.assertTrue(value[key])
            value[key] = []; files[path] = dumps(value)
            with self.subTest(path=path), self.assertRaisesRegex(MuseumError, 'full reconstruction'):
                package.verify(files, rehash(files))

    def test_external_pin_and_v2_closed_same_source_plan_are_required(self):
        original, raw, result = complete()
        with self.assertRaisesRegex(MuseumError, 'external manifest'):
            package.verify(dict(result.files), '0x' + '12' * 32)
        for change in ('version', 'extra', 'foreign_source', 'missing_adapter'):
            plan = decoded(raw)
            if change == 'version': plan['version'] = '1'
            elif change == 'extra': plan['unexpected'] = []
            elif change == 'foreign_source': plan['adapters']['iiif']['sourceManifestHash'] = '0x' + '12' * 32
            else: del plan['adapters']['premis']
            mutated = dumps(plan)
            with self.subTest(change=change), self.assertRaises(MuseumError):
                package._plan(mutated, keccak256(mutated), original.manifest_hash)

    def test_frozen_previous_profile_commitments_are_unchanged(self):
        from . import native_multiformat_package_v1 as old
        self.assertEqual(old.PROFILE_HASH, '0xaf999fb7c34b162e1b253a68b3f356c340d2458e2857665e7ea197c86cde663d')
        self.assertEqual(old.premis.PROFILE_HASH, '0x6aece4ddc82482675342603feedc8de03107e95499914a901f7339fb4214e9bd')
        self.assertEqual(old.iiif.PROFILE_HASH, '0xc870fc91757bf72845ad12173e036060ee5290547faf4c7182a195543ebfd9f9')

    def test_public_disclosure_and_output_overlap_precede_source_reads(self):
        class Trap:
            def __iter__(self): raise AssertionError('restricted original read')
        with self.assertRaisesRegex(MuseumError, 'public disclosure'):
            package.compose(Trap(), 'bad', b'bad', 'bad', disclosure='restricted')
        with TemporaryDirectory() as temporary:
            root = Path(temporary); source = root / 'source'; source.mkdir()
            plan = root / 'plan.json'; plan.write_bytes(b'{}')
            with patch.object(package, 'read_tree', side_effect=AssertionError('source read')):
                with self.assertRaises(SystemExit) as error:
                    package.main(['assemble', '--source', str(source), '--source-hash', 'bad',
                        '--plan', str(plan), '--plan-hash', 'bad', '--disclosure', 'public',
                        '--output', str(source / 'overlap')])
            self.assertEqual(error.exception.code, 2)


if __name__ == '__main__':
    unittest.main()
