"""Concrete synthetic adopted VIEW captures; no live RPC or native execution."""
from copy import deepcopy
from contextlib import redirect_stdout
import io
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import public_view_policy_output_capture_v2 as capture
from . import public_view_policy_output_source_v2 as source
from . import view_policy_output_types_v2 as types
from . import view_policy_output_wire_v2 as output_wire
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import decode, encode
from .current_rights_source import DOCUMENT_FACTS
from .view_policy_output_fixture_v2 import ViewPolicyOutputFixtureV2


def repin(files):
    """Rehash the outer inventory, leaving exact-source reconstruction to verify."""
    files = dict(files)
    manifest = loads(files['manifest.json'])
    manifest['files'] = [capture.base._ref(path, raw) for path, raw in sorted(files.items())
                         if path != 'manifest.json']
    files['manifest.json'] = dumps(manifest)
    return files, keccak256(files['manifest.json'])


class PublicViewPolicyOutputCaptureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = ViewPolicyOutputFixtureV2(count=3)
        adapter = cls.fixture.source()
        cls.snapshot_raw = adapter.snapshot()
        cls.snapshot = loads(cls.snapshot_raw, maximum=source.MAX_OUTPUT)
        transcript = adapter.transcript()
        cls.inputs = (adapter.anchor_bytes, keccak256(adapter.anchor_bytes), source.PROFILE_HASH,
                      transcript, keccak256(transcript))
        cls.result = capture.replay(*cls.inputs, provenance='synthetic_fixture', disclosure='public')

    def transcript(self):
        return loads(self.inputs[3], maximum=source.MAX_OUTPUT)

    def replay_calls(self, value):
        raw = dumps(value)
        return capture.replay(*self.inputs[:3], raw, keccak256(raw),
                              provenance='synthetic_fixture', disclosure='public')

    def test_exact_triplet_native_definitions_and_complete_evidence(self):
        files = dict(self.result.files)
        self.assertEqual(files['source/anchor.json'], self.inputs[0])
        self.assertEqual(files['source/transcript.json'], self.inputs[3])
        self.assertEqual(files['source/snapshot.json'], self.snapshot_raw)
        definitions = source.wire.definitions()
        self.assertEqual(len({row['id'] for row in definitions}), len(definitions))
        self.assertEqual({path for path in files if path.startswith('definitions/native/')},
            {'definitions/native/' + row['name'] + '.json' for row in definitions})
        for row in definitions:
            self.assertEqual(files['definitions/native/' + row['name'] + '.json'], row['bytes'])
            self.assertEqual(keccak256(row['bytes']), row['hash'])
        self.assertEqual(loads(files['view-output/evidence.json'], maximum=source.MAX_OUTPUT),
                         self.snapshot['bundle'])
        for row in output_wire.definitions():
            self.assertIn('definitions/native/' + row['name'] + '.json', files)

    def test_full_target_entropy_row_and_explicit_partial_claims(self):
        target = loads(dict(self.result.files)['view-output/target-row.json'])
        self.assertEqual(target, self.snapshot['targetOutput'])
        self.assertEqual(target['kind'], 'adopted_view_output_row_v2')
        self.assertEqual(target['row'], self.snapshot['bundle']['output']['checkpoint']['outputs'][0])
        self.assertEqual(len(encode((types.OUTPUT,), (output_wire._v(types.OUTPUT, target['row']),))), 31 * 32)
        self.assertEqual(target['tokenId'], self.snapshot['identity']['tokenId'])
        self.assertEqual(target['rowIndex'], '0')
        self.assertFalse(target['nativeFinality'])
        self.assertFalse(target['renderedBytesRecovered'])
        self.assertEqual(self.result.report['provenance'], 'synthetic_fixture')
        self.assertFalse(self.result.report['canonicalPacketCompatible'])
        self.assertFalse(self.result.report['completeCanonicalPacket'])
        for key in ('originalRenderedBytesRecovered', 'rendererReexecuted', 'historicalAuthorityVerified',
                    'currentEligibilityVerified', 'currentArchiveLivenessVerified', 'viewFinalityEstablished',
                    'sourceConsensusVerified', 'actualChainAcceptance', 'completeAcquisitionPacket', 'endpointRetained'):
            self.assertFalse(self.result.report['claims'][key], key)

    def test_sixty_five_rows_cross_part_boundary_without_dropping_occurrences(self):
        fixture = ViewPolicyOutputFixtureV2(count=65)
        result = fixture.capture()
        snapshot = loads(dict(result.files)['source/snapshot.json'], maximum=source.MAX_OUTPUT)
        output = snapshot['bundle']['output']
        self.assertEqual(len(output['checkpoint']['outputs']), 65)
        self.assertEqual([row[1] for row in output['checkpoint']['outputs']], [str(i) for i in range(41, 106)])
        parts = output['manifest']['parts']
        self.assertEqual(len(parts), 2)
        self.assertEqual([(part['descriptor'][5], part['descriptor'][6]) for part in parts], [('0', '64'), ('64', '1')])
        self.assertEqual([int(part['descriptor'][4]) for part in parts], [640 + 992 * 64, 640 + 992])
        self.assertGreater(len(parts[0]['chunks']), 1)
        self.assertEqual(capture.verify(result.files, result.manifest_hash).files, result.files)

    def test_all_policy_modes_preserve_finalized_versus_terminal(self):
        for mode, status, explicit, finalized, terminal in (
            ('disabled', '1', True, False, True), ('not_required', '2', True, False, True),
            ('finalized', '5', True, True, False), ('legacy', '5', False, True, False)):
            with self.subTest(mode=mode):
                result = ViewPolicyOutputFixtureV2(count=3, mode=mode).capture()
                snapshot = loads(dict(result.files)['source/snapshot.json'], maximum=source.MAX_OUTPUT)
                for row in snapshot['bundle']['output']['checkpoint']['outputs']:
                    entropy = row[7]
                    self.assertEqual((entropy[3], entropy[5], entropy[7], entropy[8]),
                                     (explicit, status, finalized, terminal))
                self.assertEqual(capture.verify(result.files, result.manifest_hash).files, result.files)

    def test_later_adoption_does_not_replace_original_checkpoint_adoption(self):
        original = ViewPolicyOutputFixtureV2().result()
        later = ViewPolicyOutputFixtureV2(later_adoption=True).result()
        self.assertEqual(original['bundle']['output'], later['bundle']['output'])
        self.assertNotEqual(later['bundle']['adoption']['head'], later['bundle']['output']['checkpoint']['plan'][1])
        self.assertEqual(len(later['bundle']['adoption']['history']),
                         len(original['bundle']['adoption']['history']) + 1)

    def test_later_burn_and_original_retained_burn_are_distinct(self):
        live = ViewPolicyOutputFixtureV2().result()
        later = ViewPolicyOutputFixtureV2(later_burn=True).result()
        retained = ViewPolicyOutputFixtureV2(burned=True).result()
        self.assertFalse(live['identity']['burned'])
        self.assertTrue(later['identity']['burned'])
        self.assertTrue(retained['identity']['burned'])
        self.assertEqual(live['bundle']['output'], later['bundle']['output'])
        self.assertEqual(later['targetOutput']['row'][3:6], ['2', False, '1'])
        self.assertEqual(retained['targetOutput']['row'][3:6], ['3', True, '2'])
        self.assertNotEqual(later['targetOutput']['outputRoot'], retained['targetOutput']['outputRoot'])

    def test_original_getters_do_not_call_current_render_or_finality(self):
        forbidden = ('requireCurrentCheckpoint(bytes32)', 'requireCurrentView((uint8,uint256,uint256,bytes32))',
            'currentViewAdoption((uint8,uint256,uint256,bytes32))', 'requireArtifactCoverage(bytes32)',
            'renderTokenURI(uint256)', 'verifyFinality(uint256)')
        selectors = {schema_id(signature)[:10] for signature in forbidden}
        calls = self.transcript()['calls']
        for row in calls:
            if row['method'] == 'eth_call':
                self.assertNotIn(row['params'][0]['data'][:10], selectors)
        output_calls = [row for row in calls if row['method'] == 'eth_call'
                        and row['params'][0]['data'][:10] == schema_id('outputAt(bytes32,uint256)')[:10]]
        self.assertEqual(len(output_calls), 3)

    def test_transcript_omission_extra_runtime_and_definition_tampering(self):
        for mode in ('omission', 'extra', 'runtime', 'definition'):
            with self.subTest(mode=mode):
                value = self.transcript()
                if mode == 'omission': value['calls'].pop(0)
                elif mode == 'extra': value['calls'].append(deepcopy(value['calls'][-1]))
                elif mode == 'runtime': next(row for row in value['calls'] if row['method'] == 'eth_getCode')['result'] = '0x00'
                else:
                    row = next(row for row in value['calls'] if row['method'] == 'eth_call'
                        and row['params'][0]['data'][:10] == schema_id('documentFacts(bytes32)')[:10])
                    facts = list(decode((DOCUMENT_FACTS,), hex_bytes(row['result']))[0])
                    facts[3] = schema_id('wrong literal native VIEW definition')
                    row['result'] = '0x' + encode((DOCUMENT_FACTS,), (facts,)).hex()
                with self.assertRaises(MuseumError): self.replay_calls(value)

    def test_missing_part_or_changed_output_cannot_be_replaced_by_manifest_hash(self):
        for mode in ('missing_part', 'changed_output'):
            value = self.transcript()
            signature = 'manifestPart(bytes32,uint256)' if mode == 'missing_part' else 'outputAt(bytes32,uint256)'
            row = next(row for row in value['calls'] if row['method'] == 'eth_call'
                       and row['params'][0]['data'][:10] == schema_id(signature)[:10])
            if mode == 'missing_part': value['calls'].remove(row)
            else:
                output = list(decode((types.OUTPUT,), hex_bytes(row['result']))[0])
                output[8] = schema_id('changed original JSON hash')
                row['result'] = '0x' + encode((types.OUTPUT,), (output,)).hex()
            with self.subTest(mode=mode), self.assertRaises(MuseumError): self.replay_calls(value)

    def test_repinned_derivatives_and_extra_file_fail_exact_reconstruction(self):
        paths = ('definitions/native/' + source.wire.definitions()[0]['name'] + '.json',
                 'view-output/evidence.json', 'view-output/target-row.json', 'source/snapshot.json', 'capture/report.json')
        for path in paths:
            with self.subTest(path=path):
                files = dict(self.result.files); files[path] += b'\n'
                files, digest = repin(files)
                with self.assertRaisesRegex(MuseumError, 'reconstruction differs'): capture.verify(files, digest)
        files = dict(self.result.files); files['undeclared-extra.txt'] = b'extra'
        files, digest = repin(files)
        with self.assertRaisesRegex(MuseumError, 'reconstruction differs'): capture.verify(files, digest)

    def test_external_pins_and_closed_anchor(self):
        wrong = schema_id('wrong external VIEW pin')
        for index in (1, 2, 4):
            inputs = list(self.inputs); inputs[index] = wrong
            with self.subTest(index=index), self.assertRaises(MuseumError):
                capture.replay(*inputs, provenance='synthetic_fixture', disclosure='public')
        anchor = loads(self.inputs[0]); anchor['unreviewedFlag'] = True; raw = dumps(anchor)
        with self.assertRaisesRegex(MuseumError, 'anchor shape'):
            capture.replay(raw, keccak256(raw), source.PROFILE_HASH, *self.inputs[3:],
                           provenance='synthetic_fixture', disclosure='public')
        with self.assertRaisesRegex(MuseumError, 'external manifest pin'):
            capture.verify(self.result.files, wrong)

    def test_offline_replay_and_common_dispatch(self):
        from .package_v2 import verify_package
        with patch('socket.socket', side_effect=AssertionError('network forbidden')):
            self.assertEqual(capture.verify(self.result.files, self.result.manifest_hash).files, self.result.files)
            with TemporaryDirectory() as directory:
                output = Path(directory) / 'view'
                write_tree(dict(self.result.files), output)
                self.assertEqual(verify_package(output, self.result.manifest_hash).files, self.result.files)

    def test_disclosure_precedes_all_input_destination_and_rpc_reads(self):
        wrong = schema_id('unused')
        with self.assertRaisesRegex(MuseumError, 'public disclosure'):
            capture.replay(None, wrong, wrong, None, wrong, provenance='synthetic_fixture', disclosure='private')
        with patch.object(capture, '_read_input', side_effect=AssertionError('input read')), \
             patch('tools.museum.repository_exchange._destination', side_effect=AssertionError('destination read')):
            with self.assertRaisesRegex(MuseumError, 'public disclosure'):
                capture.main(['capture', '--anchor', 'missing', '--anchor-hash', wrong,
                    '--source-profile-hash', wrong, '--rpc-env', 'VIEW_TEST_RPC',
                    '--disclosure', 'private', '--output', 'unused'])

    def test_closed_anchor_and_runtime_admission_checked_before_endpoint(self):
        with TemporaryDirectory() as directory:
            root = Path(directory); path = root / 'anchor.json'
            original_get = capture.os.environ.get
            def guarded(key, *args):
                if key == 'VIEW_TEST_RPC': raise AssertionError('endpoint read before anchor preflight')
                return original_get(key, *args)
            for mode in ('synthetic_admission', 'extra_field'):
                anchor = loads(self.inputs[0])
                if mode == 'extra_field':
                    anchor['runtimeAdmission']['kind'] = 'externally_admitted_runtime'
                    anchor['unreviewedFlag'] = True
                raw = dumps(anchor); path.write_bytes(raw)
                with self.subTest(mode=mode), patch.object(capture.os.environ, 'get', side_effect=guarded):
                    with self.assertRaises(MuseumError):
                        capture.main(['capture', '--anchor', str(path), '--anchor-hash', keccak256(raw),
                            '--source-profile-hash', source.PROFILE_HASH, '--rpc-env', 'VIEW_TEST_RPC',
                            '--disclosure', 'public', '--output', str(root / mode)])

    def test_explicit_admission_at_live_boundary_remains_caller_admitted(self):
        anchor = loads(self.inputs[0]); anchor['runtimeAdmission']['kind'] = 'externally_admitted_runtime'
        raw = dumps(anchor); transport = capture.PublicRpcTransport('https://example.invalid/never-requested')
        with patch.object(transport, 'request', side_effect=self.fixture.request), \
             patch('socket.socket', side_effect=AssertionError('synthetic transport only')):
            result = capture.capture(raw, keccak256(raw), source.PROFILE_HASH, transport, disclosure='public')
        self.assertEqual(result.report['provenance'], 'trusted_rpc')
        self.assertFalse(result.report['claims']['actualChainAcceptance'])
        self.assertEqual(loads(dict(result.files)['source/anchor.json'])['runtimeAdmission'], anchor['runtimeAdmission'])

    def test_cli_atomic_replay_verify_and_no_overwrite(self):
        with TemporaryDirectory() as directory, patch('socket.socket', side_effect=AssertionError('offline only')):
            root = Path(directory); anchor = root / 'anchor.json'; transcript = root / 'transcript.json'
            output = root / 'capture'; anchor.write_bytes(self.inputs[0]); transcript.write_bytes(self.inputs[3])
            args = ['replay', '--anchor', str(anchor), '--anchor-hash', self.inputs[1],
                '--source-profile-hash', source.PROFILE_HASH, '--transcript', str(transcript),
                '--transcript-hash', self.inputs[4], '--provenance', 'synthetic_fixture',
                '--disclosure', 'public', '--output', str(output)]
            with redirect_stdout(io.StringIO()) as printed: capture.main(args)
            self.assertEqual(loads(printed.getvalue().encode())['manifestHash'], self.result.manifest_hash)
            self.assertEqual(read_tree(output), dict(self.result.files))
            with self.assertRaises((MuseumError, FileExistsError)): capture.main(args)
            self.assertEqual(read_tree(output), dict(self.result.files))
            with redirect_stdout(io.StringIO()):
                capture.main(['verify', str(output), '--manifest-hash', self.result.manifest_hash])


if __name__ == '__main__': unittest.main()
