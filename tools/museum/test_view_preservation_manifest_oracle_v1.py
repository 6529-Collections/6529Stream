"""Native manifest vectors; no compiler, EVM or network is required."""
from pathlib import Path
import socket
import unittest
from unittest.mock import patch

from . import view_preservation_manifest_oracle_v1 as oracle
from . import view_preservation_output_types_v1 as t
from .canonical import MuseumError, dumps, hex_bytes, loads
from .chain_abi import decode, encode

VECTOR = Path(__file__).with_name('fixtures') / 'view-preservation-native-manifest-v1.json'
TRACE = Path('D:/repos/6529Stream/.tmp-view-preservation-wire-traces3/manifest.log')


def supplied():
    return loads(VECTOR.read_bytes(), maximum=oracle.MAX_VECTOR, canonical=True)


def replace_bytes(value, field, body):
    value[field] = '0x' + body.hex()


class ViewPreservationManifestOracleTests(unittest.TestCase):
    def test_native_part_index_descriptor_and_emitted_hashes(self):
        report = oracle.verify_vector(VECTOR.read_bytes())
        self.assertEqual(report['partBytes'], '3648')
        self.assertEqual(report['indexBytes'], '960')
        self.assertEqual(report['recordHash'], '0x3b9432e57983f7524efd33147b193d61071c23d1956d0317440765a0b949d49c')
        self.assertEqual(report['partContentHash'], '0x682a992b01dee3329b3468663d80444513e8a8e497b0f25a32310bcb6432345d')
        self.assertEqual(report['indexContentHash'], '0x0e45f3672bc0166bd809a2e3dca2ccd5847aab31227a598f9972af91028031cc')
        self.assertTrue(report['emptyDescriptorPreviewChecked'])

    @unittest.skipUnless(TRACE.is_file(), 'original external trace is not present on this host')
    def test_original_trace_reextracts_exact_committed_vector(self):
        raw = TRACE.read_bytes()
        self.assertEqual(oracle.extract_trace(raw), VECTOR.read_bytes())
        self.assertTrue(oracle.verify_trace(raw)['rawTraceRechecked'])

    def test_external_trace_authentication_precedes_parsing(self):
        with self.assertRaisesRegex(MuseumError, 'external trace pin/bound'):
            oracle.verify_trace(b'No files changed, compilation skipped\n1 tests passed, 0 failed')

    def test_actual_store_bytes_must_equal_production_encoding(self):
        for slot in (0, 1):
            value = supplied(); value['storePayloads'][slot] += '00'
            with self.assertRaisesRegex(MuseumError, 'Store payload differs'):
                oracle.verify_vector(dumps(value))

    def test_raw_carrier_content_must_match_encoding_and_store(self):
        for slot in (0, 1):
            value = supplied()
            carrier, body = decode((t.CARRIER, 'bytes'), hex_bytes(value['carrierReturns'][slot]))
            value['carrierReturns'][slot] = '0x' + encode((t.CARRIER, 'bytes'), (carrier, body[:-1]+b'!')).hex()
            with self.assertRaisesRegex(MuseumError, 'carrier raw bytes differ'):
                oracle.verify_vector(dumps(value))

    def test_complete_index_cannot_be_replaced_by_initial_empty_preview(self):
        value = supplied(); value['indexReturns'].reverse()
        with self.assertRaisesRegex(MuseumError, 'Store payload differs'):
            oracle.verify_vector(dumps(value))

    def test_initial_preview_must_have_same_header_and_zero_descriptors(self):
        value = supplied(); value['indexReturns'][1] = value['indexReturns'][0]
        with self.assertRaisesRegex(MuseumError, 'empty-descriptor preview differs'):
            oracle.verify_vector(dumps(value))

    def test_full_row_bytes_are_checked_against_part_payload(self):
        value = supplied(); body = bytearray(hex_bytes(value['rowsReturn'])); body[-1] ^= 1
        replace_bytes(value, 'rowsReturn', bytes(body))
        with self.assertRaisesRegex(MuseumError, 'header/row bytes differ'):
            oracle.verify_vector(dumps(value))

    def test_native_part_preimage_binds_host_configuration_and_carrier(self):
        for mutation in ('configuration', 'host', 'carrier'):
            value = supplied()
            if mutation == 'configuration': value['configurationHashReturn'] = '0x' + 'ab'*32
            elif mutation == 'host':
                for log in value['logs']: log['address'] = '0x'+'ab'*20
            else:
                carrier, body = decode((t.CARRIER, 'bytes'), hex_bytes(value['carrierReturns'][0]))
                carrier = list(carrier); carrier[0] = '0x'+'ab'*32
                value['carrierReturns'][0] = '0x'+encode((t.CARRIER, 'bytes'), (tuple(carrier), body)).hex()
            with self.assertRaisesRegex(MuseumError, 'part hash/descriptor differs'):
                oracle.verify_vector(dumps(value))

    def test_native_raw_event_topics_data_and_final_record_are_checked(self):
        for mutation in ('signature', 'data', 'record', 'plan'):
            value = supplied()
            if mutation == 'signature': value['logs'][0]['topics'][0] = '0x'+'ab'*32
            elif mutation == 'data': value['logs'][1]['data'] = '0x00'
            elif mutation == 'record': value['logs'][1]['topics'][1] = '0x'+'ab'*32
            else:
                value['logs'][0]['topics'][1] = value['logs'][1]['topics'][2] = '0x'+'ab'*32
            with self.assertRaisesRegex(MuseumError, 'raw event ABI|record hash differs'):
                oracle.verify_vector(dumps(value))

    def test_exact_abi_rejects_trailing_return_bytes(self):
        for field in ('partReturn', 'headerReturn', 'rowsReturn'):
            value = supplied(); value[field] += '00'*32
            with self.assertRaises(MuseumError): oracle.verify_vector(dumps(value))

    def test_provenance_line_groups_counts_bounds_and_order(self):
        for mutation in ('groups', 'count', 'bound', 'zero', 'order'):
            value = supplied()
            if mutation == 'groups': value['lineNumbers'] = {'invented': ['999999999']}
            elif mutation == 'count': value['lineNumbers']['partReturn'].pop()
            elif mutation == 'bound': value['lineNumbers']['partReturn'][1] = '999999999'
            elif mutation == 'zero': value['lineNumbers']['partReturn'][0] = '0'
            else: value['lineNumbers']['partReturn'].reverse()
            with self.assertRaisesRegex(MuseumError, 'provenance line'):
                oracle.verify_vector(dumps(value))

    def test_offline_vector_claims_do_not_imply_original_trace_or_full_capture(self):
        with patch.object(socket, 'socket', side_effect=AssertionError('network forbidden')):
            report = oracle.verify_vector(VECTOR.read_bytes())
        self.assertFalse(report['rawTraceRechecked'])
        self.assertFalse(report['fullConsumerCaptureVerified'])
        self.assertFalse(report['nativeSnapshotRootOrFinalityVerified'])


if __name__ == '__main__':
    unittest.main()
