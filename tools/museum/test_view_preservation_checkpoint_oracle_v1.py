"""Native extracted vectors; no renderer/EVM/network is invoked by these tests."""
from pathlib import Path
import socket
import unittest
from unittest.mock import patch

from . import view_preservation_checkpoint_oracle_v1 as oracle
from . import view_preservation_output_types_v1 as t
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .chain_abi import decode, encode
from .independent_wire import json_values

VECTOR = Path(__file__).with_name('fixtures') / 'view-preservation-native-checkpoint-v1.json'
VECTOR_HASH = '0xc080e330b93552e3953dd268d5904b5e2f3b9c69107a83ffd78484a001a37917'
TRACE = Path('D:/repos/6529Stream/.tmp-view-preservation-wire-traces3/checkpoint.log')


def supplied():
    return loads(VECTOR.read_bytes(), maximum=oracle.MAX_VECTOR, canonical=True)


def replace_return(value, name, index, body):
    row = value['returns'][name][index]
    row['hex'] = '0x' + body.hex()
    for item in row['occurrences']:
        item['length'] = str(len(row['hex']))


def replace_event(row, old, new):
    row['text'] = row['text'].replace(old, new)
    row['length'] = str(len(row['text'].encode('utf-8')))


class ViewPreservationCheckpointOracleTests(unittest.TestCase):
    def test_committed_native_vector_pin_and_complete_three_row_commitments(self):
        raw = VECTOR.read_bytes()
        self.assertEqual(keccak256(raw), VECTOR_HASH)
        report = oracle.verify_vector(raw)
        self.assertEqual(report['tokenIds'], ['11', '22', '33'])
        self.assertEqual(report['retainedBurnedTokenIds'], ['33'])
        self.assertEqual(report['rowAbiBytes'], '992')
        self.assertEqual(report['sourceAbiBytes'], '3712')
        self.assertEqual(report['sourceOccurrences'], '6')
        self.assertEqual(report['rowObservationOccurrences'], ['3', '3', '3'])
        self.assertEqual(report['checkpointId'], '0xcf8407daeba4cac330713ef38712daa38755ea59886663cf440bd9a6e72d42b3')
        self.assertEqual(report['outputRoot'], '0x1054589f1f3159d3e2f0d1fbf46e13f910274c5d8c73b5fa51290b5eae81100d')
        self.assertEqual(report['contentRoot'], '0xc3e87fd0118389860d339d2b906c81e60dbb62718f937472253c2b69762a3279')

    @unittest.skipUnless(TRACE.is_file(), 'original external native trace is not present on this host')
    def test_original_trace_reextracts_exact_vector_and_every_retained_byte_span(self):
        raw = TRACE.read_bytes()
        self.assertEqual(oracle.extract_trace(raw), VECTOR.read_bytes())
        self.assertTrue(oracle.verify_trace(raw)['claims']['rawTraceRechecked'])
        value = supplied()
        for rows in value['returns'].values():
            for row in rows:
                for item in row['occurrences']:
                    start, size = int(item['start']), int(item['length'])
                    self.assertEqual(raw[start:start+size], row['hex'].encode('ascii'))
        for rows in [value['checkpointDeployment'], value['producerDeployment'], *value['events'].values()]:
            for row in rows:
                start, size = int(row['start']), int(row['length'])
                self.assertEqual(raw[start:start+size], row['text'].encode('utf-8'))

    def test_raw_trace_pin_is_required_before_decoded_evidence(self):
        for raw in (b'', b'No files changed\n[PASS] ' + oracle.TEST.encode()):
            with self.assertRaisesRegex(MuseumError, 'trace SHA-256/size'):
                oracle.verify_trace(raw)

    def test_parser_pairs_library_frame_and_rejects_pretty_printed_structs(self):
        raw = ('    ├─ [4] Library::source() [delegatecall]\n'
               '    │   ├─ [2] Other::nested() [staticcall]\n'
               '    │   │   └─ ← [Return] 0x02\n'
               '    │   └─ ← [Return] 0x01\n').encode('utf-8')
        self.assertEqual(oracle._returns(oracle._lines(raw), 'Library::source()')[0]['hex'], '0x01')
        with self.assertRaisesRegex(MuseumError, 'raw returndata required'):
            oracle._returns(oracle._lines(raw.replace(b'0x01', b'Plan({ collectionId: 4 })')), 'Library::source()')

    def test_native_scope_source_record_mutation_does_not_hide_behind_context_hash(self):
        v = supplied()
        s = json_values(decode((t.SOURCE,), hex_bytes(v['returns']['source'][0]['hex']))[0])
        s[0][9] = '0x' + 'ab' * 32
        replace_return(v, 'source', 0, encode((t.SOURCE,), (oracle.wire._v(t.SOURCE, s),)))
        with self.assertRaisesRegex(MuseumError, 'adoption source/record hashes'):
            oracle.verify_vector(dumps(v))

    def test_native_source_context_and_producer_admission_join(self):
        for field in ('context', 'admission'):
            v = supplied()
            s = json_values(decode((t.SOURCE,), hex_bytes(v['returns']['source'][0]['hex']))[0])
            if field == 'context': s[4] = '0x' + 'ab' * 32
            else: s[3][2] = '0x' + 'ab' * 32
            replace_return(v, 'source', 0, encode((t.SOURCE,), (oracle.wire._v(t.SOURCE, s),)))
            with self.assertRaisesRegex(MuseumError, 'context hash|producer/admission binding'):
                oracle.verify_vector(dumps(v))

    def test_actual_json_and_html_bytes_match_both_hashes_and_lengths(self):
        for index in (1, 2):
            v = supplied()
            observed = list(decode((t.OUTPUT, 'bytes', 'bytes'), hex_bytes(v['returns']['observation'][0]['hex'])))
            observed[index] += b'!'
            replace_return(v, 'observation', 0, encode((t.OUTPUT, 'bytes', 'bytes'), tuple(observed)))
            with self.assertRaisesRegex(MuseumError, 'JSON/HTML bytes differ'):
                oracle.verify_vector(dumps(v))

    def test_full_output_row_not_only_json_hash_is_bound_by_native_event(self):
        v = supplied()
        row, js, html = decode((t.OUTPUT, 'bytes', 'bytes'), hex_bytes(v['returns']['observation'][1]['hex']))
        row = list(row); row[2] += 1
        replace_return(v, 'observation', 1, encode((t.OUTPUT, 'bytes', 'bytes'), (tuple(row), js, html)))
        with self.assertRaisesRegex(MuseumError, 'appended row hash'):
            oracle.verify_vector(dumps(v))

    def test_missing_or_reordered_original_rows_fail(self):
        for missing in (False, True):
            v = supplied()
            if missing: v['returns']['observation'].pop()
            else: v['returns']['observation'].reverse()
            with self.assertRaisesRegex(MuseumError, 'denominator|complete ordered rows'):
                oracle.verify_vector(dumps(v))

    def test_exact_abi_rejects_trailing_bytes_and_old_source_shape(self):
        for group, remove in (('observation', False), ('source', True)):
            v = supplied(); raw = hex_bytes(v['returns'][group][0]['hex'])
            replace_return(v, group, 0, raw[:-32] if remove else raw + bytes(32))
            with self.assertRaises(MuseumError):
                oracle.verify_vector(dumps(v))

    def test_checkpoint_id_binds_configuration_hash_and_salt(self):
        for mutation in ('configuration', 'salt'):
            v = supplied()
            if mutation == 'configuration': replace_return(v, 'checkpointConfigurationHash', 0, bytes.fromhex('ab' * 32))
            else:
                row = v['events']['started'][0]
                replace_event(row, '0xb1242cdc150a29797dcff3b70a6a302ebabb6000acb119bd48ade7dc097476cc', '0x' + 'ab' * 32)
            with self.assertRaisesRegex(MuseumError, 'native checkpoint ID'):
                oracle.verify_vector(dumps(v))

    def test_native_content_root_and_row_chain_root_are_distinct_commitments(self):
        result = oracle.verify_vector(VECTOR.read_bytes())
        for name in ('contentRoot', 'outputRoot'):
            v = supplied(); row = v['events']['sealed'][0]
            replace_event(row, result[name], '0x' + 'ab' * 32)
            with self.assertRaisesRegex(MuseumError, 'native ' + ('contentRoot' if name == 'contentRoot' else 'outputRoot')):
                oracle.verify_vector(dumps(v))

    def test_provenance_spans_and_fixed_fixture_inputs_are_closed(self):
        for mutate in ('span', 'fixture', 'revision'):
            v = supplied()
            if mutate == 'span': v['returns']['source'][0]['occurrences'][0]['start'] = str(oracle.TRACE_BYTES)
            elif mutate == 'fixture': v['fixtureConfiguration']['readGas'] = '1'
            else: v['nativeSourceRevision'] = oracle.CONSUMER_REVISION
            with self.assertRaisesRegex(MuseumError, 'byte span|provenance/configuration pins'):
                oracle.verify_vector(dumps(v))

    def test_offline_and_no_snapshot_root_or_registry_admission_claim(self):
        with patch.object(socket, 'socket', side_effect=AssertionError('network forbidden')):
            report = oracle.verify_vector(VECTOR.read_bytes())
        self.assertTrue(report['claims']['nativeJSONHTMLBytesHashMatched'])
        self.assertFalse(report['claims']['rawTraceRechecked'])
        for key in ('rawCheckpointConfigurationCaptured', 'rawCheckpointPlanCaptured',
                'nativePreservationRegistryRegistrationProven', 'snapshotVerified', 'routerRootVerified',
                'completeGraphVerified', 'deploymentOrConsensusVerified', 'completePacket'):
            self.assertFalse(report['claims'][key])


if __name__ == '__main__':
    unittest.main()
