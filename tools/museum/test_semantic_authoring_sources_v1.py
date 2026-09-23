"""Concrete source replays for draft binding; no native execution in this suite.

Owner inputs are synthetic original-wire responses with explicitly admitted
replay provenance, not actual chain evidence. Recorded-account inputs preserve
the existing captured local-EVM package and its original environment labels.
"""
from functools import lru_cache
from pathlib import Path
import unittest
from unittest.mock import patch

from . import semantic_authoring_sources_v1 as adapter
from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .citations import canonical_citation
from .owner_record_source import OwnerRecordSource
from .recorded_semantic import RecordedSemanticSource
from .review import _selector
from .semantic_authoring import bind_later_documentation, validate_draft


@lru_cache(maxsize=1)
def owner_case():
    from .test_condition import ConditionOwnerFixture
    fixture = ConditionOwnerFixture(); source, captured, _ = fixture.replay()
    snapshot = source.snapshot()
    files = {'anchor.json': captured['anchor.json'], 'transcript.json': captured['transcript.json'], 'snapshot.json': snapshot}
    plan = {'version': '1', 'kind': 'owner_record_source', 'provenance': 'trusted_rpc',
        'anchorHash': keccak256(files['anchor.json']), 'transcriptHash': keccak256(files['transcript.json']),
        'snapshotHash': keccak256(snapshot)}
    raw = dumps(plan)
    return {'files': files, 'plan_raw': raw, 'plan_hash': keccak256(raw),
        'selection': fixture.lanes[(41, schema_id('CONDITION_REPORT'))][0],
        'citation': canonical_citation(source.a['chainId'], source.a['core'], '41')}


@lru_cache(maxsize=1)
def recorded_case():
    from .package_recorded import build_recorded_package
    from .test_package_recorded import inputs, pins
    from .test_recorded_account import ROOT, load_source
    built = build_recorded_package(inputs(), root=ROOT, disclosure='public', **pins())
    source = load_source(); capture = loads(source.capture_bytes, maximum=adapter.MAX_FILE, canonical=True)
    token_hash = next(row['recordHash'] for row in capture['records'] if row['subject'][0] == '1')
    record = next(row for row in source.state.records if row.selector.record_hash == token_hash)
    files = dict(built.files); files['manifest.json'] = built.manifest
    plan = {'version': '1', 'kind': 'recorded_account_package', 'manifestHash': built.manifest_hash,
        'sourceStateHash': source.state.commitment}
    raw = dumps(plan)
    return {'files': files, 'plan_raw': raw, 'plan_hash': keccak256(raw), 'selection': _selector(record, ''),
        'citation': canonical_citation(source.anchor['chainId'], source.anchor['core'], '71')}


def admit(case, *, files=None, plan=None, digest=None):
    raw = case['plan_raw'] if plan is None else dumps(plan)
    return adapter.admit(case['files'] if files is None else files, raw,
        (case['plan_hash'] if plan is None else keccak256(raw)) if digest is None else digest, disclosure='public')


