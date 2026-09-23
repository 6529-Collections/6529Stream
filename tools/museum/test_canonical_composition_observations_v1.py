"""Cross-family contradictions using the concrete retained retrieval fixture."""
from copy import deepcopy
import unittest

from . import canonical_composition_observations_v1 as join
from . import view_preservation_retrieval_wire_v1 as retrieval
from .canonical import MuseumError, dumps, schema_id
from .view_preservation_retrieval_fixture_v1 import supplied


class CompositionObservationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = supplied()
        f = cls.fixture
        retrieval.validate(f['retrieval'], f['context'], f['graph'], f['inventory'], f['sourceProof'])

    def setUp(self):
        f = self.fixture
        self.reference = deepcopy(f['context'])
        pins = dict(f['_shared'].pins)
        witness = f['retrieval']['witness']; pins[witness['address']] = witness['runtimeHash']
        self.native = {'name': 'retrieval', 'kind': 'native', 'context': deepcopy(f['context']),
            'runtimePins': pins, 'calls': deepcopy(f['retrieval']['sourceBindings']['calls']),
            'events': [deepcopy(f['retrieval']['records'][0]['publication'])],
            'provenance': 'synthetic_fixture'}
        call = self.native['calls'][0]
        self.rpc = {'name': 'catalogue', 'kind': 'rpc', 'anchor': deepcopy(f['context']),
            'runtimePins': {call['target']: pins[call['target']]}, 'provenance': 'synthetic_fixture',
            'transcript': {'version': 1, 'calls': [{'method': 'eth_call',
                'params': [{'to': call['target'], 'data': call['calldata'], 'gas': '0x100000'},
                    {'blockHash': f['context']['blockHash'], 'requireCanonical': True}],
                'result': call['result']}]}}

    def verify(self):
        return join.reconcile(self.reference, [self.native, self.rpc])

    def add_header(self):
        event = self.native['events'][0]; log = event['log']
        header = {'hash': log['blockHash'], 'number': log['blockNumber'],
            'timestamp': hex(int(event['timestamp'])), 'stateRoot': schema_id('retained historical root'),
            'parentHash': schema_id('retained historical parent'), 'transactions': [log['transactionHash']]}
        self.rpc['transcript']['calls'].append({'method': 'eth_getBlockByHash',
            'params': [header['hash'], False], 'result': header})
        return header

    def test_concrete_native_and_rpc_getters_join_without_mutation(self):
        before = dumps([self.native, self.rpc])
        report = self.verify()
        self.assertGreater(report['successfulGetterCount'], 50)
        self.assertEqual(report['eventOccurrences'], 1)
        self.assertFalse(report['claims']['sourceProvenanceAuthenticated'])
        self.assertEqual(dumps([self.native, self.rpc]), before)

    def test_different_gas_does_not_hide_conflicting_successful_getter(self):
        self.rpc['transcript']['calls'][0]['result'] = '0x00'
        with self.assertRaisesRegex(MuseumError, 'conflicting getter'):
            self.verify()

    def test_shared_runtime_pins_cannot_disagree(self):
        address = next(iter(self.rpc['runtimePins']))
        self.rpc['runtimePins'][address] = schema_id('different admitted runtime')
        with self.assertRaisesRegex(MuseumError, 'conflicting runtime'):
            self.verify()

    def test_undeclared_fields_stay_visible_and_declared_state_must_match(self):
        self.native['context'].pop('environment')
        self.native['context'].pop('deploymentEvidenceHash')
        report = self.verify()
        self.assertEqual(report['sources'][0]['undeclaredAnchorFields'],
            ['environment', 'deploymentEvidenceHash'])
        self.rpc['anchor']['tokenId'] = '999'
        with self.assertRaisesRegex(MuseumError, 'source state differs: tokenId'):
            self.verify()

    def test_synthetic_facts_cannot_join_an_observed_source_label(self):
        self.rpc['provenance'] = 'trusted_rpc'
        with self.assertRaisesRegex(MuseumError, 'synthetic/observed'):
            self.verify()

    def test_duplicate_event_occurrences_survive_but_coordinate_conflicts_refuse(self):
        self.native['events'].append(deepcopy(self.native['events'][0]))
        self.assertEqual(self.verify()['eventOccurrences'], 2)
        self.native['events'][1]['log']['data'] = '0x00'
        with self.assertRaisesRegex(MuseumError, 'global source/publication'):
            self.verify()

    def test_complete_query_cannot_omit_a_retained_matching_native_event(self):
        self.add_header(); log = self.native['events'][0]['log']
        query = {'method': 'eth_getLogs', 'params': [{'address': log['address'],
            'topics': [log['topics'][0]], 'fromBlock': log['blockNumber'],
            'toBlock': log['blockNumber']}], 'result': [deepcopy(log)]}
        self.rpc['transcript']['calls'].append(query)
        self.assertEqual(self.verify()['eventOccurrences'], 2)
        query['result'] = []
        with self.assertRaisesRegex(MuseumError, 'retained matching log omitted'):
            self.verify()

    def test_complete_receipt_cannot_omit_a_retained_native_event(self):
        self.add_header(); log = self.native['events'][0]['log']
        receipt = {'transactionHash': log['transactionHash'], 'blockHash': log['blockHash'],
            'blockNumber': log['blockNumber'], 'transactionIndex': log['transactionIndex'],
            'status': '0x1', 'logs': [deepcopy(log)]}
        self.rpc['transcript']['calls'].append({'method': 'eth_getTransactionReceipt',
            'params': [log['transactionHash']], 'result': receipt})
        self.assertEqual(self.verify()['eventOccurrences'], 2)
        receipt['logs'] = []
        with self.assertRaisesRegex(MuseumError, 'retained matching log omitted'):
            self.verify()

    def test_native_event_must_match_retained_rpc_header(self):
        header = self.add_header()
        self.assertEqual(self.verify()['eventOccurrences'], 1)
        header['transactions'][0] = schema_id('another header transaction')
        with self.assertRaisesRegex(MuseumError, 'event/header differs'):
            self.verify()


if __name__ == '__main__':
    unittest.main()
