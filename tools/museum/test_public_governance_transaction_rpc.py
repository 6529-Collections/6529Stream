"""Offline allowlist, exact replay, bounded outcomes and sanitized transport regressions."""
import http.client
import unittest
from unittest.mock import patch
import urllib.error

from . import public_governance_transaction_rpc as rpc
from .canonical import MuseumError, dumps, keccak256
from .test_current_rights_source import H


def transcript(rows): return dumps({"profile": rpc.PROFILE, "version": rpc.VERSION, "calls": rows})


class GovernanceTransactionRpcTests(unittest.TestCase):
    def test_new_allowlist_does_not_extend_frozen_history_profile(self):
        from . import public_history_rpc as frozen
        self.assertNotIn("eth_getTransactionByHash", frozen.METHODS)
        for method, params in (("eth_sendRawTransaction", ["0x00"]), ("eth_call", []), ("eth_chainId", ["latest"]),
                ("eth_getTransactionByHash", [H(1), "latest"]), ("eth_getTransactionByHash", [H(0)])):
            with self.subTest(method=method, params=params), self.assertRaises(MuseumError): rpc._params(method, params)

    def test_null_is_retained_and_order_is_exact(self):
        rows = [{"method": "eth_chainId", "params": [], "result": "0x1"},
            {"method": "eth_getTransactionByHash", "params": [H(1)], "result": None}]
        raw = transcript(rows); replay = rpc.PublicGovernanceReplayTransport(raw, keccak256(raw))
        reader = rpc.PublicGovernanceRecordingReader(replay)
        self.assertEqual(reader.request("eth_chainId", []), "0x1")
        self.assertIsNone(reader.request("eth_getTransactionByHash", [H(1)]))
        replay.finish(); self.assertEqual(reader.transcript(), raw)
        replay = rpc.PublicGovernanceReplayTransport(raw, keccak256(raw))
        with self.assertRaisesRegex(MuseumError, "call/order"): replay.request("eth_getTransactionByHash", [H(1)])

    def test_replay_external_pin_rows_limits_missing_and_unused_calls(self):
        row = {"method": "eth_chainId", "params": [], "result": "0x1"}
        raw = transcript([row])
        with self.assertRaisesRegex(MuseumError, "external commitment"):
            rpc.PublicGovernanceReplayTransport(raw, H(1))
        with self.assertRaisesRegex(MuseumError, "unconsumed"):
            rpc.PublicGovernanceReplayTransport(raw, keccak256(raw)).finish()
        for rows in ([row] * 4, [{**row, "limit": "range_limit"}], [{"method": "eth_chainId", "params": []}]):
            raw = transcript(rows)
            with self.subTest(rows=rows), self.assertRaises(MuseumError): rpc.PublicGovernanceReplayTransport(raw, keccak256(raw))
        empty = transcript([])
        with self.assertRaisesRegex(MuseumError, "missing call"):
            rpc.PublicGovernanceReplayTransport(empty, keccak256(empty)).request("eth_chainId", [])

    def test_recording_keeps_immutable_originals_and_repeated_requests_agree(self):
        class Response:
            def request(self, method, params): return shared
        shared = {"hash": H(1), "data": ["original"]}
        reader = rpc.PublicGovernanceRecordingReader(Response())
        result = reader.request("eth_getTransactionByHash", [H(1)])
        result["data"][0] = "caller mutation"
        self.assertEqual(reader.rows[0]["result"]["data"], ["original"])
        shared["data"][0] = "provider contradiction"
        with self.assertRaisesRegex(MuseumError, "repeated RPC result differs"):
            reader.request("eth_getTransactionByHash", [H(1)])

    def test_response_bound_and_endpoint_policy(self):
        for url in ("http://example.com", "file:///etc/passwd", "https://example.com/#secret"):
            with self.subTest(url=url), self.assertRaises(MuseumError): rpc.PublicGovernanceRpcTransport(url)
        row = {"method": "eth_getTransactionByHash", "params": [H(1)], "result": "x" * rpc.MAX_RESPONSE}
        with self.assertRaisesRegex(MuseumError, "response byte bound"): rpc._row(row)

    def test_remote_error_and_endpoint_text_are_not_exposed(self):
        endpoint = "https://example.com/private-key-should-not-leak"
        for failure in (urllib.error.URLError(endpoint), http.client.BadStatusLine(endpoint), OSError(endpoint)):
            with self.subTest(failure=type(failure).__name__), patch.object(rpc.urllib.request, "build_opener") as opener:
                opener.return_value.open.side_effect = failure
                with self.assertRaises(MuseumError) as caught:
                    rpc.PublicGovernanceRpcTransport(endpoint).request("eth_chainId", [])
                self.assertEqual(str(caught.exception), "governance RPC transport failed")
                self.assertTrue(caught.exception.__suppress_context__)
        class Response:
            def __enter__(self): return self
            def __exit__(self, *_): pass
            def read(self, _): return dumps({"jsonrpc": "2.0", "id": 1, "error": {"message": endpoint, "data": endpoint}})
        with patch.object(rpc.urllib.request, "build_opener") as opener:
            opener.return_value.open.return_value = Response()
            with self.assertRaisesRegex(MuseumError, "^governance RPC response failed$"):
                rpc.PublicGovernanceRpcTransport(endpoint).request("eth_chainId", [])


if __name__ == "__main__": unittest.main()
