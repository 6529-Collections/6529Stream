"""Concrete V4 retention/replay and original source-group correspondence.

The canonical token and supplementary statements deliberately have different
original capture states. Their successful retention is not an all-family
same-target capture claim. Production and General/transfer do share a real
source map, which exercises the same-anchor positive and hostile joins.
"""
from contextlib import redirect_stderr, redirect_stdout
from copy import deepcopy
from hashlib import sha256
from io import StringIO
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import canonical_object_dossier_v4 as dossier
from . import canonical_dossier_observations_v4 as observations
from . import package_v2
from .bagit import build_bag, read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .canonical_object_dossier_fixture_v4 import complete_case_v4
from .object_dossier import _ref
from .repository_exchange import export_bag, import_version


def repin(files):
    manifest = loads(files['manifest.json'], maximum=dossier.MAX_MANIFEST, canonical=True)
    manifest['files'] = [_ref(path, raw) for path, raw in sorted(files.items()) if path != 'manifest.json']
    files['manifest.json'] = dumps(manifest)
    return keccak256(files['manifest.json'])


class CanonicalObjectDossierV4Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with patch('socket.socket', side_effect=AssertionError('network used')):
            cls.case = complete_case_v4()
            files, digest, options = cls.case.inputs()
            cls.result = dossier.compose(files, digest, **options)
        cls.files = dict(cls.result.files)
        cls.rows = observations.sources(dict(cls.case.canonical.files),
            production_files=dict(cls.case.production.files),
            general_files=dict(cls.case.general.files), transfer_files=dict(cls.case.transfer.files))
        cls.supplement_rows = [row for row in cls.rows if not row['name'].startswith('base/')]

    def test_complete_originals_and_nineteen_fortynine_decisions_are_exact(self):
        for role in ('canonical', 'production', 'transfer'):
            for path, raw in getattr(self.case, role).files:
                self.assertEqual(self.files[role + '/' + path], raw)
        nested = 'transfer/sources/general-dossier/'
        self.assertFalse(any(path.startswith('general/') for path in self.files))
        for path, raw in self.case.general.files:
            self.assertEqual(self.files[nested + path], raw)
        self.assertEqual(self.result.report['packetRequirementCount'], '19')
        self.assertEqual(self.result.report['dossierRequirementCount'], '49')
        self.assertEqual(self.result.report['requirementPromotions'], [])
        canonical = dict(self.case.canonical.files)
        self.assertEqual(self.files['canonical/input/dossier/requirements.json'],
            canonical['input/dossier/requirements.json'])
        self.assertEqual(self.files['canonical/input/report.json'], canonical['input/report.json'])

    def test_full_socket_offline_rebuild_and_generic_dispatch(self):
        with TemporaryDirectory(prefix='stream-dossier-v4-dispatch-') as temporary, \
                patch('socket.socket', side_effect=AssertionError('network used')):
            checked = dossier.verify(self.files, self.result.manifest_hash)
            directory = Path(temporary) / 'package'
            write_tree(self.files, directory)
            dispatched = package_v2.verify_package(directory, self.result.manifest_hash)
        self.assertEqual(checked.files, self.result.files)
        self.assertIsNotNone(dispatched)

    def test_distinct_capture_state_remains_unjoined_without_token_authority(self):
        joined = self.result.report['sourceReconciliation']
        supplements_ = [row for row in joined['sources'] if not row['name'].startswith('base/')]
        self.assertTrue(supplements_)
        self.assertTrue(all(row['status'] == 'unjoined' for row in supplements_))
        self.assertTrue(all('state_differs:blockHash' in row['reasons'] for row in supplements_))
        self.assertTrue(all(row['originalAnchor']['collectionId'] == '7' for row in supplements_))
        subjects = loads(self.files[dossier.SUPPLEMENTAL_PATH], maximum=dossier.MAX_BYTES)['subjects']
        self.assertTrue(subjects)
        self.assertTrue(all(row['status'] == 'different_source_identity' for row in subjects))
        self.assertTrue(all(not row['tokenAuthorityEstablished'] for row in subjects))
        self.assertEqual(self.result.report['sourceState']['collectionId'], '1')
        self.assertFalse(self.result.report['claims']['completeCanonicalDossier'])

    def test_actual_common_supplementary_state_and_collection_scope_are_distinct(self):
        # These are observations extracted from the concrete, replayed packages
        # in setUpClass. The private group check does not claim a new capture.
        joined = observations._group(self.supplement_rows)
        self.assertGreater(joined['successfulGetterCount'], 50)
        self.assertGreater(joined['uniqueEventCount'], 0)
        self.assertEqual({row['anchor']['blockHash'] for row in self.supplement_rows},
            {joined['blockHash']})
        source = loads(dict(self.case.general.files)['semantics/snapshot.json'], maximum=dossier.MAX_BYTES)
        target = dict(self.result.report['sourceState'], **source['sourceState'])
        classified = observations.subjects(target, general_files=dict(self.case.general.files))
        self.assertTrue(all(row['status'] == 'collection_documentary_scope' for row in classified))
        self.assertTrue(all(not row['tokenAuthorityEstablished'] for row in classified))

    def test_original_selections_and_duplicate_iris_do_not_merge_resources(self):
        # Both supplements intentionally declare this IRI, through distinct
        # original record occurrences. The enclosing V4 leaves both unchanged.
        iri = 'urn:fixture:physical-production:object'
        stem = keccak256(iri.encode())[2:]
        paths = ['production/production/resources/' + stem + '.json',
            'transfer/transfer/resources/' + stem + '.json']
        self.assertTrue(all(path in self.files for path in paths))
        self.assertTrue(all(loads(self.files[path])['id'] == iri for path in paths))
        self.assertFalse(self.result.report['claims']['semanticResourceIdentitiesMergedAcrossFamilies'])
        self.assertEqual(self.files['canonical/inputs/selection.json'],
            dict(self.case.canonical.files)['inputs/selection.json'])
        self.assertEqual(self.files['transfer/sources/general-dossier/inputs/selection.json'],
            dict(self.case.general.files)['inputs/selection.json'])

    def test_same_anchor_positive_getter_header_runtime_and_event_conflicts_reject(self):
        for mutation in ('getter', 'header', 'runtime', 'event'):
            rows = deepcopy(self.supplement_rows)
            if mutation == 'runtime':
                row = rows[-1]
                address = next(iter(row['runtimePins']))
                row['runtimePins'][address] = keccak256(b'contradictory actual runtime')
            else:
                method = {'getter': 'eth_call', 'header': 'eth_getBlockByHash',
                    'event': 'eth_getTransactionReceipt'}[mutation]
                original = next(row for row in rows if any(call['method'] == method
                    and call.get('result') and (mutation != 'event' or call['result']['logs'])
                    for call in row['transcript']['calls']))
                added = deepcopy(original); added['name'] += '/contradiction'
                call = next(call for call in added['transcript']['calls']
                    if call['method'] == method and call.get('result')
                    and (mutation != 'event' or call['result']['logs']))
                if mutation == 'getter': call['result'] = '0x' + '12' * 32
                elif mutation == 'header': call['result']['stateRoot'] = keccak256(b'different header state')
                else: call['result']['logs'] = call['result']['logs'][1:]
                rows.append(added)
            with self.subTest(mutation=mutation), self.assertRaises(MuseumError):
                observations._group(rows)

    def test_absent_families_remain_missing_and_standalone_general_is_preserved(self):
        original = dict(self.case.canonical.files)
        absent = dossier.compose(original, self.case.canonical.manifest_hash, disclosure='public')
        self.assertEqual(set(absent.report['missingEvidence']['absentSupplementalFamilies']),
            {'production', 'general', 'transfer'})
        self.assertEqual(absent.report['requirementPromotions'], [])
        standalone = dossier.compose(original, self.case.canonical.manifest_hash,
            general_files=dict(self.case.general.files), general_hash=self.case.general.manifest_hash,
            disclosure='public')
        self.assertFalse(any(path.startswith('transfer/') for path, _ in standalone.files))
        for path, raw in self.case.general.files:
            self.assertEqual(dict(standalone.files)['general/' + path], raw)

    def test_different_valid_general_selection_cannot_replace_nested_original(self):
        original = dict(self.case.general.files)
        from . import general_semantic_dossier_v1 as general
        source = general._replay(original['sources/metadata/anchor.json'],
            original['sources/metadata/transcript.json'], original['sources/general/anchor.json'],
            original['sources/general/transcript.json'], original['semantics/transcript.json'],
            provenance='synthetic_fixture', model_root=general.MODEL_ROOT)
        policy = loads(original['inputs/selection.json']); policy['sourceAuthoritySet'] = []
        raw = dumps(policy)
        changed = general.build(source, raw, keccak256(raw), disclosure='public')
        with self.assertRaisesRegex(MuseumError, 'redundant General package differs'):
            dossier.compose(dict(self.case.canonical.files), self.case.canonical.manifest_hash,
                general_files=dict(changed.files), general_hash=changed.manifest_hash,
                transfer_files=dict(self.case.transfer.files), transfer_hash=self.case.transfer.manifest_hash,
                disclosure='public')

    def test_rehashed_derived_and_dependency_tampering_cannot_survive_replay(self):
        files = dict(self.files)
        value = loads(files['report.json'], maximum=dossier.MAX_BYTES)
        value['claims']['completeCanonicalDossier'] = True
        files['report.json'] = dumps(value)
        with self.assertRaises(MuseumError): dossier.verify(files, repin(files))
        files = dict(self.files)
        path = next(path for path in files if path.startswith('transfer/dependencies/')
            and path.endswith('validation-policy.json'))
        value = loads(files[path]); value['forgedAcceptance'] = True
        files[path] = dumps(value)
        # Rehash the nested transfer as well; its pinned original model source
        # must still reject before the envelope can claim closure equivalence.
        child = {p.removeprefix('transfer/'): raw for p, raw in files.items() if p.startswith('transfer/')}
        transfer_hash = repin(child)
        files.update({'transfer/' + p: raw for p, raw in child.items()})
        manifest = loads(files['manifest.json'], maximum=dossier.MAX_MANIFEST)
        manifest['inputs']['transfer'] = transfer_hash; files['manifest.json'] = dumps(manifest)
        with self.assertRaises(MuseumError): dossier.verify(files, repin(files))

    def test_public_preflight_external_pins_and_complete_refusal(self):
        with patch.object(dossier.canonical, 'verify', side_effect=AssertionError('source read')):
            with self.assertRaisesRegex(MuseumError, 'public disclosure'):
                dossier.compose({}, '0x' + '11' * 32, disclosure='restricted')
            with self.assertRaisesRegex(MuseumError, 'supplied together'):
                dossier.compose({}, '0x' + '11' * 32, production_files={}, disclosure='public')
        with self.assertRaisesRegex(MuseumError, 'external manifest'):
            dossier.verify(self.files, keccak256(b'wrong external pin'))
        with self.assertRaisesRegex(MuseumError, 'complete canonical dossier unavailable'):
            dossier.complete(self.files, self.result.manifest_hash)

    def test_cli_assemble_verify_and_atomic_overwrite_refusal(self):
        with TemporaryDirectory(prefix='stream-dossier-v4-cli-') as temporary:
            root = Path(temporary); args = []
            for role in ('canonical', 'production', 'general', 'transfer'):
                value = getattr(self.case, role); path = root / role
                write_tree(dict(value.files), path)
                args += ['--' + role, str(path), '--' + role + '-hash', value.manifest_hash]
            target = root / 'assembled'
            command = ['assemble', *args, '--disclosure', 'public', '--output', str(target)]
            with patch('socket.socket', side_effect=AssertionError('network used')), redirect_stdout(StringIO()):
                dossier.main(command)
                self.assertEqual(read_tree(target), self.files)
                dossier.main(['verify', str(target), '--manifest-hash', self.result.manifest_hash])
            with redirect_stderr(StringIO()), self.assertRaises(SystemExit): dossier.main(command)
            self.assertEqual(read_tree(target), self.files)

    def test_bagit_state_export_and_ocfl_exact_roundtrip_replay_nested_v4(self):
        payloads = {'v4/' + path: raw for path, raw in self.result.files}
        canonical = dict(self.case.canonical.files)
        original = loads(canonical['input/dossier/object-dossier-v3.json'], maximum=dossier.MAX_BYTES)
        description = {'mode': 'stream_bagit_input', 'version': '1', 'bundleKind': 'STATE_EXPORT',
            'sourceMode': 'synthetic_fixture', 'disclosure': 'public', 'citation': original['citation']['qualified'],
            'baggingDate': '2026-09-22',
            'bundleManifest': {'path': 'v4/manifest.json', 'hash': self.result.manifest_hash},
            'schema': {'path': 'v4/definitions/profile.json', 'id': schema_id(dossier.NAME),
                'hash': dossier.PROFILE_HASH}, 'recordChainHeads': [],
            'tool': {'name': 'Synthetic V4 integration control', 'version': '1',
                'sourceHash': keccak256(b'explicit synthetic tool reference, not an archived release')},
            'predecessor': '0x' + '00' * 32,
            'semanticPackages': [{'prefix': 'v4', 'manifestHash': self.result.manifest_hash}],
            'payloads': [{'path': path, 'bytes': str(len(raw)), 'sha256': '0x' + sha256(raw).hexdigest(),
                'keccak256': keccak256(raw), 'renderCritical': False, 'delivery': {'kind': 'embedded'}}
                for path, raw in sorted(payloads.items())]}
        bag = build_bag(dumps(description), payloads)
        self.assertFalse(loads(dict(bag.files)['stream-bagit-profile.json'])['claims']['fullDossierConformance'])
        self.assertFalse(any(loads(bag.manifest, maximum=dossier.MAX_MANIFEST)['qualification'].values()))
        with TemporaryDirectory(prefix='stream-dossier-v4-exchange-') as temporary:
            root = Path(temporary); source, target, restored = root/'bag', root/'object', root/'restored'
            write_tree(bag.files, source)
            with patch('socket.socket', side_effect=AssertionError('network used')):
                exported = export_bag(source, bag.manifest_hash, target,
                    created='2026-09-22T00:00:00Z', message='Synthetic V4 original-byte replay')
                imported = import_version(target, exported.object.inventory_hash, 'v1',
                    bag.manifest_hash, restored)
            self.assertEqual(imported['bagManifestHash'], bag.manifest_hash)
            self.assertEqual(read_tree(restored), dict(bag.files))


if __name__ == '__main__': unittest.main()
