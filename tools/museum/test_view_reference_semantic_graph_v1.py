"""Concrete native-source replays before qualified offline file-role projection."""
from copy import deepcopy
import unittest
from unittest.mock import patch

from . import view_reference_semantic_graph_v1 as graph
from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .test_view_reference_semantic_sources_v1 import supplied_raw


class ViewReferenceSemanticGraphTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw = supplied_raw(count=3, burned=True)
        with patch('socket.socket', side_effect=AssertionError('network used')):
            cls.source_report, cls.inventory = graph.sources.admit(cls.raw, keccak256(cls.raw))
            cls.files = graph.render(cls.inventory)

    def parsed(self, path):
        return loads(self.files[path], maximum=graph.MAX_OUTPUT_BYTES, canonical=True)

    def resources(self):
        return [loads(raw, canonical=True) for path, raw in self.files.items()
            if path.startswith(graph.OUTPUT_PREFIX + 'resources/')]

    def test_every_role_has_distinct_validated_digital_object(self):
        index = self.parsed(graph.INDEX_PATH)['resources']
        rows = self.inventory['rows']
        self.assertEqual(len(index), len(rows))
        self.assertEqual({row['role'] for row in rows}, set(graph.ROLE_LABELS))
        self.assertEqual([row['occurrenceId'] for row in index], [row['occurrenceId'] for row in rows])
        self.assertEqual(len({row['id'] for row in index}), len(rows))
        for item, row in zip(index, rows):
            value = loads(self.files[item['path']], canonical=True)
            self.assertEqual(value['type'], 'DigitalObject')
            self.assertEqual(value['classified_as'][0]['id'], graph.RULE + 'role:' + row['role'])
            expanded = loads(self.files[item['expandedPath']], canonical=True)
            self.assertEqual(expanded[0]['@id'], item['id'])
            self.assertIn('http://www.ics.forth.gr/isl/CRMdig/D1_Digital_Object', expanded[0]['@type'])

    def test_received_and_declared_file_occurrences_remain_separate(self):
        rows = self.inventory['rows']
        self.assertTrue(any(row['availability'] == 'received' for row in rows))
        self.assertTrue(any(row['availability'] == 'described_only' for row in rows))
        for row in rows:
            if row['role'] in ('runnable_environment_zip', 'package_member', 'os_prerequisite', 'reference_capture'):
                self.assertEqual(row['availability'], 'described_only')
                self.assertIsNone(row['byteEvidence'])
        by_hash = {}
        for row in rows:
            if row['byteEvidence'] is not None:
                by_hash.setdefault(row['byteEvidence']['keccak256'], []).append(row)
        duplicates = [group for group in by_hash.values() if len(group) > 1]
        self.assertTrue(duplicates, 'capture HTML and token HTML keep separate byte occurrences')
        for group in duplicates:
            self.assertEqual(len({graph._identifier(row['occurrenceId']) for row in group}), len(group))

    def test_role_links_subject_and_currentness_are_exact(self):
        sidecar = self.parsed(graph.SIDECAR_PATH)
        self.assertEqual(sidecar['records'], self.inventory['records'])
        self.assertEqual(sidecar['sourceState'], self.inventory['sourceState'])
        self.assertEqual(sidecar['sourceProvenance'], 'synthetic_fixture')
        self.assertEqual([entry['occurrence'] for entry in sidecar['occurrences']], self.inventory['rows'])
        relations = [entry for entry in sidecar['relations'] if 'original' in entry]
        expected = [relation for row in self.inventory['rows'] for relation in row['relations']]
        self.assertEqual([entry['original'] for entry in relations], expected)
        self.assertEqual({entry['original']['predicate'] for entry in relations}, set(graph.RELATION_ROLES))
        token_links = [entry for entry in sidecar['relations'] if 'tokenSelector' in entry]
        self.assertEqual(len(token_links), sum(row['selector']['tokenId'] is not None for row in self.inventory['rows']))
        for entry in token_links:
            self.assertFalse(entry['independentFactEstablished'])
            self.assertIn(entry['predicate'], ('reference_of_token', 'token_output'))

    def test_exact_leaf_coverage_and_per_resource_provenance(self):
        coverage = self.parsed(graph.COVERAGE_PATH)
        self.assertEqual(coverage['leaves'], self.inventory['leaves'])
        self.assertEqual([r['occurrenceId'] for r in coverage['occurrences']],
            [r['occurrenceId'] for r in self.inventory['rows']])
        actual = self.parsed(graph.PROVENANCE_PATH)
        expected = [(r['id'], pointer, value) for r in self.resources() for pointer, value in graph._leaves(r)]
        self.assertEqual([(r['resource'], r['jsonPointer'], r['value']) for r in actual], expected)
        self.assertTrue(all(r['source']['path'] == 'source/envelope.json'
            and r['source']['hash'] == keccak256(self.raw) and r['authority']
            and r['sourcePathBase'] == 'package' for r in actual))

    def test_no_unconditional_execution_derivation_or_delivery_edges(self):
        forbidden = {'produced_by', 'created_by', 'carried_out_by', 'used_specific_object',
            'derived_from', 'access_point', 'part_of', 'timespan', 'transferred_title_of', 'transferred_custody_of'}
        for resource in self.resources():
            for pointer, _ in graph._leaves(resource):
                self.assertFalse(set(pointer.split('/')) & forbidden)
            self.assertEqual(resource['type'], 'DigitalObject')
        report = self.parsed(graph.REPORT_PATH)
        for key in ('sourceInventoryVerifiedHere', 'sourceCompletenessEstablishedHere', 'retrievalFromOriginalURIProven',
                'archiveDeliveryProven', 'executionOrBrowserPerformanceProven', 'fileFormatDetected',
                'scanSafetyProven', 'personOrEventInferred', 'custodyOrLegalTitleInferred', 'derivationInferred'):
            self.assertFalse(report['claims'][key])

    def test_historical_reference_keeps_its_own_roles_without_current_byte_promotion(self):
        raw = supplied_raw(history=True)
        _, inventory = graph.sources.admit(raw, keccak256(raw))
        files = graph.render(inventory)
        sidecar = loads(files[graph.SIDECAR_PATH], maximum=graph.MAX_OUTPUT_BYTES, canonical=True)
        self.assertEqual(len(sidecar['records']), 2)
        self.assertEqual([r['selected'] for r in sidecar['records']], [False, True])
        self.assertEqual([r['currentHead'] for r in sidecar['records']], [False, True])
        historical = sidecar['records'][0]['recordId']
        old = [entry['occurrence'] for entry in sidecar['occurrences']
            if entry['occurrence']['recordId'] == historical
            and entry['occurrence']['role'] in ('token_data', 'token_json', 'token_html')]
        self.assertEqual(len(old), 3)
        self.assertTrue(all(row['availability'] == 'described_only' and row['byteEvidence'] is None
            for row in old if row['role'] in ('token_data', 'token_json')))
        for row in old:
            if row['byteEvidence'] is not None:
                self.assertEqual(row['role'], 'token_html')
                self.assertTrue(row['byteEvidence']['source']['pointer'].startswith('/inventory/value/reference/history/0/'))
        self.assertEqual(len(sidecar['occurrences']), len(inventory['rows']))

    def test_changed_occurrence_role_evidence_and_link_reject(self):
        def byte_hash(value):
            next(row for row in value['rows'] if row['role'] == 'token_json')['byteEvidence']['keccak256'] = schema_id('forged bytes')
        def relation(value):
            row = next(row for row in value['rows'] if row['relations'])
            row['relations'][0]['targetOccurrenceId'] = row['occurrenceId']
        for edit in (lambda value: value['rows'][0].update(role='invented_performance'),
                lambda value: value['rows'][0].update(occurrenceId=schema_id('different occurrence')),
                lambda value: value.update(profileHash=schema_id('other source')),
                byte_hash, relation):
            changed = deepcopy(self.inventory); edit(changed)
            with self.subTest(edit=edit), self.assertRaises(MuseumError):
                graph.render(changed)

    def test_missing_or_duplicate_inventory_entries_reject(self):
        for edit in (lambda value: value['rows'].pop(),
                lambda value: value['rows'].append(deepcopy(value['rows'][0])),
                lambda value: value['records'].append(deepcopy(value['records'][0])),
                lambda value: value['leaves'].append(deepcopy(value['leaves'][0]))):
            changed = deepcopy(self.inventory); edit(changed)
            with self.subTest(edit=edit), self.assertRaises(MuseumError):
                graph.render(changed)

    def test_deterministic_offline_profiles_bounds_and_no_input_mutation(self):
        before = dumps(self.inventory)
        with patch('socket.socket', side_effect=AssertionError('network used')):
            self.assertEqual(graph.render(self.inventory), self.files)
        self.assertEqual(dumps(self.inventory), before)
        self.assertEqual(self.files[graph.PROFILE_PATH], graph.PROFILE_BYTES)
        self.assertEqual(self.files[graph.CROSSWALK_PATH], graph.CROSSWALK_BYTES)
        self.assertEqual(keccak256(graph.CROSSWALK_BYTES), graph.CROSSWALK_HASH)
        for constant, bound in (('MAX_ROWS', 1), ('MAX_INPUT_BYTES', 1), ('MAX_OUTPUT_BYTES', 1), ('MAX_LEAVES', 1)):
            with patch.object(graph, constant, bound), self.subTest(bound=constant), self.assertRaises(MuseumError):
                graph.render(self.inventory)


if __name__ == '__main__':
    unittest.main()
