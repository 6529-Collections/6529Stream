"""Focused internal-join controls, with real script source/package replay.

The small dossier filemap below is explicitly a post-verification helper input,
not a fabricated verified V4 package. The enclosing wrapper tests cover actual
V4 reconstruction. No production source/package verifier is mocked here.
"""
from copy import deepcopy
import unittest
from unittest import mock

from . import canonical_dossier_observations_v4 as original
from . import canonical_script_observations_v1 as join
from . import collection_script_source_v1 as native
from . import object_dossier as package
from . import script_dependency_rpc_v1 as rpc
from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .test_collection_script_package_v1 import build
from .test_collection_script_source_v1 import CollectionScriptFixture


def parsed(files, path):
    return loads(files[path], maximum=join.MAX_BYTES, canonical=True)


def helper_base(script_files):
    snapshot = parsed(script_files, 'source/snapshot.json')
    reference = dict(snapshot['sourceState'], tokenId='41')
    transcript = parsed(script_files, 'source/transcript.json')
    call = next(row for row in transcript['calls'] if row['method'] == 'eth_call')
    graph = snapshot['graph']
    pins = {row['address']: row['runtimeHash'] for row in graph.values()}
    row = {'name': 'original-helper', 'kind': 'native', 'context': reference,
        'runtimePins': pins, 'provenance': 'synthetic_fixture',
        'calls': [{'target': call['params'][0]['to'], 'calldata': call['params'][0]['data'],
            'result': call['result']}], 'events': []}
    configuration = {'host': graph['metadata']['address'], 'store': graph['store']['address'],
        'schemas': '0x' + 'ee' * 20, 'artistRegistry': '0x' + 'dd' * 20}
    return {'report.json': dumps({'sourceState': reference}),
        'canonical/report.json': dumps({'sourceState': reference}),
        'canonical/input/acquisition/inputs/work/metadata/anchor.json': dumps(configuration),
        'canonical/input/acquisition/source-observations.json': dumps([row])}


def base_row(files, update):
    path = 'canonical/input/acquisition/source-observations.json'
    rows = parsed(files, path)
    update(rows[0])
    files[path] = dumps(rows)


def reseal(files, *, transcript=None, anchor=None, snapshot=None):
    """Reseal helper inputs only; never a claim of real changed child replay."""
    if transcript is not None:
        files['source/transcript.json'] = dumps(transcript)
    if anchor is not None:
        files['source/anchor.json'] = dumps(anchor)
    snapshot = snapshot or parsed(files, 'source/snapshot.json')
    a = parsed(files, 'source/anchor.json')
    snapshot.update(anchorHash=keccak256(files['source/anchor.json']),
        transcriptHash=keccak256(files['source/transcript.json']),
        sourceState={key: a[key] for key in native.COMMON})
    files['source/snapshot.json'] = dumps(snapshot)


class CanonicalScriptObservationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.script = dict(build(CollectionScriptFixture())[0].files)
        cls.mismatch = dict(build(CollectionScriptFixture(mode='chunked', registry=True,
            registry_mismatch=True))[0].files)

    def setUp(self):
        self.script = dict(self.__class__.script)
        self.base = helper_base(self.script)

    def verify(self):
        return join.reconcile(self.base, self.script)

    def optional(self, kind='provider_error', code=-32000):
        a = parsed(self.script, 'source/anchor.json')
        return {'method': 'eth_call', 'params': [{'to': a['core'], 'data': '0xdeadbeef',
            'gas': '0x100000'}, {'blockHash': a['blockHash'], 'requireCanonical': True}],
            'unavailable': {'kind': kind, 'code': code}}

    def append(self, *rows):
        t = parsed(self.script, 'source/transcript.json')
        t['calls'].extend(rows)
        reseal(self.script, transcript=t)

    def event(self):
        address = parsed(self.script, 'source/anchor.json')['core']
        event = {'timestamp': '90', 'log': {'address': address,
            'blockHash': schema_id('shared historical block'), 'blockNumber': '0x20',
            'transactionHash': schema_id('shared historical tx'), 'transactionIndex': '0x0',
            'logIndex': '0x0', 'topics': [schema_id('original event')], 'data': '0x'}}
        base_row(self.base, lambda row: row['events'].append(event))
        return event

    def different_tip(self):
        a = parsed(self.script, 'source/anchor.json')
        t = parsed(self.script, 'source/transcript.json')
        old_hash, old_number = a['blockHash'], hex(int(a['blockNumber']))
        a.update(blockHash=schema_id('later script block'), blockNumber='43', timestamp='101')
        for row in t['calls']:
            method = row['method']
            if method in ('eth_call', 'eth_getCode'):
                row['params'][1]['blockHash'] = a['blockHash']
            elif method in ('eth_getBlockByHash', 'eth_getBlockByNumber'):
                if row['params'][0] in (old_hash, old_number):
                    row['params'][0] = a['blockHash'] if method == 'eth_getBlockByHash' else '0x2b'
                    row['result'].update(hash=a['blockHash'], number='0x2b', timestamp='0x65')
        reseal(self.script, transcript=t, anchor=a)

    def test_same_state_real_script_has_collection_scope_and_partial_configuration(self):
        before = (dict(self.base), dict(self.script))
        result = self.verify()
        row = result['scriptSource']
        self.assertEqual(row['status'], 'joined')
        self.assertEqual(row['scope']['kind'], 'collection')
        for value in (row['scope'], row['originalAnchor'], row['originalSourceState']):
            self.assertNotIn('tokenId', value)
        self.assertEqual(set(row['configuration']), {'metadata', 'store'})
        self.assertEqual(row['undeclaredConfiguration'], ['schemas', 'artistRegistry'])
        self.assertFalse(result['claims']['completeConfigurationEstablished'])
        shared = result['reconciliation']
        self.assertEqual(shared['profileHash'], original.PROFILE_HASH)
        self.assertEqual(shared['hash'], keccak256(dumps(shared['report'])))
        projection = result['transcriptProjection']
        self.assertEqual(projection['sourcePath'], 'scripts/source/transcript.json')
        self.assertEqual(projection['sourceReference'], package._ref(projection['sourcePath'],
            self.script[projection['sourcePath'].removeprefix('scripts/')]))
        self.assertEqual(before, (self.base, self.script))

    def test_actual_registry_runtime_mismatch_keeps_original_unavailability(self):
        self.script = dict(self.mismatch)
        self.base = helper_base(self.script)
        result = self.verify()
        snapshot = parsed(self.script, 'source/snapshot.json')
        mismatches = [row for row in snapshot['runtimeObservations'] if not row['matchesExpected']]
        self.assertTrue(mismatches)
        for row in mismatches:
            self.assertEqual(result['scriptSource']['runtimePins'][row['address']], row['observedRuntimeHash'])
            self.assertNotEqual(row['expectedRuntimeHash'], row['observedRuntimeHash'])
        t = parsed(self.script, 'source/transcript.json')
        expected = [{'transcriptIndex': i, 'row': row} for i, row in enumerate(t['calls']) if 'unavailable' in row]
        self.assertTrue(expected)
        self.assertEqual(result['unavailable'], expected)
        projection = result['transcriptProjection']
        restored = sorted(projection['projectedOriginalIndices'] + projection['unavailableOriginalIndices'])
        self.assertEqual(restored, list(range(len(t['calls']))))

    def test_all_unavailable_kinds_duplicates_and_empty_success_stay_distinct(self):
        rows = [self.optional(), self.optional('response_size', None),
            self.optional('transport_unavailable', None)]
        for index, row in enumerate(rows):
            row['params'][0]['data'] = '0xdeadbe' + str(index).zfill(2)
        empty = deepcopy(rows[0]); empty.pop('unavailable'); empty['result'] = '0x'
        empty['params'][0]['data'] = '0xdeadffff'
        self.append(*rows, deepcopy(rows[0]), empty)
        result = self.verify()
        self.assertEqual([row['row'] for row in result['unavailable']], rows + [rows[0]])
        self.assertFalse(result['claims']['unavailableMeansAbsence'])
        last = result['transcriptProjection']['originalCount'] - 1
        self.assertIn(last, result['transcriptProjection']['projectedOriginalIndices'])

    def test_unavailable_does_not_contradict_other_source_positive(self):
        t = parsed(self.script, 'source/transcript.json')
        call = next(row for row in t['calls'] if row['method'] == 'eth_call')
        call.pop('result'); call['unavailable'] = {'kind': 'provider_error', 'code': -32000}
        reseal(self.script, transcript=t)
        self.assertEqual(self.verify()['scriptSource']['status'], 'joined')

    def test_same_anchor_conflicts_cannot_hide_behind_config_provenance_or_gas(self):
        base_row(self.base, lambda row: row['calls'][0].update(result='0x00'))
        snapshot = parsed(self.script, 'source/snapshot.json')
        snapshot['provenance'] = 'trusted_rpc'
        reseal(self.script, snapshot=snapshot)
        p = 'canonical/input/acquisition/inputs/work/metadata/anchor.json'
        a = parsed(self.base, p); a['host'] = '0x' + 'ab' * 20; self.base[p] = dumps(a)
        with self.assertRaisesRegex(MuseumError, 'conflicting same-block successful getter'):
            self.verify()

    def test_observed_runtime_conflict_rejects_without_expected_pin_substitution(self):
        core = parsed(self.script, 'source/anchor.json')['core']
        base_row(self.base, lambda row: row['runtimePins'].update({core: schema_id('other runtime')}))
        with self.assertRaisesRegex(MuseumError, 'conflicting same-block runtime'):
            self.verify()

    def test_different_anchor_retains_unjoined_original_and_missing_config(self):
        self.different_tip()
        base_row(self.base, lambda row: row['calls'][0].update(result='0x00'))
        row = self.verify()['scriptSource']
        self.assertEqual(row['status'], 'unjoined')
        self.assertIn('state_differs:blockHash', row['reasons'])
        self.assertEqual(row['originalAnchor']['blockNumber'], '43')

    def test_provenance_and_configuration_difference_remain_unjoined(self):
        snapshot = parsed(self.script, 'source/snapshot.json')
        snapshot['provenance'] = 'trusted_rpc'; reseal(self.script, snapshot=snapshot)
        p = 'canonical/input/acquisition/inputs/work/metadata/anchor.json'
        a = parsed(self.base, p); a['host'] = '0x' + 'ab' * 20; self.base[p] = dumps(a)
        reasons = self.verify()['scriptSource']['reasons']
        self.assertIn('provenance_class_differs', reasons)
        self.assertIn('configuration_differs:metadata', reasons)

    def test_log_limit_retained_but_successful_matching_omission_rejects(self):
        event = self.event(); log = event['log']
        query = {'method': 'eth_getLogs', 'params': [{'address': log['address'],
            'topics': [log['topics'][0]], 'fromBlock': '0x20', 'toBlock': '0x20'}], 'limit': 'range_limit'}
        self.append(query)
        result = self.verify()
        self.assertEqual(result['reconciliation']['report']['observationEvidence'][0]['limitedQueryOccurrences'], 1)
        t = parsed(self.script, 'source/transcript.json')
        t['calls'][-1].pop('limit'); t['calls'][-1]['result'] = []; reseal(self.script, transcript=t)
        with self.assertRaisesRegex(MuseumError, 'matching retained log omitted'):
            self.verify()

    def test_historical_overlap_is_checked_across_different_tips(self):
        event = self.event(); self.different_tip()
        header = {'hash': event['log']['blockHash'], 'number': '0x20', 'timestamp': '0x5a',
            'stateRoot': schema_id('original historical state')}
        self.append({'method': 'eth_getBlockByHash', 'params': [header['hash'], False], 'result': header})
        self.assertEqual(self.verify()['scriptSource']['status'], 'unjoined')
        t = parsed(self.script, 'source/transcript.json')
        t['calls'][-1]['result']['timestamp'] = '0x5b'; reseal(self.script, transcript=t)
        with self.assertRaisesRegex(MuseumError, 'timestamp'):
            self.verify()

    def test_malformed_unavailable_and_wrong_block_and_repeated_outcomes_reject(self):
        for mutation in ('private_data', 'noncall', 'wrong_block', 'repeat'):
            with self.subTest(mutation=mutation):
                self.script = dict(self.__class__.script)
                row = self.optional()
                if mutation == 'private_data': row['unavailable']['message'] = 'must not survive'
                elif mutation == 'noncall': row.update(method='eth_getCode', params=[row['params'][0]['to'], row['params'][1]])
                elif mutation == 'wrong_block': row['params'][1]['blockHash'] = schema_id('not anchor')
                self.append(row)
                if mutation == 'repeat':
                    other = deepcopy(row); other['unavailable']['code'] = -32001; self.append(other)
                with self.assertRaises(MuseumError): self.verify()

    def test_original_snapshot_hash_graph_and_token_invention_reject(self):
        for mutation in ('hash', 'graph', 'token'):
            with self.subTest(mutation=mutation):
                self.script = dict(self.__class__.script)
                snapshot = parsed(self.script, 'source/snapshot.json')
                if mutation == 'hash': snapshot['transcriptHash'] = schema_id('wrong transcript')
                elif mutation == 'graph': snapshot['graph']['store']['runtimeHash'] = schema_id('wrong Store')
                else:
                    a = parsed(self.script, 'source/anchor.json'); a['tokenId'] = '41'
                    self.script['source/anchor.json'] = dumps(a)
                    snapshot['anchorHash'] = keccak256(self.script['source/anchor.json'])
                self.script['source/snapshot.json'] = dumps(snapshot)
                with self.assertRaises(MuseumError): self.verify()

    def test_original_unavailable_rows_count_toward_aggregate_bound(self):
        self.append(self.optional())
        count = len(parsed(self.script, 'source/transcript.json')['calls'])
        with mock.patch.object(join, 'MAX_SOURCE_ROWS', count):
            with self.assertRaisesRegex(MuseumError, 'original source row/count bound'):
                self.verify()


if __name__ == '__main__':
    unittest.main()
