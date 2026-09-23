"""Replayed native coverage cannot be promoted by rehashing package reports."""
from copy import deepcopy
from pathlib import Path
from unittest import TestCase, mock

from . import canonical_composition_observations_v1 as observations
from . import genesis_registry_coverage_v1 as coverage
from .canonical import MuseumError, dumps, keccak256, loads
from .object_dossier import _ref
from .test_genesis_registry_source_v1 import GenesisRegistryFixture


def build(fixture):
    snapshot, transcript = fixture.capture()
    result = coverage.assemble(dict(fixture.plan.files), fixture.plan.manifest_hash,
        fixture.anchor_raw, keccak256(fixture.anchor_raw), transcript, keccak256(transcript),
        provenance='synthetic_fixture', disclosure='public')
    return result, snapshot, transcript


def repin(files, inputs=None):
    manifest = loads(files['manifest.json'], maximum=1048576)
    if inputs is not None:
        manifest['inputs'].update(inputs)
    manifest['files'] = [_ref(path, raw) for path, raw in sorted(files.items()) if path != 'manifest.json']
    files['manifest.json'] = dumps(manifest)
    return keccak256(files['manifest.json'])


class GenesisRegistryCoverageTests(TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = GenesisRegistryFixture()
        cls.complete, cls.snapshot, cls.transcript = build(cls.fixture)

    def test_complete_package_replays_without_reading_source_files(self):
        files = dict(self.complete.files)
        with mock.patch.object(Path, 'read_bytes', side_effect=AssertionError('unexpected filesystem read')):
            result = coverage.verify(files, self.complete.manifest_hash)
        self.assertEqual(result, self.complete)
        self.assertEqual(files['source/snapshot.json'], self.snapshot)
        self.assertEqual(files['source/transcript.json'], self.transcript)
        self.assertEqual({p.removeprefix('plan/'): raw for p, raw in files.items()
            if p.startswith('plan/')}, dict(self.fixture.plan.files))
        self.assertFalse(result.report['claims']['registrationPerformed'])
        self.assertFalse(result.report['claims']['completeObjectDossier'])

    def test_partial_package_keeps_all_fifty_one_rows_and_original_conflicts(self):
        fixture = GenesisRegistryFixture()
        fixture.install_document(20, exists=False)
        fixture.install_document(21, status=1)
        conflict = b'original same-name conflicting definition bytes'
        fixture.install_document(22, content=conflict)
        result, _, _ = build(fixture)
        value = coverage.verify(dict(result.files), result.manifest_hash).report['nativeSource']
        self.assertEqual(len(value['documents']), 51)
        self.assertEqual(value['coverage']['outcomes'],
            {'absent': '1', 'active': '48', 'deprecated': '1', 'archived': '0', 'conflict': '1'})
        self.assertEqual(value['documents'][22]['payloadHex'], '0x' + conflict.hex())
        self.assertFalse(value['coverage']['allPlanDocumentsPresentAndExact'])
        self.assertFalse(value['coverage']['allPlanDocumentsCurrentlyEligible'])

    def test_independent_original_and_outer_pins_are_required(self):
        wrong = '0x' + '11' * 32
        with self.assertRaisesRegex(MuseumError, 'external manifest'):
            coverage.verify(dict(self.complete.files), wrong)
        with self.assertRaisesRegex(MuseumError, 'original source commitment'):
            coverage.assemble(dict(self.fixture.plan.files), self.fixture.plan.manifest_hash,
                self.fixture.anchor_raw, wrong, self.transcript, keccak256(self.transcript),
                provenance='synthetic_fixture', disclosure='public')

    def test_rehashed_report_snapshot_claim_and_file_tampering_refused(self):
        for kind in ('report', 'snapshot', 'claim', 'extra', 'omitted'):
            with self.subTest(kind=kind):
                files = dict(self.complete.files)
                if kind in ('report', 'snapshot'):
                    path = 'report.json' if kind == 'report' else 'source/snapshot.json'
                    value = loads(files[path], maximum=64 * 1024 * 1024)
                    value['claims']['actualChainAcceptance'] = True
                    files[path] = dumps(value)
                elif kind == 'claim':
                    manifest = loads(files['manifest.json'], maximum=1048576)
                    manifest['claims']['completeObjectDossier'] = True
                    files['manifest.json'] = dumps(manifest)
                elif kind == 'extra':
                    files['unobserved-document.json'] = b'{}'
                else:
                    del files['source/snapshot.json']
                with self.assertRaisesRegex(MuseumError, 'reconstruction'):
                    coverage.verify(files, repin(files))

    def test_rehashed_unconsumed_transcript_refused(self):
        files = dict(self.complete.files)
        transcript = loads(files['source/transcript.json'], maximum=64 * 1024 * 1024)
        transcript['calls'].append(deepcopy(transcript['calls'][-1]))
        files['source/transcript.json'] = dumps(transcript)
        pin = repin(files, {'transcriptHash': keccak256(files['source/transcript.json'])})
        with self.assertRaisesRegex(MuseumError, 'unconsumed'):
            coverage.verify(files, pin)

    def test_public_scope_and_runtime_provenance_cannot_be_changed(self):
        for override in ({'disclosure': 'restricted'}, {'provenance': 'trusted_rpc'}):
            with self.subTest(override=override):
                files = dict(self.complete.files)
                with self.assertRaises(MuseumError):
                    coverage.verify(files, repin(files, override))

    def test_verified_observation_joins_exact_declared_state_without_token_inference(self):
        row = coverage.observation(dict(self.complete.files), self.complete.manifest_hash)
        self.assertNotIn('tokenId', row['anchor'])
        self.assertNotIn('collectionId', row['anchor'])
        reference = {key: self.fixture.anchor[key] for key in observations.STATE_KEYS
            if key in self.fixture.anchor} | {'tokenId': '1', 'collectionId': '1'}
        result = observations.reconcile(reference, [row])
        self.assertIsInstance(result, dict)
        with self.assertRaisesRegex(MuseumError, 'source state differs'):
            observations.reconcile(reference | {'blockHash': '0x' + '99' * 32}, [row])
