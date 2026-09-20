"""Transport/replay controls; no public RPC calls."""
import copy
import http.client
import io
import traceback
import unittest
import urllib.error
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads
from . import public_history_rpc as rpc

H = lambda n: "0x" + f"{n:064x}"
A = lambda n: "0x" + f"{n:040x}"
LOG_PARAMS = [{"address": A(1), "topics": [H(1)], "fromBlock": "0x0", "toBlock": "0x10"}]


class Transport:
    def __init__(self, result): self.result = result
    def request(self, method, params):
        if isinstance(self.result, Exception): raise self.result
        return copy.deepcopy(self.result)


class PublicHistoryRpcTests(unittest.TestCase):
    def test_distinct_wire_and_exact_success_replay(self):
        reader = rpc.PublicRecordingReader(Transport("0x1"), H(9))
        self.assertEqual(reader.request("eth_chainId", []), "0x1")
        raw = reader.transcript(); value = loads(raw)
        self.assertEqual(value["version"], 2)
        self.assertEqual(value["profile"], rpc.PROFILE)
        replay = rpc.PublicReplayTransport(raw, keccak256(raw))
        same = rpc.PublicRecordingReader(replay, H(9))
        with patch("socket.socket", side_effect=AssertionError("no network")):
            same.request("eth_chainId", []); replay.finish()
        self.assertEqual(same.transcript(), raw)

    def test_sanitized_limits_replay_as_limit_not_empty_result(self):
        reader = rpc.PublicRecordingReader(Transport(rpc.PublicLimitError("range_limit")), H(9))
        with self.assertRaises(rpc.PublicLimitError): reader.request("eth_getLogs", LOG_PARAMS)
        raw = reader.transcript()
        self.assertEqual(loads(raw)["calls"][0], {"method": "eth_getLogs", "params": LOG_PARAMS, "limit": "range_limit"})
        replay = rpc.PublicReplayTransport(raw, keccak256(raw))
        with self.assertRaisesRegex(rpc.PublicLimitError, "range_limit"): replay.request("eth_getLogs", LOG_PARAMS)
        replay.finish()

    def test_response_size_becomes_log_limit_only(self):
        reader = rpc.PublicRecordingReader(Transport("x" * rpc.MAX_RESPONSE), H(9))
        with self.assertRaisesRegex(rpc.PublicLimitError, "response_size"): reader.request("eth_getLogs", LOG_PARAMS)
        self.assertLess(len(reader.transcript()), 1000)
        with self.assertRaisesRegex(MuseumError, "response byte bound"): reader.request("eth_getCode", [A(1), reader.block])

    def test_conflicting_repeated_results_and_limit_success_reject(self):
        t = Transport("0x1"); reader = rpc.PublicRecordingReader(t, H(9))
        reader.request("eth_chainId", []); t.result = "0x2"
        with self.assertRaisesRegex(MuseumError, "repeated RPC result"): reader.request("eth_chainId", [])
        t = Transport(rpc.PublicLimitError("range_limit")); reader = rpc.PublicRecordingReader(t, H(9))
        with self.assertRaises(rpc.PublicLimitError): reader.request("eth_getLogs", LOG_PARAMS)
        t.result = []
        with self.assertRaisesRegex(MuseumError, "repeated RPC result"): reader.request("eth_getLogs", LOG_PARAMS)

    def test_captured_rows_do_not_alias_returned_values(self):
        reader = rpc.PublicRecordingReader(Transport({"value": []}), H(9))
        value = reader.request("eth_getBlockByHash", [H(9), False]); before = reader.transcript()
        value["value"].append("mutated")
        self.assertEqual(reader.transcript(), before)

    def test_replay_requires_pin_profile_shape_order_and_consumption(self):
        reader = rpc.PublicRecordingReader(Transport("0x1"), H(9)); reader.request("eth_chainId", [])
        raw = reader.transcript()
        with self.assertRaisesRegex(MuseumError, "commitment"): rpc.PublicReplayTransport(raw, H(1))
        for edit in (lambda v: v.update(version=1), lambda v: v.update(profile="old"),
            lambda v: v["calls"][0].update(limit="range_limit"), lambda v: v.update(extra=True)):
            value = loads(raw); edit(value); changed = dumps(value)
            with self.subTest(edit=edit), self.assertRaises(MuseumError): rpc.PublicReplayTransport(changed, keccak256(changed))
        replay = rpc.PublicReplayTransport(raw, keccak256(raw))
        with self.assertRaisesRegex(MuseumError, "unconsumed"): replay.finish()
        with self.assertRaisesRegex(MuseumError, "order mismatch"): replay.request("eth_getCode", [A(1), reader.block])

    def test_param_methods_and_bounds_fail_before_transport(self):
        reader = rpc.PublicRecordingReader(Transport("0x1"), H(9))
        for method, params in (("eth_sendRawTransaction", []), ("eth_chainId", ["extra"]),
            ("eth_getBlockByNumber", ["latest", False]), ("eth_getCode", [A(1), "latest"]),
            ("eth_getLogs", [{**LOG_PARAMS[0], "fromBlock": "0x11"}]),
            ("eth_getLogs", [{**LOG_PARAMS[0], "topics": [[]]}])):
            with self.subTest(method=method), self.assertRaises(MuseumError): reader.request(method, params)
        self.assertEqual(reader.rows, [])
        with patch.object(rpc, "MAX_CALLS", 1):
            reader.request("eth_chainId", [])
            with self.assertRaisesRegex(MuseumError, "call bound"): reader.request("eth_chainId", [])
        with patch.object(rpc, "MAX_TRANSCRIPT", rpc.MAX_RESPONSE + 1):
            with self.assertRaisesRegex(MuseumError, "transcript byte bound"):
                rpc.PublicRecordingReader(Transport("0x1"), H(9)).request("eth_chainId", [])

    def test_live_wire_success_and_sanitized_error_classification(self):
        transport = rpc.PublicRpcTransport("https://example.invalid/private-credential")
        responses = [dumps({"jsonrpc": "2.0", "id": 1, "result": []}),
            dumps({"jsonrpc": "2.0", "id": 2, "error": {"code": -32005, "message": "private remote content", "data": "secret"}}),
            dumps({"jsonrpc": "2.0", "id": 3, "error": {"code": -1, "message": "secret failure"}})]
        with patch.object(rpc.urllib.request, "build_opener") as opener:
            opener.return_value.open.side_effect = [io.BytesIO(raw) for raw in responses]
            self.assertEqual(transport.request("eth_getLogs", LOG_PARAMS), [])
            request = opener.return_value.open.call_args.args[0]
            self.assertEqual(request.get_header("User-agent"), "6529Stream-readonly-capture/1")
            with self.assertRaisesRegex(rpc.PublicLimitError, "range_limit") as error: transport.request("eth_getLogs", LOG_PARAMS)
            self.assertNotIn("secret", str(error.exception))
            with self.assertRaisesRegex(MuseumError, "response failed") as error: transport.request("eth_getLogs", LOG_PARAMS)
            self.assertNotIn("secret", str(error.exception))

    def test_endpoint_redirect_http_error_and_large_wire(self):
        with self.assertRaises(MuseumError): rpc.PublicRpcTransport("http://example.invalid/key")
        with self.assertRaisesRegex(MuseumError, "redirect refused"):
            rpc._NoRedirect().redirect_request(None, None, 302, "", {}, "https://other.invalid")
        transport = rpc.PublicRpcTransport("https://example.invalid/key")
        with patch.object(rpc.urllib.request, "build_opener") as opener:
            opener.return_value.open.side_effect = urllib.error.HTTPError("secret", 413, "secret", {}, None)
            with self.assertRaisesRegex(rpc.PublicLimitError, "response_size"): transport.request("eth_getLogs", LOG_PARAMS)
            opener.return_value.open.side_effect = None
            opener.return_value.open.return_value = io.BytesIO(b"x" * (rpc.MAX_RESPONSE + 1))
            with self.assertRaisesRegex(rpc.PublicLimitError, "response_size"): transport.request("eth_getLogs", LOG_PARAMS)

    def test_http_protocol_failures_redact_complete_formatted_traceback(self):
        secret = "-".join(("PRIVATE", "CREDENTIAL", "PATH"))
        for exception in (http.client.InvalidURL("/rpc/" + secret), http.client.BadStatusLine("HTTP remote " + secret)):
            transport = rpc.PublicRpcTransport("https://example.invalid/" + secret)
            with self.subTest(kind=type(exception).__name__), patch.object(rpc.urllib.request, "build_opener") as opener:
                opener.return_value.open.side_effect = exception
                try:
                    transport.request("eth_getLogs", LOG_PARAMS)
                except MuseumError as exc:
                    rendered = "".join(traceback.format_exception(exc))
                    self.assertIn("public RPC transport failed", rendered)
                    self.assertNotIn(secret, rendered)
                    self.assertNotIn(type(exception).__name__, rendered)
                else: self.fail("HTTP protocol failure was accepted")

    def test_malformed_response_and_parser_failure_redact_traceback(self):
        secret = "-".join(("PRIVATE", "REMOTE", "PAYLOAD"))
        transport = rpc.PublicRpcTransport("https://example.invalid/" + secret)
        with patch.object(rpc.urllib.request, "build_opener") as opener:
            opener.return_value.open.return_value = io.BytesIO(secret.encode() + b"\xff")
            try:
                transport.request("eth_getLogs", LOG_PARAMS)
            except MuseumError as exc:
                rendered = "".join(traceback.format_exception(exc))
                self.assertIn("public RPC malformed response", rendered)
                self.assertNotIn(secret, rendered)
                self.assertNotIn("UnicodeDecodeError", rendered)
            else: self.fail("malformed response was accepted")
            opener.return_value.open.return_value = io.BytesIO(b"{}")
            with patch.object(rpc, "loads", side_effect=ValueError(secret)):
                try:
                    transport.request("eth_getLogs", LOG_PARAMS)
                except MuseumError as exc:
                    rendered = "".join(traceback.format_exception(exc))
                    self.assertIn("public RPC malformed response", rendered)
                    self.assertNotIn(secret, rendered)
                else: self.fail("parser failure was accepted")


if __name__ == "__main__": unittest.main()