class AuthoringSourcesTests(unittest.TestCase):
    def test_owner_concrete_source_replay_and_exact_original_references(self):
        case = owner_case(); evidence = admit(case)
        self.assertIs(type(evidence.source), OwnerRecordSource)
        self.assertEqual(evidence.source.snapshot(), case['files']['snapshot.json'])
        self.assertEqual(evidence.source_hash, loads(case['plan_raw'])['snapshotHash'])
        self.assertEqual(evidence.report['sourceMode'], 'recorded_state')
        self.assertEqual(evidence.report['sourceProvenance'], 'trusted_rpc')
        self.assertFalse(evidence.report['claims']['sourceOriginAuthenticated'])
        self.assertFalse(evidence.report['claims']['currentOwnerProven'])
        for ref in evidence.report['originals']:
            self.assertEqual(ref['keccak256'], keccak256(case['files'][ref['path'].removeprefix('source/')]))

    def test_owner_result_works_with_existing_later_documentation_binding(self):
        from .test_semantic_authoring import later_fixture
        case = owner_case(); evidence = admit(case)
        raw = bind_later_documentation(dumps(later_fixture(case['citation'])), evidence.source,
            case['selection'], source_hash=evidence.source_hash)
        checked = validate_draft(raw, source=evidence.source, source_hash=evidence.source_hash)
        self.assertEqual(checked['recordBinding']['recordHash'], case['selection'])

    def test_owner_wrong_external_pins_and_repinned_original_bytes_reject(self):
        case = owner_case()
        for key in ('anchorHash', 'transcriptHash', 'snapshotHash'):
            plan = loads(case['plan_raw']); plan[key] = schema_id('wrong ' + key)
            with self.subTest(pin=key), self.assertRaises(MuseumError): admit(case, plan=plan)
        files = dict(case['files']); snapshot = loads(files['snapshot.json'], maximum=adapter.MAX_FILE)
        snapshot['claims']['currentOwnerProven'] = True; files['snapshot.json'] = dumps(snapshot)
        plan = loads(case['plan_raw']); plan['snapshotHash'] = keccak256(files['snapshot.json'])
        with self.assertRaisesRegex(MuseumError, 'original owner replay'): admit(case, files=files, plan=plan)

    def test_owner_extra_or_omitted_files_reject(self):
        case = owner_case()
        for files in ({k: v for k, v in case['files'].items() if k != 'snapshot.json'},
                case['files'] | {'deployment-evidence.json': b'not part of this source route'}):
            with self.assertRaisesRegex(MuseumError, 'exact owner file'): admit(case, files=files)

    def test_synthetic_snapshot_and_provenance_cannot_be_promoted(self):
        case = owner_case(); plan = loads(case['plan_raw']); plan['provenance'] = 'synthetic_fixture'
        with self.assertRaisesRegex(MuseumError, 'trusted_rpc'): admit(case, plan=plan)
        files = dict(case['files']); snapshot = loads(files['snapshot.json'], maximum=adapter.MAX_FILE)
        snapshot['mode'] = 'synthetic_fixture'; files['snapshot.json'] = dumps(snapshot)
        plan = loads(case['plan_raw']); plan['snapshotHash'] = keccak256(files['snapshot.json'])
        with self.assertRaisesRegex(MuseumError, 'original owner replay'): admit(case, files=files, plan=plan)

    def test_owner_ordered_full_consumption_rejects_extra_response(self):
        case = owner_case(); files = dict(case['files'])
        transcript = loads(files['transcript.json'], maximum=adapter.MAX_FILE); transcript['calls'].append(transcript['calls'][-1])
        files['transcript.json'] = dumps(transcript)
        plan = loads(case['plan_raw']); plan['transcriptHash'] = keccak256(files['transcript.json'])
        with self.assertRaisesRegex(MuseumError, 'unconsumed'): admit(case, files=files, plan=plan)

    def test_recorded_package_replays_offline_from_retained_dependencies(self):
        from .test_recorded_account import ROOT
        case = recorded_case(); read_bytes = Path.read_bytes

        def retained_only(path):
            if path.resolve().is_relative_to(ROOT.resolve()):
                raise AssertionError('adapter read original schema directory')
            return read_bytes(path)

        with patch('socket.socket', side_effect=AssertionError('adapter attempted network')), \
                patch.object(Path, 'read_bytes', retained_only):
            evidence = admit(case)
        self.assertIs(type(evidence.source), RecordedSemanticSource)
        self.assertEqual(evidence.source_hash, loads(case['plan_raw'])['sourceStateHash'])
        self.assertEqual(evidence.report['environment'], 'local_evm_fixture')
        self.assertEqual(evidence.source.capture_bytes, case['files']['inputs/source-capture.json'])
        self.assertTrue(any(row['path'].startswith('source/dependencies/') for row in evidence.report['originals']))

    def test_recorded_result_binding_works_after_temporary_tree_cleanup(self):
        from .test_semantic_authoring import later_fixture
        case = recorded_case(); evidence = admit(case)
        raw = bind_later_documentation(dumps(later_fixture(case['citation'])), evidence.source,
            case['selection'], source_hash=evidence.source_hash)
        checked = validate_draft(raw, source=evidence.source, source_hash=evidence.source_hash)
        self.assertEqual(checked['recordBinding']['recordSelector'], case['selection'])

    def test_recorded_wrong_manifest_and_source_state_pins_reject(self):
        case = recorded_case()
        for key in ('manifestHash', 'sourceStateHash'):
            plan = loads(case['plan_raw']); plan[key] = schema_id('wrong ' + key)
            with self.subTest(pin=key), self.assertRaises(MuseumError): admit(case, plan=plan)

    def test_recorded_retained_schema_tamper_and_fixture_mode_reject(self):
        case = recorded_case(); files = dict(case['files'])
        path = next(p for p in files if p.startswith('definitions/') and p.endswith('.json'))
        files[path] += b' '
        with self.assertRaises(MuseumError): admit(case, files=files)
        files = dict(case['files']); manifest = loads(files['manifest.json'], maximum=adapter.MAX_MANIFEST)
        manifest['mode'] = 'synthetic_candidate_resource_package'; files['manifest.json'] = dumps(manifest)
        plan = loads(case['plan_raw']); plan['manifestHash'] = keccak256(files['manifest.json'])
        with self.assertRaisesRegex(MuseumError, 'unsupported recorded package'): admit(case, files=files, plan=plan)

    def test_public_guard_precedes_any_plan_or_file_access(self):
        class Forbidden(dict):
            def items(self): raise AssertionError('restricted input inspected')
        with patch.object(adapter, 'TemporaryDirectory', side_effect=AssertionError('restricted temp write')):
            with self.assertRaisesRegex(MuseumError, 'public disclosure'):
                adapter.admit(Forbidden(), None, None, disclosure='restricted')

    def test_closed_canonical_plan_and_hash_reject(self):
        case = owner_case()
        with self.assertRaises(MuseumError): admit(case, digest=schema_id('wrong plan'))
        raw = case['plan_raw'] + b' '
        with self.assertRaisesRegex(MuseumError, 'noncanonical'):
            adapter.admit(case['files'], raw, keccak256(raw), disclosure='public')
        for change in ({'version': 1}, {'kind': 'fixture_state'}, {'assertedValid': True}):
            plan = loads(case['plan_raw']) | change
            with self.subTest(change=change), self.assertRaises(MuseumError): admit(case, plan=plan)

    def test_path_aliases_and_bounded_file_maps_reject_before_temp_writes(self):
        case = recorded_case()
        for change in ({'../escape': b'x'}, {'INPUTS/anchor.json': b'x'}):
            with self.subTest(paths=change), self.assertRaises(MuseumError): admit(case, files=case['files'] | change)
        with patch.object(adapter, 'MAX_FILE', 2), patch.object(adapter, 'TemporaryDirectory',
                side_effect=AssertionError('oversized temp write')):
            with self.assertRaisesRegex(MuseumError, 'bounds'): admit(case)


if __name__ == '__main__': unittest.main()
