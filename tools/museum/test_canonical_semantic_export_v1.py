"""Native source replay, exact retention, semantic commitments and offline checks."""
from contextlib import redirect_stderr, redirect_stdout
import io
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import acquisition_canonical_v10 as acquisition
from . import canonical_object_dossier_v3 as dossier
from . import canonical_semantic_export_v1 as export
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .test_acquisition_canonical_v10 import composed_inputs


def repin(files):
    envelope = loads(files['manifest.json'], maximum=export.MAX_MANIFEST, canonical=True)
    envelope['files'] = [export.package._ref(path, raw) for path, raw in sorted(files.items())
        if path != 'manifest.json']
    files['manifest.json'] = dumps(envelope)
    return keccak256(files['manifest.json'])


class CanonicalSemanticExportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        prior, sources, pin = composed_inputs()
        packet = acquisition.compose(prior.files, prior.manifest_hash, sources, pin, disclosure='public')
        cls.dossier = dossier.compose(packet.files, packet.manifest_hash, disclosure='public')
        cls.originals = dict(cls.dossier.files)
        cls.selection = export.prepare_selection(cls.originals, cls.dossier.manifest_hash, disclosure='public')
        cls.result = export.build(cls.originals, cls.dossier.manifest_hash, cls.selection,
            keccak256(cls.selection), disclosure='public')
        cls.files = dict(cls.result.files)

    def test_original_dossier_and_49_requirements_survive_new_projection(self):
        for path, raw in self.originals.items():
            self.assertEqual(self.files['input/' + path], raw)
        self.assertEqual(self.result.report['dossierRequirements'],
            loads(self.originals['dossier/requirements.json'], maximum=export.MAX_BYTES))
        self.assertEqual(len(self.result.report['dossierRequirements']['results']), 49)
        self.assertFalse(self.result.report['claims']['currentAuthorityInferred'])
        self.assertFalse(self.result.report['claims']['completeCanonicalDossier'])
        self.assertEqual(self.files[export.SELECTION_PATH], self.selection)
        self.assertTrue(any(p.startswith('semantic/expanded/') for p in self.files))
        locations = loads(self.files['semantic/source-locations.json'], maximum=export.MAX_BYTES)
        self.assertEqual(locations['originalSourcePathBase'], 'input/')
        for row in locations['sourceDocuments']:
            self.assertEqual(row, export.package._ref(row['path'], self.files[row['path']]))
        self.assertTrue(any(p.startswith('definitions/native-source/') for p in self.files))

    def test_retained_dependency_replay_needs_neither_network_nor_repository_models(self):
        real_open = io.open
        model_root = export.MODEL_ROOT.resolve()

        def guarded(file, *args, **kwargs):
            if isinstance(file, (str, bytes, Path)):
                path = Path(file).resolve()
                if path.is_relative_to(model_root):
                    raise AssertionError('repository model fallback attempted')
            return real_open(file, *args, **kwargs)

        with patch('socket.socket', side_effect=AssertionError('network used')), patch('io.open', guarded):
            with self.assertRaisesRegex(AssertionError, 'repository model'):
                (model_root / 'linked-art-v2/validation-policy.json').read_bytes()
            result = export.verify(self.files, self.result.manifest_hash)
        self.assertEqual(result.files, self.result.files)

    def test_hash_graph_only_points_to_children_or_earlier_source(self):
        semantic = loads(self.files[export.MANIFEST_PATH], maximum=export.MAX_MANIFEST)
        self.assertEqual(semantic['sourceDossier']['keccak256'], self.dossier.manifest_hash)
        names = [r['path'] for r in semantic['children']]
        self.assertEqual(len(names), len(set(names)))
        self.assertNotIn('manifest.json', names)
        self.assertNotIn(export.MANIFEST_PATH, names)
        for row in semantic['children']:
            self.assertEqual(row, export.package._ref(row['path'], self.files[row['path']]))
        envelope = loads(self.files['manifest.json'], maximum=export.MAX_MANIFEST)
        self.assertEqual(envelope['exportManifest'],
            export.package._ref(export.MANIFEST_PATH, self.files[export.MANIFEST_PATH]))

    def test_rehashed_inventory_report_and_extra_file_do_not_override_reconstruction(self):
        for path in (export.INVENTORY_PATH, 'semantic/report.json', 'undeclared.json'):
            files = dict(self.files)
            value = loads(files[path], maximum=export.MAX_BYTES) if path in files else {}
            value['inventedAuthority'] = True
            files[path] = dumps(value)
            with self.subTest(path=path), self.assertRaisesRegex(MuseumError, 'reconstruction differs'):
                export.verify(files, repin(files))

    def test_rehashed_model_policy_cannot_replace_frozen_interpretation(self):
        files = dict(self.files)
        path = 'dependencies/linked-art-v2/validation-policy.json'
        value = loads(files[path], maximum=export.MAX_MANIFEST)
        value['processor'] = 'unreviewed-processor'
        files[path] = dumps(value)
        with self.assertRaisesRegex(MuseumError, 'policy hash'):
            export.verify(files, repin(files))

    def test_public_disclosure_and_external_selection_pin_are_checked_first(self):
        with patch.object(export.sources, 'admit', side_effect=AssertionError('source read before guard')):
            with self.assertRaisesRegex(MuseumError, 'public disclosure'):
                export.build({}, self.dossier.manifest_hash, self.selection, keccak256(self.selection),
                    disclosure='restricted')
            with self.assertRaisesRegex(MuseumError, 'selection commitment'):
                export.build({}, self.dossier.manifest_hash, self.selection, '0x' + '12' * 32,
                    disclosure='public')

    def test_cli_selection_build_verify_and_failure_are_atomic(self):
        with TemporaryDirectory(prefix='stream-canonical-semantic-cli-') as temporary:
            root = Path(temporary)
            source = root / 'source'
            write_tree(self.originals, source)
            policy, output, refused = root / 'policy', root / 'export', root / 'refused'
            capture = io.StringIO()
            with redirect_stdout(capture):
                export.main(['prepare-selection', '--dossier', str(source), '--dossier-hash',
                    self.dossier.manifest_hash, '--disclosure', 'public', '--output', str(policy)])
            self.assertEqual((policy / 'selection.json').read_bytes(), self.selection)
            with redirect_stdout(io.StringIO()):
                export.main(['build', '--dossier', str(source), '--dossier-hash', self.dossier.manifest_hash,
                    '--selection', str(policy / 'selection.json'), '--selection-hash', keccak256(self.selection),
                    '--disclosure', 'public', '--output', str(output)])
                export.main(['verify', str(output), '--manifest-hash', self.result.manifest_hash])
            self.assertEqual(read_tree(output), self.files)
            with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as caught:
                export.main(['build', '--dossier', str(source), '--dossier-hash', self.dossier.manifest_hash,
                    '--selection', str(policy / 'selection.json'), '--selection-hash', '0x' + '12' * 32,
                    '--disclosure', 'public', '--output', str(refused)])
            self.assertEqual(caught.exception.code, 2)
            self.assertFalse(refused.exists())
            self.assertEqual(read_tree(source), self.originals)


if __name__ == '__main__':
    unittest.main()
