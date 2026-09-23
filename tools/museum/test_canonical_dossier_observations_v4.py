"""Bounded V4 join regressions over concrete replayed retrieval observations.

These are helper controls, not additional source-admission profiles. Full child
verification and source extraction are covered by the V4 package tests.
"""
from copy import deepcopy
import unittest

from . import canonical_dossier_observations_v4 as join
from . import view_preservation_retrieval_wire_v1 as retrieval
from .canonical import MuseumError, dumps, schema_id, subject_id
from .view_preservation_retrieval_fixture_v1 import supplied


class DossierObservationV4Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = supplied()
        f = cls.fixture
        retrieval.validate(f['retrieval'], f['context'], f['graph'], f['inventory'], f['sourceProof'])

    def setUp(self):
        f = self.fixture
        self.reference = deepcopy(f['context'])
        pins = dict(f['_shared'].pins)
        witness = f['retrieval']['witness']
        pins[witness['address']] = witness['runtimeHash']
        self.native = {'name': 'base/retrieval', 'kind': 'native',
            'context': deepcopy(self.reference), 'runtimePins': pins,
            'calls': deepcopy(f['retrieval']['sourceBindings']['calls']),
            'events': [deepcopy(f['retrieval']['records'][0]['publication'])],
            'provenance': 'synthetic_fixture'}
        call = self.native['calls'][0]
        self.rpc = {'name': 'supplement/catalogue', 'kind': 'rpc',
            'anchor': deepcopy(self.reference), 'runtimePins': {call['target']: pins[call['target']]},
            'provenance': 'synthetic_fixture', 'transcript': {'version': 1, 'calls': [{
                'method': 'eth_call', 'params': [{'to': call['target'], 'data': call['calldata'],
                    'gas': '0x100000'}, {'blockHash': self.reference['blockHash'], 'requireCanonical': True}],
                'result': call['result']}]}}

    def verify(self):
        return join.reconcile(self.reference, [self.native, self.rpc])

    def header(self, *, full=True):
        event = self.native['events'][0]
        log = event['log']
        value = {'hash': log['blockHash'], 'number': log['blockNumber'],
            'timestamp': hex(int(event['timestamp'])), 'stateRoot': schema_id('retained historical root')}
        if full:
            value.update(parentHash=schema_id('retained historical parent'), transactions=[log['transactionHash']])
        self.rpc['transcript']['calls'].append({'method': 'eth_getBlockByHash',
            'params': [value['hash'], False], 'result': value})
        return value

    def receipt(self, *, failed=False):
        log = self.native['events'][0]['log']
        value = {key: log[key] for key in ('transactionHash', 'blockHash', 'blockNumber', 'transactionIndex')}
        if failed:
            value['transactionHash'] = schema_id('unrelated reverted transaction')
            value['transactionIndex'] = '0x1'
        value.update(status='0x0' if failed else '0x1', logs=[] if failed else [deepcopy(log)])
        self.rpc['transcript']['calls'].append({'method': 'eth_getTransactionReceipt',
            'params': [value['transactionHash']], 'result': value})
        return value

    def different_tip(self):
        anchor = self.rpc['anchor']
        anchor.update(blockHash=schema_id('later independent capture'),
            blockNumber=str(int(anchor['blockNumber']) + 1), timestamp=str(int(anchor['timestamp']) + 1))
        self.rpc['transcript']['calls'][0]['params'][1]['blockHash'] = anchor['blockHash']

    def test_concrete_native_and_rpc_join_without_mutation_or_authority_promotion(self):
        original = dumps([self.native, self.rpc])
        result = self.verify()
        self.assertEqual(result['joinedSourceCount'], 2)
        self.assertGreater(result['observationEvidence'][0]['successfulGetterCount'], 50)
        self.assertFalse(result['claims']['sourceOriginAuthenticated'])
        self.assertEqual(dumps([self.native, self.rpc]), original)

    def test_host_specific_deployment_evidence_does_not_change_shared_state(self):
        digest = schema_id('separately pinned host deployment evidence')
        self.rpc['anchor']['deploymentEvidenceHash'] = digest
        result = self.verify()
        self.assertEqual(result['joinedSourceCount'], 2)
        self.assertEqual(result['sources'][1]['hostDeploymentEvidenceHash'], digest)

    def test_same_anchor_getter_conflict_cannot_hide_behind_gas_config_or_provenance(self):
        self.rpc['transcript']['calls'][0]['result'] = '0x00'
        self.rpc['provenance'] = 'trusted_rpc'
        self.rpc['configuration'] = {'metadata': '0x' + '99' * 20}
        with self.assertRaisesRegex(MuseumError, 'conflicting same-block successful getter'):
            self.verify()

    def test_same_anchor_runtime_conflict_rejects(self):
        address = next(iter(self.rpc['runtimePins']))
        self.rpc['runtimePins'][address] = schema_id('conflicting runtime')
        with self.assertRaisesRegex(MuseumError, 'conflicting same-block runtime'):
            self.verify()

    def test_different_tip_retains_distinct_getter_and_unjoined_reason(self):
        self.different_tip()
        self.rpc['transcript']['calls'][0]['result'] = '0x00'
        result = self.verify()
        self.assertEqual(len(result['observationEvidence']), 2)
        self.assertEqual(result['sources'][1]['status'], 'unjoined')
        self.assertIn('state_differs:blockHash', result['sources'][1]['reasons'])

    def test_missing_fields_and_synthetic_provenance_are_explicitly_unjoined(self):
        self.rpc['anchor'].pop('stateRoot')
        self.rpc['provenance'] = 'trusted_rpc'
        result = self.verify()
        row = result['sources'][1]
        self.assertEqual(row['status'], 'unjoined')
        self.assertIn('state_undeclared:stateRoot', row['reasons'])
        self.assertIn('provenance_class_differs', row['reasons'])

    def test_partial_header_retains_missing_detail_and_accepts_consistent_full_observation(self):
        partial = self.header(full=False)
        result = self.verify()['observationEvidence'][0]
        self.assertIn(partial['hash'], result['missingObservationDetail']['headersWithoutTransactionLists'])
        full = self.header()
        self.assertNotIn(full['hash'], self.verify()['observationEvidence'][0]
            ['missingObservationDetail']['headersWithoutTransactionLists'])
        full['stateRoot'] = schema_id('contradictory same historical header')
        with self.assertRaisesRegex(MuseumError, 'conflicting.*header'):
            self.verify()

    def test_reverted_unrelated_receipt_survives_but_logs_on_failed_receipt_reject(self):
        receipt = self.receipt(failed=True)
        result = self.verify()['observationEvidence'][0]
        self.assertEqual(result['failedReceiptOccurrences'], 1)
        self.assertIn(receipt['blockHash'], result['missingObservationDetail']['receiptBlocksWithoutObservedHeaders'])
        receipt['logs'] = [deepcopy(self.native['events'][0]['log'])]
        with self.assertRaisesRegex(MuseumError, 'failed receipt'):
            self.verify()

    def test_retained_matching_event_cannot_disappear_from_successful_query(self):
        log = self.native['events'][0]['log']
        self.rpc['transcript']['calls'].append({'method': 'eth_getLogs', 'params': [{
            'address': log['address'], 'topics': [log['topics'][0]],
            'fromBlock': log['blockNumber'], 'toBlock': log['blockNumber']}], 'result': []})
        with self.assertRaisesRegex(MuseumError, 'matching retained log omitted'):
            self.verify()

    def test_limit_does_not_claim_positive_empty_result(self):
        log = self.native['events'][0]['log']
        self.rpc['transcript']['calls'].append({'method': 'eth_getLogs', 'params': [{
            'address': log['address'], 'topics': [log['topics'][0]],
            'fromBlock': log['blockNumber'], 'toBlock': log['blockNumber']}], 'limit': 'range_limit'})
        self.assertEqual(self.verify()['observationEvidence'][0]['limitedQueryOccurrences'], 1)

    def test_retained_event_cannot_disappear_from_observed_receipt(self):
        receipt = self.receipt()
        self.verify()
        receipt['logs'] = []
        with self.assertRaisesRegex(MuseumError, 'matching retained log omitted'):
            self.verify()

    def test_duplicate_occurrences_retained_and_conflicting_event_coordinates_reject(self):
        self.native['events'].append(deepcopy(self.native['events'][0]))
        self.assertEqual(self.verify()['observationEvidence'][0]['eventOccurrences'], 2)
        self.native['events'][1]['log']['data'] = '0x00'
        with self.assertRaisesRegex(MuseumError, 'conflicting.*event'):
            self.verify()

    def test_different_tips_cannot_hide_same_historical_block_event_contradiction(self):
        self.different_tip()
        receipt = self.receipt()
        receipt['logs'][0]['data'] = '0x00'
        with self.assertRaisesRegex(MuseumError, 'conflicting'):
            self.verify()

    def test_cross_tip_header_must_agree_with_actual_native_event_timestamp(self):
        self.different_tip()
        header = self.header(full=False)
        header['timestamp'] = hex(int(header['timestamp'], 16) - 1)
        with self.assertRaisesRegex(MuseumError, 'timestamp'):
            self.verify()

    def test_token_subject_preimage_is_distinct_from_collection_and_media_scope(self):
        # Minimal post-verification subject rows exercise only this helper's
        # adaptation contract; no source/package verifier is mocked.
        anchor = deepcopy(self.reference)
        chain, core, collection = (anchor[key] for key in ('chainId', 'core', 'collectionId'))
        cases = [
            ('token', self.reference['tokenId'], None, 'exact_token_subject'),
            ('token', '999', None, 'different_token_subject'),
            ('collection', None, None, 'collection_documentary_scope'),
            ('media', None, schema_id('original media identity'), 'media_documentary_scope')]
        for kind, token, object_id, expected in cases:
            with self.subTest(kind=kind, token=token):
                sid = subject_id(kind, chain, core, collection, token_id=token, object_id=object_id)
                record = schema_id('original ' + expected)
                selector = {'recordHash': record, 'host': '0x' + '55' * 20, 'pointer': '/assertions/0'}
                statement = {'source': dict(selector, pointer=''), 'status': 'supported',
                    'value': {'anchorSubject': {'kind': kind, 'subjectId': sid}, 'assertions': [{}]},
                    'original': {'subject': [str(('collection', 'token', 'media').index(kind)),
                        collection, token or '0', object_id or '0x' + '00' * 32]}}
                files = {'sources/general/anchor.json': dumps(anchor),
                    'semantics/snapshot.json': dumps({'statements': [statement]}),
                    'graph/selection.json': dumps({'selected': [{'source': selector}], 'withheld': []})}
                result = join.subjects(self.reference, general_files=files)
                self.assertEqual(result[0]['status'], expected)
                self.assertFalse(result[0]['tokenAuthorityEstablished'])
                files['graph/selection.json'] = dumps({'selected': [], 'withheld': [{'source': selector}]})
                withheld = join.subjects(self.reference, general_files=files)[0]
                self.assertEqual(withheld['status'], expected)
                self.assertEqual(withheld['selectionDisposition'], 'withheld')
                self.assertFalse(withheld['tokenAuthorityEstablished'])
                wrong_selector = dict(selector, host='0x' + '66' * 20)
                files['graph/selection.json'] = dumps({'selected': [{'source': wrong_selector}], 'withheld': []})
                with self.assertRaises(MuseumError):
                    join.subjects(self.reference, general_files=files)
                files['graph/selection.json'] = dumps({'selected': [{'source': selector}], 'withheld': []})
                statement['original']['subject'][1] = str(int(collection) + 1)
                files['semantics/snapshot.json'] = dumps({'statements': [statement]})
                with self.assertRaisesRegex(MuseumError, 'original subject preimage differs'):
                    join.subjects(self.reference, general_files=files)


if __name__ == '__main__':
    unittest.main()
