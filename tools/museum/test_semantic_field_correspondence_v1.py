"""Concrete source admission and deterministic correspondence package reopening."""
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import semantic_field_correspondence_v1 as correspondence
from . import package_v2
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .object_dossier import _ref
from .test_package_v2 import ROOT, inputs


def repin(files):
    manifest = loads(files['manifest.json'], maximum=correspondence.MAX_MANIFEST, canonical=True)
    manifest['files'] = [_ref(path, raw) for path, raw in sorted(files.items())
        if path != 'manifest.json']
    files['manifest.json'] = dumps(manifest)
    return keccak256(files['manifest.json'])


class SemanticFieldCorrespondenceV1Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        args, pins = inputs()
        child = package_v2.build_fixture_package(*args, root=ROOT, **pins)
        cls.originals = dict(child.files, **{'manifest.json': child.manifest})
        cls.original_hash = child.manifest_hash
        cls.result = correspondence.compose(cls.originals, child.manifest_hash,
            source_kind='account_formats_v2', disclosure='public')
        cls.files = dict(cls.result.files)

    def test_complete_original_retention_and_socket_offline_rebuild(self):
        for path, raw in self.originals.items():
            self.assertEqual(self.files['source/' + path], raw)
        for path in (correspondence.INVENTORY_PATH, correspondence.LEDGER_PATH,
                correspondence.IDENTITIES_PATH, correspondence.COMPARISONS_PATH):
            self.assertIn(path, self.files)
        with patch('socket.socket', side_effect=AssertionError('network used')):
            rebuilt = correspondence.verify(self.files, self.result.manifest_hash)
        self.assertEqual(rebuilt.files, self.result.files)
        self.assertFalse(self.result.report['claims']['differentSourcePackagesJoined'])
        self.assertFalse(self.result.report['claims']['completeSemanticMappingProven'])
        self.assertFalse(self.result.report['claims']['institutionalAcceptance'])

    def test_native_route_retains_assessments_and_never_claims_format_agreement(self):
        from . import canonical_object_dossier_v4 as dossier
        from .canonical_object_dossier_fixture_v4 import complete_case_v4
        case = complete_case_v4()
        files, digest, options = case.inputs()
        original = dossier.compose(files, digest, **options)
        built = correspondence.compose(dict(original.files), original.manifest_hash,
            source_kind='canonical_v4', disclosure='public')
        retained = dict(built.files)
        inventory = loads(retained[correspondence.INVENTORY_PATH], maximum=correspondence.MAX_BYTES)
        ledger = loads(retained[correspondence.LEDGER_PATH], maximum=correspondence.MAX_BYTES)
        self.assertTrue(inventory['fields'])
        self.assertEqual(len(ledger['fields']), len(inventory['fields']))
        self.assertEqual(ledger['status'], 'unsupported_native_four_format_adapter')
        self.assertTrue(all(row['disposition'] in ('retained_stream_only', 'not_applicable')
            for row in ledger['fields']))
        self.assertEqual(loads(retained[correspondence.COMPARISONS_PATH],
            maximum=correspondence.MAX_BYTES)['comparisons'], [])
        for occurrence in inventory['occurrences']:
            for domain in occurrence['domains']:
                source = domain['source']
                self.assertEqual(keccak256(retained[source['path']]), source['hash'])
        for path in ('canonical/input/report.json', 'canonical/input/dossier/requirements.json'):
            self.assertEqual(retained['source/' + path], dict(original.files)[path])
        self.assertEqual(correspondence.verify(retained, built.manifest_hash).files, built.files)

    def test_rehashed_derived_ledger_or_identity_cannot_change_correspondence(self):
        for path in (correspondence.INVENTORY_PATH, correspondence.LEDGER_PATH,
                correspondence.IDENTITIES_PATH, correspondence.COMPARISONS_PATH):
            with self.subTest(path=path):
                changed = dict(self.files)
                changed[path] = dumps({'invented': 'different source or dropped denominator'})
                digest = repin(changed)
                with self.assertRaisesRegex(MuseumError, 'full reconstruction differs'):
                    correspondence.verify(changed, digest)

    def test_removed_or_extra_file_rejects_even_with_new_outer_hash(self):
        for mutation in ('remove', 'extra'):
            with self.subTest(mutation=mutation):
                changed = dict(self.files)
                if mutation == 'remove':
                    del changed[correspondence.ADAPTER_REPORT_PATH]
                else:
                    changed['conformance/extra.json'] = dumps({'unadmitted': True})
                digest = repin(changed)
                with self.assertRaisesRegex(MuseumError, 'full reconstruction differs'):
                    correspondence.verify(changed, digest)

    def test_original_target_tamper_cannot_hide_in_rehashed_outer_package(self):
        changed = dict(self.files)
        changed['source/lido/lido.xml'] += b' '
        with self.assertRaises(MuseumError):
            correspondence.verify(changed, repin(changed))

    def test_wrong_external_pin_or_route_and_false_claim_reject(self):
        with self.assertRaisesRegex(MuseumError, 'external manifest differs'):
            correspondence.verify(self.files, '0x' + '00' * 32)
        with self.assertRaises(MuseumError):
            correspondence.compose(self.originals, self.original_hash,
                source_kind='canonical_v4', disclosure='public')
        changed = dict(self.files)
        manifest = loads(changed['manifest.json'], maximum=correspondence.MAX_MANIFEST)
        manifest['claims']['institutionalAcceptance'] = True
        changed['manifest.json'] = dumps(manifest)
        with self.assertRaisesRegex(MuseumError, 'closed manifest differs'):
            correspondence.verify(changed, keccak256(changed['manifest.json']))

    def test_public_preflight_precedes_input_inspection_and_cli_reads(self):
        class Unreadable:
            def __iter__(self):
                raise AssertionError('source inspected')
        with self.assertRaisesRegex(MuseumError, 'public disclosure'):
            correspondence.compose(Unreadable(), None, source_kind='account_formats_v2',
                disclosure='restricted')
        with patch.object(correspondence, 'read_tree', side_effect=AssertionError('source read')), \
                redirect_stderr(StringIO()), self.assertRaises(SystemExit):
            correspondence.main(['assemble', '--source', 'missing', '--source-hash', self.original_hash,
                '--source-kind', 'account_formats_v2', '--disclosure', 'restricted', '--output', 'missing-out'])

    def test_cli_new_destination_and_generic_offline_dispatch(self):
        with TemporaryDirectory(prefix='stream-field-correspondence-') as temporary:
            source, target = Path(temporary) / 'source', Path(temporary) / 'output'
            write_tree(self.originals, source)
            output = StringIO()
            with redirect_stdout(output), patch('socket.socket', side_effect=AssertionError('network used')):
                correspondence.main(['assemble', '--source', str(source), '--source-hash', self.original_hash,
                    '--source-kind', 'account_formats_v2', '--disclosure', 'public', '--output', str(target)])
            digest = loads(output.getvalue().strip().encode('utf-8'))['manifestHash']
            self.assertEqual(digest, self.result.manifest_hash)
            self.assertEqual(read_tree(target), self.files)
            checked = package_v2.verify_package(target, digest)
            self.assertEqual(checked.files, self.result.files)
            with redirect_stderr(StringIO()), self.assertRaises(SystemExit):
                correspondence.main(['assemble', '--source', str(source), '--source-hash', self.original_hash,
                    '--source-kind', 'account_formats_v2', '--disclosure', 'public', '--output', str(target)])


if __name__ == '__main__':
    unittest.main()
