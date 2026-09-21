"""No live RPC: exact fake HTTP/record/replay availability boundaries."""
from copy import deepcopy
import http.client
import io
import traceback
import unittest
import urllib.error
from unittest.mock import patch

from . import script_dependency_rpc_v1 as rpc
from .canonical import MuseumError, dumps, keccak256, loads


def H(n): return '0x' + format(n, '064x')
def A(n): return '0x' + format(n, '040x')
BLOCK = {'blockHash': H(9), 'requireCanonical': True}
CALL = [{'to': A(1), 'data': '0x12345678', 'gas': '0x1312d00'}, BLOCK]
LOGS = [{'address': A(1), 'topics': [H(1)], 'fromBlock': '0x0', 'toBlock': '0x9'}]


class Transport:
    def __init__(self, result): self.result = result
    def request(self, method, params):
        if isinstance(self.result, Exception): raise self.result
        return deepcopy(self.result)


def recorded(outcome):
    reader = rpc.RecordingReader(Transport(outcome), H(9))
    result = reader.call_outcome(A(1), '0x12345678')
    return reader, result


class ScriptDependencyRpcTests(unittest.TestCase):
    def test_available_and_empty_bytes_are_preserved_exactly(self):
        for value in ('0x', '0x1234'):
            with self.subTest(value=value):
                reader, outcome = recorded(value)
                self.assertEqual(outcome, {'status': 'available', 'result': value})
                raw = reader.transcript()
                self.assertEqual(loads(raw)['calls'], [{'method': 'eth_call', 'params': CALL, 'result': value}])
                replay = rpc.ReplayTransport(raw, keccak256(raw))
                again = rpc.RecordingReader(replay, H(9))
                with patch('socket.socket', side_effect=AssertionError('network used')):
                    self.assertEqual(again.call_outcome(A(1), '0x12345678'), outcome)
                    replay.finish()
                self.assertEqual(again.transcript(), raw)

    def test_unavailable_variants_record_replay_and_mandatory_call_refusal(self):
        for kind, code in (('provider_error', -32000), ('response_size', None), ('transport_unavailable', None)):
            with self.subTest(kind=kind):
                reader, outcome = recorded(rpc.CallUnavailable(kind, code))
                self.assertEqual(outcome, {'status': 'unavailable', 'kind': kind, 'code': code})
                raw = reader.transcript()
                self.assertEqual(loads(raw)['calls'][0]['unavailable'], {'kind': kind, 'code': code})
                replay = rpc.ReplayTransport(raw, keccak256(raw))
                again = rpc.RecordingReader(replay, H(9))
                with self.assertRaises(rpc.CallUnavailable): again.call(A(1), '0x12345678')
                replay.finish()
                self.assertEqual(again.transcript(), raw)

    def test_unavailable_is_only_permitted_for_eth_call(self):
        for method, params in (('eth_chainId', []), ('eth_getCode', [A(1), BLOCK]),
                ('eth_getBlockByHash', [H(9), False]), ('eth_getLogs', LOGS)):
            reader = rpc.RecordingReader(Transport(rpc.CallUnavailable('transport_unavailable')), H(9))
            with self.subTest(method=method), self.assertRaisesRegex(MuseumError, 'outside eth_call'):
                reader.request(method, params)
            self.assertEqual(reader.rows, [])
        reader, _ = recorded(rpc.CallUnavailable('provider_error', -1))
        value = loads(reader.transcript())
        value['calls'][0].update(method='eth_getCode', params=[A(1), BLOCK])
        raw = dumps(value)
        with self.assertRaisesRegex(MuseumError, 'outside eth_call'): rpc.ReplayTransport(raw, keccak256(raw))

    def test_repeated_calls_must_keep_exact_success_or_failure_outcome(self):
        for first, second in (('0x', rpc.CallUnavailable('provider_error', -1)),
                (rpc.CallUnavailable('provider_error', -1), rpc.CallUnavailable('provider_error', -2)),
                (rpc.CallUnavailable('transport_unavailable'), '0x')):
            transport = Transport(first)
            reader = rpc.RecordingReader(transport, H(9))
            reader.call_outcome(A(1), '0x12345678')
            transport.result = second
            with self.assertRaisesRegex(MuseumError, 'repeated RPC outcome'): reader.call_outcome(A(1), '0x12345678')
            self.assertEqual(len(reader.rows), 1)
        value = loads(recorded('0x')[0].transcript())
        row = deepcopy(value['calls'][0]); row['result'] = '0x01'; value['calls'].append(row)
        raw = dumps(value)
        with self.assertRaisesRegex(MuseumError, 'repeated RPC outcome'): rpc.ReplayTransport(raw, keccak256(raw))

    def test_unknown_exceptions_and_malformed_success_never_become_unavailable(self):
        for value in (MuseumError('hard source failure'), None, '0x0', '0xAA', {'result': '0x'}):
            reader = rpc.RecordingReader(Transport(value), H(9))
            with self.subTest(value=type(value).__name__), self.assertRaises(MuseumError):
                reader.call_outcome(A(1), '0x12345678')
            self.assertEqual(reader.rows, [])

    def test_endpoint_params_and_boundaries_fail_before_transport(self):
        with self.assertRaises(MuseumError): rpc.RpcTransport('http://example.invalid/private')
        reader = rpc.RecordingReader(Transport('0x'), H(9))
        malformed = deepcopy(CALL); malformed[1]['requireCanonical'] = False
        for method, params in (('eth_sendRawTransaction', []), ('eth_call', [CALL[0], 'latest']),
                ('eth_call', malformed), ('eth_getBlockByNumber', ['latest', False]),
                ('eth_call', [{'to': A(1), 'data': '0x', 'gas': '0x00'}, BLOCK])):
            with self.subTest(method=method), self.assertRaises(MuseumError): reader.request(method, params)
        self.assertEqual(reader.rows, [])
        with patch.object(rpc, 'MAX_REQUEST', 32), self.assertRaisesRegex(MuseumError, 'request byte bound'):
            reader.call(A(1), '0x')
        with patch.object(rpc, 'MAX_CALLS', 1):
            reader.call(A(1), '0x')
            with self.assertRaisesRegex(MuseumError, 'call bound'): reader.call(A(1), '0x')

    def test_only_provider_error_code_is_retained_and_traceback_is_sanitized(self):
        secret = 'PRIVATE_PROVIDER_MESSAGE_DATA_ENDPOINT'
        transport = rpc.RpcTransport('https://example.invalid/' + secret)
        raw = dumps({'jsonrpc': '2.0', 'id': 1,
            'error': {'code': -32005, 'message': secret, 'data': {'private': secret}}})
        with patch.object(rpc.urllib.request, 'build_opener') as opener:
            opener.return_value.open.return_value = io.BytesIO(raw)
            reader = rpc.RecordingReader(transport, H(9))
            try:
                reader.call(A(1), '0x12345678')
            except rpc.CallUnavailable as exc:
                self.assertEqual((exc.kind, exc.code), ('provider_error', -32005))
                self.assertNotIn(secret, ''.join(traceback.format_exception(exc)))
            else: self.fail('unavailable mandatory call accepted')
        self.assertNotIn(secret.encode(), reader.transcript())
        self.assertEqual(loads(reader.transcript())['calls'][0]['unavailable'], {'kind': 'provider_error', 'code': -32005})

    def test_fake_http_errors_and_response_size_are_distinguished(self):
        secret = 'PRIVATE_HTTP_PAYLOAD'
        failures = ((urllib.error.HTTPError(secret, 413, secret, {}, None), 'response_size'),
            (urllib.error.HTTPError(secret, 500, secret, {}, None), 'transport_unavailable'),
            (urllib.error.URLError(secret), 'transport_unavailable'),
            (http.client.BadStatusLine(secret), 'transport_unavailable'),
            (TimeoutError(secret), 'transport_unavailable'))
        for failure, kind in failures:
            with self.subTest(kind=type(failure).__name__), patch.object(rpc.urllib.request, 'build_opener') as opener:
                opener.return_value.open.side_effect = failure
                reader = rpc.RecordingReader(rpc.RpcTransport('https://example.invalid/' + secret), H(9))
                self.assertEqual(reader.call_outcome(A(1), '0x12345678'), {'status': 'unavailable', 'kind': kind, 'code': None})
                self.assertNotIn(secret.encode(), reader.transcript())
        with patch.object(rpc.urllib.request, 'build_opener') as opener:
            response = unittest.mock.Mock()
            response.__enter__ = unittest.mock.Mock(return_value=response)
            response.__exit__ = unittest.mock.Mock(return_value=None)
            response.read.return_value = b'x' * (rpc.MAX_RESPONSE + 1)
            opener.return_value.open.return_value = response
            reader = rpc.RecordingReader(rpc.RpcTransport('https://example.invalid/key'), H(9))
            self.assertEqual(reader.call_outcome(A(1), '0x12345678')['kind'], 'response_size')
            response.read.assert_called_once_with(rpc.MAX_RESPONSE + 1)

    def test_malformed_response_or_id_is_hard_failure_without_remote_text(self):
        secret = 'PRIVATE_BAD_RESPONSE'
        values = (secret.encode() + b'\xff', dumps({'jsonrpc': '2.0', 'id': 2, 'result': '0x'}),
            dumps({'jsonrpc': '2.0', 'id': True, 'result': '0x'}),
            dumps({'jsonrpc': '2.0', 'id': 1, 'result': '0x', 'error': {'code': -1}}),
            dumps({'jsonrpc': '2.0', 'id': 1, 'error': {'code': True, 'message': secret}}),
            dumps({'jsonrpc': '2.0', 'id': 1, 'result': secret}))
        for raw in values:
            with self.subTest(raw=raw[:12]), patch.object(rpc.urllib.request, 'build_opener') as opener:
                opener.return_value.open.return_value = io.BytesIO(raw)
                reader = rpc.RecordingReader(rpc.RpcTransport('https://example.invalid/key'), H(9))
                try: reader.call_outcome(A(1), '0x12345678')
                except MuseumError as exc:
                    self.assertNotIsInstance(exc, rpc.CallUnavailable)
                    self.assertNotIn(secret, ''.join(traceback.format_exception(exc)))
                else: self.fail('malformed response accepted')
                self.assertEqual(reader.rows, [])

    def test_original_public_methods_and_log_limits_keep_their_semantics(self):
        transport = rpc.RpcTransport('https://example.invalid/key')
        responses = [dumps({'jsonrpc': '2.0', 'id': 1, 'result': '0x1'}),
            dumps({'jsonrpc': '2.0', 'id': 2, 'result': '0x6000'}),
            dumps({'jsonrpc': '2.0', 'id': 3, 'error': {'code': -32005, 'message': 'range limit'}})]
        with patch.object(rpc.urllib.request, 'build_opener') as opener:
            opener.return_value.open.side_effect = [io.BytesIO(raw) for raw in responses]
            reader = rpc.RecordingReader(transport, H(9))
            self.assertEqual(reader.request('eth_chainId', []), '0x1')
            self.assertEqual(reader.code(A(1)), '0x6000')
            with self.assertRaises(rpc.PublicLimitError): reader.request('eth_getLogs', LOGS)
        raw = reader.transcript(); replay = rpc.ReplayTransport(raw, keccak256(raw))
        self.assertEqual(replay.request('eth_chainId', []), '0x1')
        self.assertEqual(replay.request('eth_getCode', [A(1), BLOCK]), '0x6000')
        with self.assertRaises(rpc.PublicLimitError): replay.request('eth_getLogs', LOGS)
        replay.finish()

    def test_byte_limits_are_recordable_only_for_optional_calls_or_log_limits(self):
        with patch.object(rpc, 'MAX_RESPONSE', 64):
            reader, outcome = recorded('0x' + 'ab' * 64)
            self.assertEqual(outcome['kind'], 'response_size')
            self.assertLess(len(reader.transcript()), 1024)
            reader = rpc.RecordingReader(Transport('x' * 65), H(9))
            with self.assertRaises(rpc.PublicLimitError): reader.request('eth_getLogs', LOGS)
            with self.assertRaisesRegex(MuseumError, 'response byte bound'): reader.code(A(1))
        with patch.object(rpc, 'MAX_TRANSCRIPT', rpc.MAX_RESPONSE + 1):
            with self.assertRaisesRegex(MuseumError, 'transcript byte bound'): recorded('0x')

    def test_replay_profile_pin_shape_order_and_complete_consumption(self):
        reader, _ = recorded('0x')
        raw = reader.transcript()
        with self.assertRaisesRegex(MuseumError, 'commitment'): rpc.ReplayTransport(raw, H(1))
        for change in (lambda v: v.update(profile=rpc.public.PROFILE), lambda v: v.update(version=2),
                lambda v: v['calls'][0].update(unavailable={'kind': 'provider_error', 'code': -1}),
                lambda v: v['calls'][0].update(result=None)):
            value = loads(raw); change(value); other = dumps(value)
            with self.assertRaises(MuseumError): rpc.ReplayTransport(other, keccak256(other))
        replay = rpc.ReplayTransport(raw, keccak256(raw))
        with self.assertRaisesRegex(MuseumError, 'unconsumed'): replay.finish()
        other = deepcopy(CALL); other[1]['blockHash'] = H(8)
        with self.assertRaisesRegex(MuseumError, 'order mismatch'): replay.request('eth_call', other)
        self.assertEqual(replay.request('eth_call', CALL), '0x')
        replay.finish()
        with self.assertRaisesRegex(MuseumError, 'missing call'): replay.request('eth_call', CALL)

    def test_unavailable_closed_shape_and_code_bounds(self):
        for kind, code in (('provider_error', None), ('provider_error', True), ('provider_error', 1 << 31),
                ('provider_error', -(1 << 31) - 1), ('transport_unavailable', -1), ('unknown', None)):
            with self.subTest(kind=kind, code=code), self.assertRaises(MuseumError): rpc.CallUnavailable(kind, code)
        reader, _ = recorded(rpc.CallUnavailable('provider_error', -1))
        value = loads(reader.transcript()); value['calls'][0]['unavailable']['message'] = 'private'
        raw = dumps(value)
        with self.assertRaisesRegex(MuseumError, 'unavailable shape'): rpc.ReplayTransport(raw, keccak256(raw))

    def test_recording_and_replay_do_not_alias_mutable_caller_data(self):
        transport = Transport({'transactions': []})
        reader = rpc.RecordingReader(transport, H(9))
        params = [H(9), False]
        result = reader.request('eth_getBlockByHash', params)
        raw = reader.transcript(); result['transactions'].append('caller edit'); params[0] = H(8)
        self.assertEqual(reader.transcript(), raw)
        value = loads(raw); value['calls'].append(deepcopy(value['calls'][0])); raw = dumps(value)
        replay = rpc.ReplayTransport(raw, keccak256(raw))
        result = replay.request('eth_getBlockByHash', [H(9), False]); result['transactions'].append('caller edit')
        self.assertEqual(replay.request('eth_getBlockByHash', [H(9), False]), {'transactions': []})
        replay.finish()


if __name__ == '__main__':
    unittest.main()
