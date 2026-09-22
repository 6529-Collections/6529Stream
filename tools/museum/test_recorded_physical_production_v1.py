"""Concrete native-source Production projection, with no live-chain claims."""

from contextlib import redirect_stderr, redirect_stdout
from copy import deepcopy
from functools import lru_cache
from io import StringIO
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import recorded_physical_production_v1 as production
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .object_dossier import _ref
from .owner_notice_dossier import leaves
from .recorded_physical_production_fixture_v1 import (
    DATATYPE, EVENT_ID, OBJECT_ID, RELATION, RULE, supplied,
)


CRM = 'http://www.cidoc-crm.org/cidoc-crm/'


@lru_cache(maxsize=1)
def positive_source():
    return supplied()


@lru_cache(maxsize=1)
def positive():
    value = positive_source()
    return production.build(value['source_files'], value['source_hash'], disclosure='public')


def build_case(**kwargs):
    value = supplied(**kwargs)
    return production.build(value['source_files'], value['source_hash'], disclosure='public')


def rows(result):
    return loads(dict(result.files)['production/sidecar.json'], maximum=production.MAX_BYTES)['rows']


def resources(result):
    return {value['id']: value for path, raw in result.files
        if path.startswith('production/resources/') for value in [loads(raw)]}


def rehash(files):
    manifest = loads(files['manifest.json'], maximum=production.MAX_MANIFEST, canonical=True)
    manifest['files'] = [_ref(path, raw) for path, raw in sorted(files.items()) if path != 'manifest.json']
    files['manifest.json'] = dumps(manifest)
    return keccak256(files['manifest.json'])


def rehash_source(files):
    manifest = loads(files['manifest.json'], maximum=production.MAX_MANIFEST, canonical=True)
    manifest['files'] = [{'path': path, 'bytes': str(len(raw)), 'hash': keccak256(raw)}
        for path, raw in sorted(files.items()) if path != 'manifest.json']
    files['manifest.json'] = dumps(manifest)
    return keccak256(files['manifest.json'])


class RecordedPhysicalProductionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with patch('socket.socket', side_effect=AssertionError('network used')):
            cls.result = positive()

    def test_original_artist_statement_emits_exact_physical_production_relation(self):
        self.assertEqual((production.RELATION, production.RULE, production.DATATYPE), (RELATION, RULE, DATATYPE))
        physical = resources(self.result)[OBJECT_ID]
        self.assertEqual(physical['type'], 'HumanMadeObject')
        self.assertEqual(physical['produced_by']['id'], EVENT_ID)
        self.assertEqual(physical['produced_by']['type'], 'Production')
        path = 'production/expanded/' + keccak256(OBJECT_ID.encode())[2:] + '.json'
        expanded = loads(dict(self.result.files)[path])[0]
        self.assertEqual(expanded['@type'], [CRM + 'E22_Human-Made_Object'])
        event = expanded[CRM + 'P108i_was_produced_by'][0]
        self.assertEqual(event['@id'], EVENT_ID)
        self.assertEqual(event['@type'], [CRM + 'E12_Production'])
        self.assertEqual(self.result.report['graph']['completedObjectCount'], '1')
        self.assertEqual(rows(self.result)[0]['disposition'], 'completed_production')

    def test_original_scope_authority_and_documentary_evidence_are_retained(self):
        original = positive_source(); row = rows(self.result)[0]
        self.assertEqual(row['assertion'], original['payload']['assertions'][0])
        self.assertEqual(row['body'], original['body'])
        self.assertEqual(row['source']['authorizationClass'], 'ARTIST_SIGNER')
        self.assertEqual(row['selection']['basis'], 'historical_native_direct_statement')
        self.assertEqual(row['evidence'], original['payload']['assertions'][0]['evidence'])
        self.assertEqual(original['payload']['anchorSubject']['kind'], 'collection')
        self.assertEqual(self.result.report['sourceState'],
            loads(original['source_files']['dossier.json'], maximum=production.MAX_BYTES)['sourceState'])
        self.assertEqual(self.result.report['sourceProvenance'], 'synthetic_fixture')
        for name in ('physicalExistenceProven', 'historicalPerformanceProven', 'historicalTimeProven',
                     'namedArtistIdentityProven', 'currentSigningAuthorityGranted', 'physicalCustodyProven',
                     'legalTitleProven', 'museumAccessionProven', 'consensusProof', 'profileRegistered'):
            self.assertIs(self.result.report['claims'][name], False, name)
        graph = dumps(resources(self.result))
        for field in (b'carried_out_by', b'current_owner', b'current_custodian', b'timespan'):
            self.assertNotIn(field, graph)

    def test_planned_cancelled_and_unknown_never_become_completed_events(self):
        for status in ('planned', 'cancelled', 'unknown'):
            with self.subTest(status=status):
                result = build_case(status=status)
                self.assertEqual(resources(result), {})
                self.assertEqual(result.report['graph']['completedObjectCount'], '0')
                self.assertEqual(rows(result)[0]['disposition'], 'retained_' + status)
                self.assertEqual(rows(result)[0]['body']['status'], status)

    def test_native_disputed_withdrawn_and_unconfirmed_mapping_stay_withheld(self):
        for variant in ({'review_status': 'disputed'}, {'review_status': 'withdrawn'},
                        {'origin': 'derived_projection'}):
            with self.subTest(variant=variant):
                result = build_case(**variant)
                self.assertEqual(resources(result), {})
                self.assertEqual(rows(result)[0]['disposition'], 'source_selection_withheld')
                self.assertTrue(rows(result)[0]['reasons'])

    def test_conflicting_selected_originals_withheld_without_recency_winner(self):
        result = build_case(conflict=True)
        self.assertEqual(resources(result), {})
        self.assertEqual([row['disposition'] for row in rows(result)], ['conflict_withheld'] * 2)
        self.assertTrue(all('conflicting_selected_production_statements' in row['reasons']
            for row in rows(result)))
        native = build_case(conflict=True, single_valued=True)
        self.assertEqual(resources(native), {})
        self.assertEqual([row['disposition'] for row in rows(native)], ['source_selection_withheld'] * 2)

    def test_unselected_conflict_does_not_veto_and_remains_in_denominator(self):
        result = build_case(conflict=True, selected=[0])
        self.assertEqual(result.report['graph']['completedObjectCount'], '1')
        self.assertEqual([row['disposition'] for row in rows(result)], ['completed_production', 'unselected'])
        self.assertEqual(rows(result)[1]['assertion']['id'], 'urn:fixture:physical-production:assertion:1')

    def test_distinct_occurrence_iri_collision_and_consistent_same_occurrence_duplicates(self):
        # This first half is a pure interpretation-unit control, NOT an admitted
        # second native record.  Only the public build cases establish replay.
        dossier = loads(positive_source()['source_files']['dossier.json'], maximum=production.MAX_BYTES)
        second = deepcopy(dossier['semanticEvidence']['statements'][0])
        second['source']['recordHash'] = keccak256(b'distinct occurrence unit control')
        dossier['semanticEvidence']['statements'].append(second)
        choice = deepcopy(dossier['selection']['selected'][0])
        choice['source']['recordHash'] = second['source']['recordHash']
        dossier['selection']['selected'].append(choice)
        interpreted, _ = production._derive(dossier)
        self.assertEqual([row['disposition'] for row in interpreted], ['conflict_withheld'] * 2)
        self.assertTrue(all('selected_declaration_identity_collision' in row['reasons'] for row in interpreted))
        graph, report = production._graph(interpreted, production.validator(production.MODEL_ROOT))
        self.assertEqual(loads(graph['production/index.json'])['resources'], [])
        self.assertEqual(report['completedObjectCount'], '0')

        def duplicate_original(value):
            assertion = deepcopy(value['assertions'][0])
            assertion['id'] = 'urn:fixture:physical-production:consistent-second-assertion'
            value['assertions'].append(assertion)

        # Both original assertions below are actually embedded before native
        # hashes/events and then replayed by the public package builder.
        result = build_case(mutate_payload=duplicate_original)
        self.assertEqual(result.report['graph']['completedObjectCount'], '1')
        self.assertEqual([row['disposition'] for row in rows(result)], ['completed_production'] * 2)
        index = loads(dict(result.files)['production/index.json'])
        self.assertEqual(len(index['resources']), 1)
        self.assertEqual(len(index['resources'][0]['sources']), 2)
        self.assertEqual({source['pointer'] for source in index['resources'][0]['sources']},
            {'/assertions/0', '/assertions/1'})

    def test_matching_literal_requires_exact_closed_body_and_local_declaration_pins(self):
        mutations = [
            lambda body: body.update(extra='unsupported'),
            lambda body: body.update(status='printed'),
            lambda body: body['physicalObject'].update(pointer='/entities/00'),
            lambda body: body['physicalObject'].update(pointer='/entities/2'),
            lambda body: body['physicalObject'].update(hash=keccak256(b'unrelated declaration')),
            lambda body: body['physicalObject'].update(id=EVENT_ID),
        ]
        for index, mutate in enumerate(mutations):
            with self.subTest(index=index), self.assertRaises(MuseumError):
                build_case(mutate_body=mutate)

    def test_declared_digital_object_or_non_event_cannot_be_coerced_to_production(self):
        for variant in ({'object_kind': 'digital_object'}, {'event_kind': 'place'}):
            with self.subTest(variant=variant), self.assertRaises(MuseumError):
                build_case(**variant)
        with self.assertRaises(MuseumError):
            build_case(declaration_collision=True)

    def test_unsupported_conventions_remain_original_sidecars(self):
        variants = [
            ('relation', lambda value: value['assertions'][0].update(relation='urn:fixture:other'), 'unsupported_relation'),
            ('rule', lambda value: value['assertions'][0].update(mappingRule='urn:fixture:other'), 'unsupported_literal_convention'),
            ('datatype', lambda value: value['assertions'][0]['object']['literal'].update(datatype='urn:fixture:other'), 'unsupported_literal_convention'),
        ]
        for label, mutate, disposition in variants:
            with self.subTest(label=label):
                result = build_case(mutate_payload=mutate)
                self.assertEqual(resources(result), {})
                self.assertEqual(rows(result)[0]['disposition'], disposition)
                self.assertIsNone(rows(result)[0]['body'])

    def test_original_evidence_hash_pointer_and_declaring_account_replay_reject(self):
        variants = [
            lambda value: value['assertions'][0]['evidence'][0]['source'].update(digest=keccak256(b'not original')),
            lambda value: value['assertions'][0]['evidence'][0].update(selector='/missing'),
            lambda value: value['entities'][0].update(declaringAgent='urn:fixture:impersonated-artist'),
        ]
        for index, mutate in enumerate(variants):
            with self.subTest(index=index), self.assertRaises(MuseumError):
                supplied(mutate_payload=mutate)

    def test_rotated_current_artist_does_not_rewrite_historical_statement(self):
        result = build_case(rotated=True, disputed=True)
        row = rows(result)[0]
        self.assertEqual(row['historicalAuthority']['signer'], '0x' + (8).to_bytes(20, 'big').hex())
        self.assertNotEqual(row['historicalAuthority'], row['currentQualification'])
        self.assertEqual(row['disposition'], 'completed_production')
        self.assertFalse(result.report['claims']['currentSigningAuthorityGranted'])

    def test_original_package_and_complete_statement_leaf_coverage_are_exact(self):
        original = positive_source(); files = dict(self.result.files)
        self.assertEqual({path.removeprefix('sources/attribution/'): raw for path, raw in files.items()
            if path.startswith('sources/attribution/')}, original['source_files'])
        coverage = loads(files['production/coverage.json'], maximum=production.MAX_BYTES)
        for statement in original['snapshot']['statements']:
            expected = {(pointer, dumps(value)) for pointer, value in leaves(statement)}
            actual = {(row['pointer'], dumps(row['value'])) for row in coverage
                if row['source'] == statement['source'] and row['disposition'] == 'retained_original'}
            self.assertEqual(actual, expected)
        provenance = loads(files['production/provenance.json'], maximum=production.MAX_BYTES)
        for identity, resource in resources(self.result).items():
            self.assertEqual({(row['path'], dumps(row['value'])) for row in provenance if row['entity'] == identity},
                {(pointer, dumps(value)) for pointer, value in leaves(resource)})

    def test_rehashed_graph_sidecar_report_profile_and_coverage_tampering_rejects(self):
        original = dict(self.result.files)
        resource_path = next(path for path in original if path.startswith('production/resources/'))
        changes = {
            resource_path: lambda value: value.update(_label='invented physical object'),
            'production/sidecar.json': lambda value: value['rows'][0]['body'].update(status='planned'),
            'report.json': lambda value: value['claims'].update(physicalExistenceProven=True),
            'definitions/profile.json': lambda value: value.update(version='2'),
            'production/coverage.json': lambda value: value.pop(),
        }
        for path, edit in changes.items():
            with self.subTest(path=path):
                files = dict(original); value = loads(files[path], maximum=production.MAX_BYTES)
                edit(value); files[path] = dumps(value)
                with self.assertRaises(MuseumError): production.verify(files, rehash(files))

    def test_rehashed_source_bytes_cannot_replace_native_replayed_records(self):
        value = positive_source(); source = dict(value['source_files'])
        snapshot = loads(source['semantics/snapshot.json'], maximum=production.MAX_BYTES)
        snapshot['statements'][0]['value']['assertions'][0]['rationale'] = 'coherently repinned but not originally recorded'
        source['semantics/snapshot.json'] = dumps(snapshot)
        with self.assertRaises(MuseumError):
            production.build(source, rehash_source(source), disclosure='public')

    def test_offline_verify_uses_retained_model_only_and_rejects_bad_pin_extra_file(self):
        original_read = Path.read_bytes
        model_root = production.MODEL_ROOT.resolve()

        def retained_only(path):
            if path.resolve().is_relative_to(model_root):
                raise AssertionError('repository model fallback used')
            return original_read(path)

        with patch('socket.socket', side_effect=AssertionError('network used')), patch.object(Path, 'read_bytes', retained_only):
            result = production.verify(dict(self.result.files), self.result.manifest_hash)
        self.assertEqual(result.files, self.result.files)
        with self.assertRaises(MuseumError):
            production.verify(dict(self.result.files), keccak256(b'wrong manifest'))
        files = dict(self.result.files); files['extra.json'] = b'{}'
        with self.assertRaises(MuseumError): production.verify(files, rehash(files))

    def test_public_guard_and_cli_build_verify_no_overwrite_are_offline(self):
        with self.assertRaisesRegex(MuseumError, 'public disclosure'):
            production.build(None, None, disclosure='private')
        with TemporaryDirectory(prefix='stream-production-test-') as directory:
            base = Path(directory); source = base / 'source'; output = base / 'output'
            value = positive_source(); write_tree(value['source_files'], source)
            args = ['build', str(source), str(output), '--source-hash', value['source_hash'], '--disclosure', 'public']
            with patch('socket.socket', side_effect=AssertionError('network used')), redirect_stdout(StringIO()) as stdout:
                production.main(args)
                summary = loads(stdout.getvalue().encode())
            self.assertEqual(read_tree(source), value['source_files'])
            with patch('socket.socket', side_effect=AssertionError('network used')), redirect_stdout(StringIO()) as stdout:
                production.main(['verify', str(output), '--manifest-hash', summary['manifestHash']])
                self.assertEqual(loads(stdout.getvalue().encode())['manifestHash'], summary['manifestHash'])
            with redirect_stderr(StringIO()), self.assertRaises(SystemExit): production.main(args)


if __name__ == '__main__':
    unittest.main()
