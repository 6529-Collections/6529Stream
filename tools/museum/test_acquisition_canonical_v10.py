"""Concrete common-state native packet composition; no source-verifier mocks."""
from copy import deepcopy
from contextlib import redirect_stderr
import io
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import acquisition_canonical_v10 as v
from . import acquisition_scoped_policy_finality_v9 as scoped
from . import canonical_native_inputs_v1 as inputs
from . import canonical_object_dossier_v3 as dossier
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .title_v5_fixture import TitleV5Fixture
from .scoped_policy_finality_fixture_v2 import ScopedPolicyFinalityFixtureV2
from .test_acquisition_work_condition_v1 import title_case
from .test_acquisition_recovery_sustainability_v1 import RecoverySustainabilityFixture
from .test_acquisition_preservation_current_v1 import input_envelope


def composed_inputs(*, v9=False):
    base = ScopedPolicyFinalityFixtureV2() if v9 else TitleV5Fixture()
    state = {key: '41' if key == 'tokenId' else base.a[key] for key in v.observations.STATE_KEYS}
    recovery = RecoverySustainabilityFixture(source_state=state, base=base, mode='empty')
    prior, evidence, kwargs = title_case(base)
    if v9:
        captured = base.policy_capture()
        prior = scoped.compose(prior.files, prior.manifest_hash, captured.files, captured.manifest_hash, disclosure='public')
    _, preservation = input_envelope(state, source_header=deepcopy(base.blocks[state['blockHash']]))
    sources, source_hash = inputs.create(dumps(preservation), dumps(evidence), kwargs['metadata_files'],
        recovery.envelope(), condition_files=kwargs['condition_files'])
    return prior, sources, source_hash


def repin(files):
    manifest = loads(files['manifest.json'], maximum=v.MAX_MANIFEST, canonical=True)
    manifest['files'] = [v.package._ref(path, raw) for path, raw in sorted(files.items()) if path != 'manifest.json']
    files['manifest.json'] = dumps(manifest)
    return keccak256(files['manifest.json'])


class CanonicalPacketTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.prior, cls.sources, cls.source_hash = composed_inputs()
        cls.result = v.compose(cls.prior.files, cls.prior.manifest_hash, cls.sources, cls.source_hash, disclosure='public')
        cls.files = dict(cls.result.files)
        cls.dossier_result = None

    def dossier_result_for_test(self):
        if type(self).dossier_result is None:
            type(self).dossier_result = dossier.compose(self.files, self.result.manifest_hash, disclosure='public')
        return type(self).dossier_result

    def test_full_source_replay_preserves_originals_and_all_nineteen_groups(self):
        original = loads(dict(self.prior.files)[v.previous.title.PACKET_PATH], maximum=v.MAX_BYTES, canonical=True)
        packet = loads(self.files[v.PACKET_PATH], maximum=v.MAX_BYTES, canonical=True)
        self.assertEqual(set(packet), set(original))
        for key in original:
            if key in v.CHANGED.values():
                self.assertEqual(packet[key]['priorEvidence'], original[key])
                self.assertEqual(packet[key]['kind'], v.BRANCHES[key])
            elif key not in ('schema', 'version'):
                self.assertEqual(packet[key], original[key])
        for path, raw in self.prior.files:
            self.assertEqual(self.files['prior/' + path], raw)
        for path, raw in self.sources.items():
            self.assertEqual(self.files['inputs/' + path], raw)
        self.assertEqual(len(self.result.report['items']), 19)
        self.assertEqual(len(self.result.report['sourceReconciliation']['sources']), 15)
        self.assertIsNone(packet['scriptDrill']['current']['packetPatch'])
        self.assertFalse(packet['preservation']['current']['fixityCycleHistory']['hostSelectionProven'])

    def test_offline_full_reconstruction_and_unchanged_native_records(self):
        before = deepcopy(self.files)
        with patch('socket.socket', side_effect=AssertionError('network used')):
            result = v.verify(self.files, self.result.manifest_hash)
        self.assertEqual(result.files, self.result.files)
        self.assertEqual(self.files, before)
        self.assertFalse(result.report['canonicalPacketReady'])

    def test_rehashed_derived_packet_and_hidden_extra_file_refuse(self):
        for path in (v.PACKET_PATH, 'invented.json'):
            files = dict(self.files)
            body = loads(files[path], maximum=v.MAX_BYTES) if path in files else {}
            body['completeCanonicalPacket'] = True
            files[path] = dumps(body)
            with self.subTest(path=path), self.assertRaisesRegex(MuseumError, 'reconstruction differs'):
                v.verify(files, repin(files))

    def test_native_host_bound_elsewhere_refuses_after_input_rehash(self):
        files = dict(self.sources)
        value = loads(files['preservation/input.json'], maximum=v.MAX_BYTES, canonical=True)
        value['context']['core'] = '0x' + '12' * 20
        files['preservation/input.json'] = dumps(value)
        digest = repin(files)
        with self.assertRaisesRegex(MuseumError, 'packet source core'):
            v.compose(self.prior.files, self.prior.manifest_hash, files, digest, disclosure='public')

    def test_source_header_contradiction_refuses_after_original_source_rehash(self):
        files = dict(self.sources)
        value = loads(files['preservation/input.json'], maximum=v.MAX_BYTES, canonical=True)
        source = value['evidence']['recordSource']
        for row in source['transcript']['calls']:
            if row['method'] in ('eth_getBlockByHash', 'eth_getBlockByNumber'):
                row['result']['extraData'] = '0x1234'
        source['transcriptHash'] = keccak256(dumps(source['transcript']))
        files['preservation/input.json'] = dumps(value)
        with self.assertRaisesRegex(MuseumError, 'conflicting exact RPC outcome|conflicting header'):
            v.compose(self.prior.files, self.prior.manifest_hash, files, repin(files), disclosure='public')

    def test_dossier_keeps_49_denominator_and_original_event_occurrences(self):
        result = self.dossier_result_for_test()
        files = dict(result.files)
        self.assertEqual(result.report['dossierRequirements']['counts']['total'], 49)
        self.assertEqual(len(result.report['packetRequirements']), 19)
        self.assertFalse(result.report['dossierRequirements']['complete'])
        for path, raw in self.files.items():
            self.assertEqual(files['acquisition/' + path], raw)
        events = loads(files['dossier/event-occurrences.json'], maximum=v.MAX_BYTES)
        self.assertGreater(len(events), len({dumps(row['event']) for row in events}))
        self.assertEqual(dossier.verify(files, result.manifest_hash).files, result.files)

    def test_dossier_requirement_drop_cannot_pass_by_rehashing(self):
        result = self.dossier_result_for_test()
        files = dict(result.files)
        value = loads(files['dossier/requirements.json'], maximum=v.MAX_BYTES, canonical=True)
        value['results'].pop()
        files['dossier/requirements.json'] = dumps(value)
        with self.assertRaisesRegex(MuseumError, 'full reconstruction differs'):
            dossier.verify(files, repin(files))
        with self.assertRaisesRegex(MuseumError, 'unresolved requirements'):
            dossier.complete(result.files, result.manifest_hash)

    def test_cli_refuses_complete_without_touching_sources(self):
        with TemporaryDirectory(prefix='stream-v10-') as directory:
            path = Path(directory) / 'packet'
            write_tree(self.files, path)
            error = io.StringIO()
            with redirect_stderr(error), self.assertRaises(SystemExit) as caught:
                v.main(['complete-packet', str(path), '--manifest-hash', self.result.manifest_hash])
            self.assertEqual(caught.exception.code, 2)
            self.assertIn('unresolved items', error.getvalue())
            self.assertEqual(read_tree(path), self.files)

    def test_v9_native_finality_survives_current_family_composition(self):
        prior, sources, source_hash = composed_inputs(v9=True)
        result = v.compose(prior.files, prior.manifest_hash, sources, source_hash, disclosure='public')
        packet = loads(dict(result.files)[v.PACKET_PATH], maximum=v.MAX_BYTES)
        original = loads(dict(prior.files)[scoped.PACKET_PATH], maximum=v.MAX_BYTES)
        self.assertEqual(packet['finality'], original['finality'])
        self.assertEqual(packet['contentRootProof'], original['contentRootProof'])
        self.assertEqual(packet['finality']['kind'], 'native_scoped_policy_finality_v2')
        self.assertEqual(len(result.report['sourceReconciliation']['sources']), 16)


if __name__ == '__main__':
    unittest.main()
