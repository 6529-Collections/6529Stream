"""Concrete source replay and retention at the script package boundary."""
from contextlib import redirect_stdout
from copy import deepcopy
import io
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import TestCase, mock

from . import collection_script_package_v1 as package
from . import collection_script_source_v1 as native
from . import collection_script_wire_v1 as wire
from . import script_dependency_rpc_v1 as rpc
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .object_dossier import _ref
from .test_collection_script_source_v1 import CollectionScriptFixture


def build(fixture):
    snapshot, transcript = fixture.capture()
    result = package.assemble(fixture.anchor_raw, keccak256(fixture.anchor_raw),
        transcript, keccak256(transcript), fixture.runtime_bridge_raw,
        keccak256(fixture.runtime_bridge_raw), provenance='synthetic_fixture', disclosure='public')
    return result, snapshot, transcript


def repin(files, **inputs):
    manifest = loads(files['manifest.json'], maximum=1048576, canonical=True)
    manifest['inputs'].update(inputs)
    manifest['files'] = [_ref(path, raw) for path, raw in sorted(files.items()) if path != 'manifest.json']
    files['manifest.json'] = dumps(manifest)
    return keccak256(files['manifest.json'])


class CollectionScriptPackageTests(TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = CollectionScriptFixture(mode='stable')
        cls.complete, cls.snapshot, cls.transcript = build(cls.fixture)

    def test_offline_replay_retains_exact_inputs_profiles_and_payloads(self):
        originals = dict(self.complete.files)
        with mock.patch('socket.socket', side_effect=AssertionError('network used')), \
                mock.patch.object(Path, 'read_bytes', side_effect=AssertionError('filesystem used')):
            self.assertEqual(package.verify(originals, self.complete.manifest_hash), self.complete)
        self.assertEqual(originals['source/anchor.json'], self.fixture.anchor_raw)
        self.assertEqual(originals['source/transcript.json'], self.transcript)
        self.assertEqual(originals['source/runtime-bridge.bin'], self.fixture.runtime_bridge_raw)
        self.assertEqual(originals['source/snapshot.json'], self.snapshot)
        for name, raw in (('package', package.PROFILE_BYTES), ('source', native.PROFILE_BYTES),
                ('wire', wire.PROFILE_BYTES), ('transport', rpc.PROFILE_BYTES)):
            self.assertEqual(originals['definitions/' + name + '-profile.json'], raw)
        snapshot = loads(self.snapshot, maximum=package.MAX_SNAPSHOT, canonical=True)
        self.assertTrue(self.complete.report['payloads'])
        for occurrence, row in zip(snapshot['interpretations'], self.complete.report['payloads']):
            self.assertEqual(originals[row['script']['path']], hex_bytes(occurrence['report']['script']['payloadHex']))
            self.assertIsNone(row['dependency'])
        self.assertNotIn('tokenId', self.complete.report['sourceState'])
        self.assertFalse(self.complete.report['claims']['runtimeBridgeContentsVerified'])
        self.assertFalse(self.complete.report['claims']['completeObjectDossier'])

    def test_unavailable_library_outcomes_survive_full_replay(self):
        result, snapshot_raw, transcript_raw = build(CollectionScriptFixture(mode='chunked', registry=True, registry_mismatch=True))
        self.assertEqual(package.verify(dict(result.files), result.manifest_hash), result)
        transcript = loads(transcript_raw, maximum=rpc.MAX_TRANSCRIPT, canonical=True)
        self.assertTrue(any('unavailable' in row for row in transcript['calls']))
        snapshot = loads(snapshot_raw, maximum=package.MAX_SNAPSHOT, canonical=True)
        self.assertTrue(snapshot['interpretations'])
        self.assertTrue(any(not row['report']['completeDependencyBytes'] for row in snapshot['interpretations']))
        self.assertTrue(all(row['dependency'] is None for row in result.report['payloads']))
        self.assertEqual(dict(result.files)['source/transcript.json'], transcript_raw)

    def test_complete_host_library_bytes_survive_partial_registry_readback(self):
        result, snapshot_raw, _ = build(CollectionScriptFixture(mode='chunked', registry=True, unavailable='registry'))
        self.assertEqual(package.verify(dict(result.files), result.manifest_hash), result)
        snapshot = loads(snapshot_raw, maximum=package.MAX_SNAPSHOT, canonical=True)
        files = dict(result.files)
        for original, row in zip(snapshot['interpretations'], result.report['payloads']):
            self.assertFalse(row['wireCompleteness']['completeDependencyBytes'])
            self.assertEqual(original['report']['dependency']['status'], 'partial_unavailable')
            self.assertEqual(files[row['dependency']['path']],
                hex_bytes(original['report']['dependency']['payloadHex']))

    def test_missing_script_chunk_preserves_library_and_original_chunk_denominator(self):
        fixture = CollectionScriptFixture(mode='chunked')
        fixture.fail(fixture.metadata, 'scriptBundleChunk(bytes32,uint256)',
            ('bytes32', 'uint256'), (fixture.value['script']['bundleId'], 0))
        result, snapshot_raw, _ = build(fixture)
        snapshot = loads(snapshot_raw, maximum=package.MAX_SNAPSHOT, canonical=True)
        for original, row in zip(snapshot['interpretations'], result.report['payloads']):
            self.assertFalse(row['wireCompleteness']['completeScriptBytes'])
            self.assertIsNone(row['script'])
            self.assertIsNotNone(row['dependency'])
            self.assertEqual(len(original['value']['script']['chunks']), 2)

    def test_zero_selection_inline_and_empty_sources_remain_distinct(self):
        for mode in ('inline', 'empty'):
            result, snapshot_raw, _ = build(CollectionScriptFixture(mode=mode))
            snapshot = loads(snapshot_raw, maximum=package.MAX_SNAPSHOT, canonical=True)
            self.assertEqual(snapshot['availability']['current_manifest'], 'zero_selection')
            self.assertEqual(snapshot['availability']['unmanifestedInlineScript'], mode == 'inline')
            self.assertEqual(snapshot['interpretations'], [])
            self.assertEqual(result.report['payloads'], [])
            self.assertEqual(package.verify(dict(result.files), result.manifest_hash), result)

    def test_replaced_metadata_does_not_relabel_saved_bundle_as_current(self):
        fixture = CollectionScriptFixture(mode='chunked', replaced=True)
        result, snapshot_raw, _ = build(fixture)
        snapshot = loads(snapshot_raw, maximum=package.MAX_SNAPSHOT, canonical=True)
        self.assertEqual(snapshot['availability']['current_manifest'], 'call_unavailable')
        self.assertEqual([row['basis'] for row in snapshot['interpretations']], ['raw_saved_bundle'])
        self.assertEqual(snapshot['interpretations'][0]['host'], fixture.metadata)
        self.assertNotEqual(snapshot['graph']['metadata']['address'], fixture.metadata)
        self.assertEqual(package.verify(dict(result.files), result.manifest_hash), result)

    def test_external_input_and_package_commitments_are_independent(self):
        wrong = keccak256(b'wrong commitment')
        with self.assertRaisesRegex(MuseumError, 'external manifest'):
            package.verify(dict(self.complete.files), wrong)
        values = [self.fixture.anchor_raw, keccak256(self.fixture.anchor_raw),
            self.transcript, keccak256(self.transcript), self.fixture.runtime_bridge_raw,
            keccak256(self.fixture.runtime_bridge_raw)]
        for index in (1, 3, 5):
            with self.subTest(input=index):
                changed = list(values); changed[index] = wrong
                with self.assertRaisesRegex(MuseumError, 'external commitment'):
                    package.assemble(*changed, provenance='synthetic_fixture', disclosure='public')

    def test_rehashed_reports_snapshots_definitions_and_files_are_reconstructed(self):
        for kind in ('report', 'snapshot', 'claim', 'extra', 'omitted', 'payload', 'definition'):
            with self.subTest(kind=kind):
                files = dict(self.complete.files)
                if kind in ('report', 'snapshot'):
                    path = 'report.json' if kind == 'report' else 'source/snapshot.json'
                    value = loads(files[path], maximum=package.MAX_SNAPSHOT, canonical=True)
                    value['claims']['inventedCompleteness'] = True
                    files[path] = dumps(value)
                elif kind == 'claim':
                    manifest = loads(files['manifest.json'], maximum=1048576, canonical=True)
                    manifest['claims']['completeObjectDossier'] = True
                    files['manifest.json'] = dumps(manifest)
                elif kind == 'extra':
                    files['unobserved.bin'] = b'unobserved'
                elif kind == 'omitted':
                    del files['source/snapshot.json']
                elif kind == 'payload':
                    path = next(path for path in files if path.startswith('payloads/'))
                    files[path] += b'changed'
                else:
                    files['definitions/wire-profile.json'] = b'{}'
                with self.assertRaisesRegex(MuseumError, 'reconstruction'):
                    package.verify(files, repin(files))

    def test_runtime_bridge_rehash_cannot_override_original_anchor_admission(self):
        files = dict(self.complete.files)
        files['source/runtime-bridge.bin'] += b'changed'
        pin = repin(files, runtimeBridgeHash=keccak256(files['source/runtime-bridge.bin']))
        with self.assertRaisesRegex(MuseumError, 'retained runtime bridge differs'):
            package.verify(files, pin)

    def test_unconsumed_and_missing_original_calls_are_refused(self):
        for append in (True, False):
            files = dict(self.complete.files)
            transcript = loads(files['source/transcript.json'], maximum=rpc.MAX_TRANSCRIPT, canonical=True)
            if append:
                transcript['calls'].append(deepcopy(transcript['calls'][-1]))
            else:
                transcript['calls'].pop()
            files['source/transcript.json'] = dumps(transcript)
            pin = repin(files, transcriptHash=keccak256(files['source/transcript.json']))
            with self.assertRaisesRegex(MuseumError, 'unconsumed|missing call'):
                package.verify(files, pin)

    def test_public_disclosure_precedes_source_reads_and_provenance_is_bound(self):
        with mock.patch.object(native, 'CollectionScriptSource', side_effect=AssertionError('source read')):
            with self.assertRaisesRegex(MuseumError, 'public disclosure required'):
                package.assemble(b'', '', b'', '', b'', '', provenance='synthetic_fixture', disclosure='restricted')
        files = dict(self.complete.files)
        with self.assertRaises(MuseumError):
            package.verify(files, repin(files, provenance='trusted_rpc'))

    def test_cli_publishes_new_package_and_refuses_existing_output(self):
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            values = {'anchor': self.fixture.anchor_raw, 'transcript': self.transcript,
                'runtime-bridge': self.fixture.runtime_bridge_raw}
            args = ['assemble', '--provenance', 'synthetic_fixture', '--disclosure', 'public']
            for name, raw in values.items():
                path = root / (name + '.bin'); path.write_bytes(raw)
                args += ['--' + name, str(path), '--' + name + '-hash', keccak256(raw)]
            output = root / 'package'
            args += ['--output', str(output)]
            with redirect_stdout(io.StringIO()) as printed:
                package.main(args)
            self.assertEqual(loads(printed.getvalue().encode())['manifestHash'], self.complete.manifest_hash)
            with redirect_stdout(io.StringIO()):
                package.main(['verify', str(output), '--manifest-hash', self.complete.manifest_hash])
            with self.assertRaises(SystemExit) as error, redirect_stdout(io.StringIO()), mock.patch('sys.stderr', io.StringIO()):
                package.main(args)
            self.assertEqual(error.exception.code, 2)
