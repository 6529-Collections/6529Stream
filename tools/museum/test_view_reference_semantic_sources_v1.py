"""Real retrieval replay and native reference occurrence controls; no verifier mocks."""
from copy import deepcopy
from functools import lru_cache
from unittest.mock import patch
import unittest

from . import view_reference_semantic_sources_v1 as source
from . import view_preservation_retrieval_fixture_v1 as fixture
from . import view_preservation_inventory_fixture_v1 as inventory_fixture
from . import test_view_preservation_retrieval_inventory_v1 as inventory_controls
from . import test_view_preservation_reference_wire_v1 as reference_controls
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id
from .native_finality_wire import from_json
from .test_view_preservation_retrieval_v1 import complete_envelope


def _historical_inventory(*args, **kwargs):
    """Rebuild actual inventory originals before the retrieval fixture uses them."""
    inventory, context, graph, witness, configuration = inventory_controls.supplied(*args, **kwargs)
    value = inventory['value']; original_context = deepcopy(value['context'])
    fixed = [{'stage': row['stage'], 'index': row['index'], 'items': deepcopy(row['items']),
        'sourceWitnessHash': row['segment'][3], 'source': deepcopy(row['source'])}
        for row in value['segments'] if 2 <= int(row['stage']) <= 6]
    references = value['reference']
    reference_controls.second_reference(references, context, graph)
    references['selectedRecordHash'] = references['history'][-1]['receipt'][1][0]
    # Lock precedes the real inventory publication; all immutable native hashes
    # and event data are recomputed rather than relabeling an admitted report.
    references['lock'][3] = '134'
    references['events'][-1]['timestamp'] = '134'
    references['events'][-1]['log'].update(blockNumber='0x22', blockHash=schema_id('semantic history block34'),
        transactionHash=schema_id('semantic history tx34'))
    reference_controls.reseal(references, context, graph)
    references['selectedRecordHash'] = references['history'][-1]['receipt'][1][0]
    inventory_fixture.set_context(value, from_json(inventory_controls.it.DESCRIPTIONS, original_context[5]),
        from_json(inventory_controls.it.CONSERVATION, original_context[6]), original_context[7])
    inventory_controls.seal(value, context, graph, fixed)
    inventory_controls.w.validate(inventory, context, graph, witness, configuration)
    return inventory, context, graph, witness, configuration


@lru_cache(maxsize=4)
def supplied_raw(count=1, burned=False, history=False):
    """Exact full synthetic source bytes, suitable for source/graph/package tests."""
    if history:
        # This swaps only fixture construction, never any production verifier.
        with patch.object(fixture, 'inventory_supplied', side_effect=_historical_inventory):
            value = complete_envelope(count=count, burned=burned)
    else:
        value = complete_envelope(count=count, burned=burned)
    return dumps(value)


class ViewReferenceSemanticSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw = supplied_raw()
        cls.checked, cls.inventory = source.admit(cls.raw, keccak256(cls.raw))

    def test_concrete_envelope_replay_and_exact_input_preserved(self):
        with patch('socket.socket', side_effect=AssertionError('unexpected network')):
            checked, result = source.admit(self.raw, keccak256(self.raw))
        self.assertEqual(checked, self.checked)
        self.assertEqual(result, self.inventory)
        self.assertEqual(checked['inputHash'], keccak256(self.raw))
        self.assertEqual(result['sourceProvenance'], 'synthetic_fixture')
        self.assertEqual(set(source.ROLES), {r['role'] for r in result['rows']})
        self.assertFalse(result['claims']['rpcProvenanceAuthenticated'])
        self.assertFalse(result['claims']['verifiedArchivalClaim'])
        self.assertEqual(dumps(loads(self.raw, maximum=source.MAX_INPUT)), self.raw)

    def test_external_pin_checked_before_concrete_verifier(self):
        # Invalid source bytes would reach a distinct native shape/JSON error.
        with self.assertRaisesRegex(MuseumError, 'external input pin'):
            source.admit(b'not JSON', schema_id('wrong external pin'))

    def test_rehashed_native_output_tamper_fails_actual_verification(self):
        value = loads(self.raw, maximum=source.MAX_INPUT)
        value['inventory']['value']['members'][0]['html'] = '0x00'
        raw = dumps(value)
        with self.assertRaises(MuseumError): source.admit(raw, keccak256(raw))

    def test_all_native_occurrences_and_duplicate_roles_keep_distinct_ids(self):
        rows = self.inventory['rows']
        members = [r for r in rows if r['role'] == 'package_member']
        self.assertEqual(len(members), 2)
        self.assertNotEqual(members[0]['occurrenceId'], members[1]['occurrenceId'])
        self.assertEqual([r['values']['index'] for r in members], ['0', '1'])
        self.assertEqual(len(rows), len({r['occurrenceId'] for r in rows}))
        self.assertEqual([r['historyIndex'] for r in [x['selector'] for x in self.inventory['records']]], ['0'])

    def test_declared_zip_and_members_are_not_received_main_artwork_bytes(self):
        self.assertTrue(self.checked['media'], 'the native envelope really includes unrelated received media')
        for row in self.inventory['rows']:
            if row['role'] in ('runnable_environment_zip', 'package_member', 'os_prerequisite', 'reference_capture'):
                self.assertEqual(row['availability'], 'described_only')
                self.assertIsNone(row['byteEvidence'])
        self.assertFalse(self.inventory['claims']['zipMemberPossessionInferred'])

    def test_received_script_and_output_bytes_resolve_exact_original(self):
        from .chain_abi import decode
        from .view_policy_adoption_types_v2 import PAYLOAD, MAX_PAYLOAD
        for row in self.inventory['rows']:
            evidence = row['byteEvidence']
            if evidence is None: continue
            original = source.resolve_reference(self.raw, evidence['source'])
            raw = hex_bytes(original)
            if evidence['derivation'] == 'abi_view_payload_script_field_4':
                raw = decode((PAYLOAD,), raw, maximum=MAX_PAYLOAD)[0][4]
            self.assertEqual(source._digest(raw), {k: evidence[k] for k in ('byteLength', 'keccak256', 'sha256')})

    def test_reference_relationships_are_typed_and_token_specific(self):
        rows = {r['occurrenceId']: r for r in self.inventory['rows']}
        found = set()
        for row in rows.values():
            for relation in row['relations']:
                found.add(relation['predicate'])
                target = rows[relation['targetOccurrenceId']]
                self.assertEqual(target['recordId'], row['recordId'])
                self.assertIsNotNone(source.resolve_reference(self.raw, relation['source']))
        self.assertEqual(found, set(source.RELATIONS))

    def test_whole_envelope_leaf_denominator_independent_walk(self):
        value = loads(self.raw, maximum=source.MAX_INPUT)
        def walk(value, pointer=''):
            if isinstance(value, dict) and value:
                return [p for key in sorted(value) for p in walk(value[key], pointer + '/' + source._escape(key))]
            if isinstance(value, list) and value:
                return [p for i, child in enumerate(value) for p in walk(child, pointer + '/' + str(i))]
            return [pointer]
        self.assertEqual(walk(value), [r['source']['pointer'] for r in self.inventory['leaves']])
        self.assertTrue(any(r['source']['pointer'].startswith('/retrieval/') for r in self.inventory['leaves']))
        self.assertTrue(any(isinstance(r['value'], dict) and 'retainedUtf8' in r['value']
            for r in self.inventory['leaves']))

    def test_pointer_aliases_and_foreign_source_pins_reject(self):
        base = self.inventory['rows'][0]['source']
        for pointer in ('/inventory/value/reference/history/-1', '/inventory/value/reference/history/00', '/~2x'):
            with self.subTest(pointer=pointer), self.assertRaises(MuseumError):
                source.resolve_reference(self.raw, {**base, 'pointer': pointer})
        with self.assertRaises(MuseumError):
            source.resolve_reference(self.raw, {**base, 'hash': schema_id('foreign raw')})

    def test_internal_inventory_rejects_relabelled_possession_and_cross_scope(self):
        for mutation in ('role', 'bytes', 'subject', 'relation', 'leaf'):
            value = deepcopy(self.inventory)
            if mutation == 'role': value['rows'][0]['role'] = 'master_file'
            elif mutation == 'bytes':
                value['rows'][2]['byteEvidence'] = deepcopy(value['rows'][0]['byteEvidence'])
                value['rows'][2]['availability'] = 'received'
            elif mutation == 'subject': value['rows'][0]['selector']['collectionId'] = '999'
            elif mutation == 'relation': value['rows'][1]['relations'][0]['targetOccurrenceId'] = value['rows'][2]['occurrenceId']
            else: value['leaves'].append(deepcopy(value['leaves'][0]))
            with self.subTest(mutation=mutation), self.assertRaises(MuseumError): source.validate_inventory(value)

    def test_burned_three_member_subject_and_full_output_denominator(self):
        raw = supplied_raw(count=3, burned=True)
        result = source.extract(raw, keccak256(raw))
        for role in ('token_data', 'token_json', 'token_html'):
            rows = [r for r in result['rows'] if r['role'] == role]
            self.assertEqual(len(rows), 3)
            self.assertEqual(len({r['selector']['tokenId'] for r in rows}), 3)
            self.assertTrue(any(r['values']['originalBurned'] for r in rows))
        self.assertEqual(sum(r['role'] == 'reference_capture' for r in result['rows']), 2)

    def test_every_historical_reference_retained_before_selected(self):
        raw = supplied_raw(history=True)
        result = source.extract(raw, keccak256(raw))
        self.assertEqual(len(result['records']), 2)
        self.assertEqual([r['selected'] for r in result['records']], [False, True])
        self.assertEqual([r['currentHead'] for r in result['records']], [False, True])
        self.assertEqual([r['revision'] for r in result['records']], ['1', '2'])
        by_record = {r['recordId']: [x for x in result['rows'] if x['recordId'] == r['recordId']]
            for r in result['records']}
        self.assertEqual([len(x) for x in by_record.values()], [11, 11])
        old = by_record[result['records'][0]['recordId']]
        self.assertTrue(all(r['availability'] == 'described_only' for r in old
            if r['role'] in ('token_data', 'token_json')))
        old_html = next(r for r in old if r['role'] == 'token_html')
        self.assertEqual(old_html['availability'], 'received')
        self.assertTrue(old_html['byteEvidence']['source']['pointer'].startswith(
            '/inventory/value/reference/history/0/publication/1/7/'))
        self.assertTrue(any(r['role'] == 'capture_html' and r['availability'] == 'received' for r in old))


if __name__ == '__main__': unittest.main()
