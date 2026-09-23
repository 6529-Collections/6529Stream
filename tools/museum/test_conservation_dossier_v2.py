"""Combined conservation replay, material evidence and offline model closure."""
from contextlib import redirect_stderr, redirect_stdout
import io
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import conservation_archive_v1 as archive
from . import conservation_dossier_v1 as original
from . import conservation_dossier_v2 as dossier
from . import conservation_semantic_graph_v1 as semantic
from . import object_dossier as package
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .test_conservation_archive_v1 import complete_case
from .test_conservation_dossier_v1 import captured, fixtures


def repin(files):
    manifest = loads(files['manifest.json'], maximum=2 * 1024 * 1024, canonical=True)
    manifest['files'] = [package._ref(path, raw) for path, raw in sorted(files.items()) if path != 'manifest.json']
    files['manifest.json'] = dumps(manifest)
    return keccak256(files['manifest.json'])


class ConservationDossierV2Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source, cls.materials_raw, cls.materials = complete_case('external')
        cls.materials_hash = keccak256(cls.materials_raw)
        cls.result = dossier.build(dict(cls.source.files), cls.source.manifest_hash,
            cls.materials_raw, cls.materials_hash, cls.materials, disclosure='public')
        cls.files = dict(cls.result.files)

    def test_complete_family_joins_preserve_all_originals_and_resolve_component_paths(self):
        report = dossier.require_complete(self.result)
        self.assertEqual(report['status'], 'complete_with_stream_extensions')
        self.assertTrue(report['archiveComplete'])
        self.assertTrue(report['semanticComplete'])
        self.assertFalse(report['claims']['completeCanonicalDossier'])
        for path, raw in self.source.files:
            self.assertEqual(self.files['source/' + path], raw)
        for path, raw in self.materials.items():
            self.assertEqual(self.files['materials/data/' + path], raw)
        locations = loads(self.files['source-locations.json'], maximum=65536, canonical=True)
        self.assertEqual(locations['originalDossierRoot'], 'source/')
        for item in locations['inputs']:
            self.assertEqual(item['packagePath'], 'source/' + item['componentPath'])
            self.assertEqual(item['hash'], keccak256(self.files[item['packagePath']]))
        self.assertFalse(locations['referenceURIsRewritten'])

    def test_offline_reconstruction_uses_retained_model_closure(self):
        with patch('socket.socket', side_effect=AssertionError('conservation V2 attempted network')):
            rebuilt = dossier.verify(self.files, self.result.manifest_hash)
        self.assertEqual(rebuilt.files, self.result.files)
        self.assertIn('dependencies/linked-art-v2/validation-policy.json', self.files)

    def test_coherently_rehashed_derived_semantics_archive_and_path_map_are_rejected(self):
        for path in (semantic.SIDECAR_PATH, 'archive/correspondence.json', 'source-locations.json'):
            with self.subTest(path=path):
                altered = dict(self.files)
                value = loads(altered[path], maximum=64 * 1024 * 1024, canonical=True)
                if type(value) is list:
                    value.append({'invented': 'claim'})
                else:
                    value['invented'] = 'claim'
                altered[path] = dumps(value)
                with self.assertRaises(MuseumError):
                    dossier.verify(altered, repin(altered))

    def test_rehashed_original_dossier_projection_cannot_replace_source_replay(self):
        altered = dict(self.files)
        source = {path.removeprefix('source/'): raw for path, raw in altered.items() if path.startswith('source/')}
        value = loads(source['conservation/dossier.json'], maximum=64 * 1024 * 1024, canonical=True)
        value['currentAssociation'] = ['invented original association']
        source['conservation/dossier.json'] = dumps(value)
        source_hash = repin(source)
        altered.update({'source/' + path: raw for path, raw in source.items()})
        manifest = loads(altered['manifest.json'], maximum=2 * 1024 * 1024, canonical=True)
        manifest['sourceManifestHash'] = source_hash
        altered['manifest.json'] = dumps(manifest)
        with self.assertRaises(MuseumError):
            dossier.verify(altered, repin(altered))

    def test_changed_embedded_model_policy_cannot_become_a_new_validation_authority(self):
        altered = dict(self.files)
        path = 'dependencies/linked-art-v2/validation-policy.json'
        policy = loads(altered[path], maximum=2 * 1024 * 1024, canonical=True)
        policy['invented'] = 'weakened interpretation'
        altered[path] = dumps(policy)
        with self.assertRaises(MuseumError):
            dossier.verify(altered, repin(altered))

    def test_missing_materials_and_empty_source_never_pass_completion(self):
        native, _ = captured(fixtures()['empty'])
        empty = original.build(dict(native.files), native.manifest_hash, disclosure='public')
        for source in (self.source, empty):
            with self.subTest(records=source.report['recordCount']):
                envelope = archive.template(dict(source.files))
                result = dossier.build(dict(source.files), source.manifest_hash, envelope,
                    keccak256(envelope), {}, disclosure='public')
                self.assertEqual(result.report['status'], 'incomplete')
                with self.assertRaises(MuseumError):
                    dossier.require_complete(result)

    def test_disclosure_precedes_cli_reads_and_external_pins_are_required(self):
        with patch.object(dossier, 'read_tree', side_effect=AssertionError('input read before disclosure')):
            with redirect_stderr(io.StringIO()):
                self.assertEqual(dossier.main(['build', 'missing-source', 'missing-materials', 'unused-output',
                    '--manifest-hash', self.source.manifest_hash, '--materials-hash', self.materials_hash,
                    '--disclosure', 'restricted']), 1)
                self.assertEqual(dossier.main(['material-template', 'missing-source', 'unused-output',
                    '--manifest-hash', self.source.manifest_hash, '--disclosure', 'restricted']), 1)
        with self.assertRaises(MuseumError):
            dossier.build(dict(self.source.files), self.source.manifest_hash, self.materials_raw,
                '0x' + 'ff' * 32, self.materials, disclosure='public')
        with self.assertRaises(MuseumError):
            dossier.verify(self.files, '0x' + 'ff' * 32)

    def test_cli_build_verify_complete_and_no_overwrite(self):
        with TemporaryDirectory(prefix='stream-conservation-v2-cli-') as temporary:
            root = Path(temporary)
            source, materials, destination = root / 'source', root / 'materials', root / 'output'
            write_tree(dict(self.source.files), source)
            write_tree({'input.json': self.materials_raw, **{'data/' + p: raw for p, raw in self.materials.items()}}, materials)
            args = ['build', str(source), str(materials), str(destination), '--manifest-hash', self.source.manifest_hash,
                '--materials-hash', self.materials_hash, '--disclosure', 'public', '--require-complete']
            stream = io.StringIO()
            with redirect_stdout(stream):
                self.assertEqual(dossier.main(args), 0)
            message = json.loads(stream.getvalue())
            self.assertEqual(message['manifestHash'], self.result.manifest_hash)
            with patch('socket.socket', side_effect=AssertionError('CLI attempted network')):
                for command in ('verify', 'complete'):
                    with redirect_stdout(io.StringIO()):
                        self.assertEqual(dossier.main([command, str(destination), '--manifest-hash', self.result.manifest_hash]), 0)
            before = read_tree(destination)
            with redirect_stderr(io.StringIO()):
                self.assertEqual(dossier.main(args), 1)
            self.assertEqual(read_tree(destination), before)

    def test_cli_template_diagnosis_cannot_create_a_complete_package(self):
        with TemporaryDirectory(prefix='stream-conservation-v2-missing-') as temporary:
            root = Path(temporary)
            source, materials, destination = root / 'source', root / 'materials', root / 'output'
            write_tree(dict(self.source.files), source)
            stdout = io.StringIO()
            with redirect_stdout(stdout):
                self.assertEqual(dossier.main(['material-template', str(source), str(materials),
                    '--manifest-hash', self.source.manifest_hash, '--disclosure', 'public']), 0)
            envelope_hash = json.loads(stdout.getvalue())['materialsHash']
            with redirect_stderr(io.StringIO()):
                self.assertEqual(dossier.main(['build', str(source), str(materials), str(destination),
                    '--manifest-hash', self.source.manifest_hash, '--materials-hash', envelope_hash,
                    '--disclosure', 'public', '--require-complete']), 1)
                self.assertEqual(dossier.main(['material-template', str(source), str(source / 'nested'),
                    '--manifest-hash', self.source.manifest_hash, '--disclosure', 'public']), 1)
            self.assertFalse(destination.exists())
            self.assertEqual(read_tree(source), dict(self.source.files))


if __name__ == '__main__':
    unittest.main()
