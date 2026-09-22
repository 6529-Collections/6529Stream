"""Original-field and offline reconstruction checks for native WORK LIDO."""
from functools import lru_cache
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import native_work_lido_package_v1 as package
from .bagit import MAX_BYTES, MAX_MANIFEST, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .object_dossier import _ref
from .package_v2 import verify_package
from .test_native_work_lido_v1 import supplied


@lru_cache(maxsize=1)
def complete():
    original, plan = supplied()
    with patch('socket.socket', side_effect=AssertionError('network forbidden')):
        result = package.compose(dict(original.files), original.manifest_hash,
            plan, keccak256(plan), disclosure='public')
    return original, plan, result


def decoded(raw):
    return loads(raw, maximum=MAX_BYTES, canonical=True)


def projected(files):
    return {p: raw for p, raw in files.items() if p.startswith('lido/')}


class NativeWorkLidoPackageTests(unittest.TestCase):
    def test_complete_original_inventory_and_actual_native_mapping_are_distinct(self):
        original, _, result = complete(); files = dict(result.files)
        self.assertEqual({p[7:]: raw for p, raw in files.items() if p.startswith('source/')},
            dict(original.files))
        inventory = decoded(files[package.INVENTORY_PATH])
        ledger = decoded(files[package.LEDGER_PATH])
        self.assertEqual(len(ledger['rows']), len(inventory['fields']))
        occurrences = {r['occurrenceId']: r for r in inventory['occurrences']}
        count, title = 0, False
        for index, row in enumerate(ledger['rows']):
            self.assertEqual(row['sourceFieldPointer'], '/fields/' + str(index))
            field = inventory['fields'][index]
            if row['lido']['disposition'] == 'mapped':
                count += 1
                self.assertEqual(occurrences[field['occurrenceId']]['family'], 'WORK')
                self.assertIn(field['domain'], ('payload', 'catalog'))
                self.assertTrue(row['lido']['evidence'])
                title |= field['pointer'] == '/title'
            elif field['presence'] == 'absent':
                self.assertEqual(row['lido']['disposition'], 'not_applicable')
            self.assertEqual(set(row['otherFormats'].values()), {'not_evaluated_by_this_profile'})
        self.assertTrue(title)
        self.assertEqual(str(count), result.report['mappedNativeFieldCount'])
        self.assertFalse(result.report['claims']['allNativeFormatsMapped'])
        self.assertFalse(result.report['claims']['crossFormatAgreementProven'])
        self.assertEqual(original.report['packetRequirementCount'], '19')
        self.assertEqual(original.report['dossierRequirementCount'], '49')

    def test_generic_reopen_uses_only_retained_dependencies_offline(self):
        _, _, result = complete(); files = dict(result.files)
        original_read = Path.read_bytes
        def retained_only(path):
            if path.resolve().is_relative_to(package.MODEL_ROOT.resolve()):
                raise AssertionError('repository dependency fallback')
            return original_read(path)
        with TemporaryDirectory() as temporary:
            target = Path(temporary) / 'package'; write_tree(files, target)
            with patch.object(Path, 'read_bytes', retained_only), patch('socket.socket',
                    side_effect=AssertionError('network forbidden')):
                rebuilt = verify_package(target, result.manifest_hash)
            self.assertEqual(dict(rebuilt.files), files)

    def test_operator_and_generated_identity_evidence_do_not_promote_original_fields(self):
        _, _, result = complete(); files = dict(result.files); mapped = projected(files)
        proof = decoded(mapped['lido/provenance.json'])
        proof['rows'] = [r for r in proof['rows'] if all(s['domain'] in
            ('operator_context', 'original_identity') for s in r['sources'])]
        self.assertTrue(proof['rows'])
        mapped['lido/provenance.json'] = dumps(proof)
        ledger = decoded(package._ledger(files[package.INVENTORY_PATH], mapped))
        self.assertEqual(ledger['mappedNativeFieldCount'], '0')
        self.assertFalse(any(r['lido']['disposition'] == 'mapped' for r in ledger['rows']))

    def test_actual_xml_value_must_match_exact_provenance(self):
        _, _, result = complete(); files = dict(result.files); mapped = projected(files)
        proof = decoded(mapped['lido/provenance.json'])
        proof['rows'][0]['targetValue'] = 'invented XML value'
        mapped['lido/provenance.json'] = dumps(proof)
        with self.assertRaisesRegex(MuseumError, 'actual XML value'):
            package._ledger(files[package.INVENTORY_PATH], mapped)

    def test_native_reference_and_exact_value_cannot_be_reassigned(self):
        _, _, result = complete(); files = dict(result.files)
        for change in ('reference', 'value', 'occurrence'):
            mapped = projected(files); proof = decoded(mapped['lido/provenance.json'])
            row = next(r for r in proof['rows'] if any(s['domain'] == 'payload' for s in r['sources']))
            source = next(s for s in row['sources'] if s['domain'] == 'payload')
            if change == 'reference': source['sourceReference']['jsonPointer'] = '/another/record'
            elif change == 'value': source['exactHex'] = '0x00'
            else: row['occurrenceId'] = '0x' + '12' * 32
            mapped['lido/provenance.json'] = dumps(proof)
            with self.subTest(change=change), self.assertRaises(MuseumError):
                package._ledger(files[package.INVENTORY_PATH], mapped)

    def test_rehashing_deleted_ledger_fields_cannot_bypass_full_reconstruction(self):
        _, _, result = complete(); files = dict(result.files)
        ledger = decoded(files[package.LEDGER_PATH]); ledger['rows'].pop()
        files[package.LEDGER_PATH] = dumps(ledger)
        manifest = loads(files['manifest.json'], maximum=MAX_MANIFEST, canonical=True)
        manifest['files'] = [_ref(p, raw) for p, raw in sorted(files.items()) if p != 'manifest.json']
        files['manifest.json'] = dumps(manifest)
        with self.assertRaisesRegex(MuseumError, 'full reconstruction'):
            package.verify(files, keccak256(files['manifest.json']))

    def test_external_pin_is_required_before_reconstruction(self):
        _, _, result = complete()
        with self.assertRaisesRegex(MuseumError, 'external manifest'):
            package.verify(dict(result.files), '0x' + '12' * 32)

    def test_public_guard_and_output_overlap_precede_source_reads(self):
        class Trap:
            def __iter__(self): raise AssertionError('private source inspected')
        with self.assertRaisesRegex(MuseumError, 'public disclosure'):
            package.compose(Trap(), 'bad', b'bad', 'bad', disclosure='restricted')
        with TemporaryDirectory() as temporary:
            root = Path(temporary); source = root / 'source'; source.mkdir()
            plan = root / 'plan.json'; plan.write_bytes(b'{}')
            args = ['assemble', '--source', str(source), '--source-hash', 'bad',
                '--plan', str(plan), '--plan-hash', 'bad', '--disclosure', 'public',
                '--output', str(source / 'nested')]
            with patch.object(package, 'read_tree', side_effect=AssertionError('source read')):
                with self.assertRaises(SystemExit) as raised: package.main(args)
            self.assertEqual(raised.exception.code, 2)


if __name__ == '__main__':
    unittest.main()
