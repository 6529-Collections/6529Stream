"""Offline-only union-transport/replay controls; no network or chain acceptance."""
import http.client
import traceback
import unittest
from unittest.mock import patch

from . import public_scoped_finality_rpc as rpc
from . import public_history_rpc as history
from . import public_governance_transaction_rpc as transaction
from .canonical import MuseumError, dumps, keccak256, loads


def H(value): return keccak256(str(value).encode("utf-8"))
ADDRESS = "0x" + "12" * 20
BLOCK = H("source block")
TRANSACTION = H("original transaction")
FILTER = {"address": ADDRESS, "topics": [H("topic")], "fromBlock": "0x0", "toBlock": "0xc34f"}


def transcript(rows):
    return dumps({"profile": rpc.PROFILE, "version": rpc.VERSION, "calls": rows})


class Answers:
    def __init__(self, result): self.result = result
    def request(self, method, params): return self.result


class ScopedFinalityRpcTests(unittest.TestCase):
    def test_distinct_union_profile_preserves_both_frozen_profiles(self):
        self.assertEqual(history.PROFILE_HASH, "0xadec710b3df01c4e4eb37681eeecf5a8a0a40fdfe35ef2eb603b130857ab0c68")
        self.assertEqual(transaction.PROFILE_HASH, "0xbc67b7edf60d35ef70a4701dd4c1f0b2c28825b6f17c40eec31f0a2bb3420507")
        self.assertEqual(rpc.METHODS, history.METHODS | {"eth_getTransactionByHash"})
        self.assertNotIn("eth_getTransactionByHash", history.METHODS)
        self.assertNotIn("eth_getLogs", transaction.METHODS)
        rows = [{"method": "eth_chainId", "params": [], "result": "0x1"}]
        for profile, version in ((history.PROFILE, history.VERSION), (transaction.PROFILE, transaction.VERSION)):
            raw = dumps({"profile": profile, "version": version, "calls": rows})
            with self.assertRaisesRegex(MuseumError, "profile/version"):
                rpc.PublicScopedReplayTransport(raw, keccak256(raw))

    def test_every_allowed_read_roundtrips_in_one_ordered_transcript(self):
        state = {"blockHash": BLOCK, "requireCanonical": True}
        requests = [("eth_chainId", [], "0xaa36a7"),
            ("eth_getBlockByNumber", ["0x12345", False], {"hash": BLOCK}),
            ("eth_getBlockByHash", [BLOCK, False], {"hash": BLOCK}),
            ("eth_getTransactionReceipt", [TRANSACTION], {"transactionHash": TRANSACTION}),
            ("eth_getLogs", [FILTER], []),
            ("eth_getCode", [ADDRESS, state], "0x6000"),
            ("eth_call", [{"to": ADDRESS, "data": "0x12345678", "gas": "0x1312d00"}, state], "0x00"),
            ("eth_getTransactionByHash", [TRANSACTION], {"hash": TRANSACTION, "input": "0x12345678"})]
        raw = transcript([{"method": m, "params": p, "result": r} for m, p, r in requests])
        transport = rpc.PublicScopedReplayTransport(raw, keccak256(raw))
        reader = rpc.PublicScopedRecordingReader(transport, BLOCK)
        for method, params, result in requests: self.assertEqual(reader.request(method, params), result)
        transport.finish()
        self.assertEqual(reader.transcript(), raw)

    def test_null_transaction_is_retained_not_invented_absence_reason(self):
        raw = transcript([{"method": "eth_getTransactionByHash", "params": [TRANSACTION], "result": None}])
        replay = rpc.PublicScopedReplayTransport(raw, keccak256(raw))
        reader = rpc.PublicScopedRecordingReader(replay, BLOCK)
        self.assertIsNone(reader.request("eth_getTransactionByHash", [TRANSACTION]))
        replay.finish(); self.assertEqual(reader.transcript(), raw)
        self.assertEqual(set(loads(raw)["calls"][0]), {"method", "params", "result"})

    def test_only_log_queries_can_retain_sanitized_limits(self):
        for kind in ("range_limit", "response_size"):
            raw = transcript([{"method": "eth_getLogs", "params": [FILTER], "limit": kind}])
            replay = rpc.PublicScopedReplayTransport(raw, keccak256(raw))
            reader = rpc.PublicScopedRecordingReader(replay, BLOCK)
            with self.assertRaises(history.PublicLimitError) as error: reader.request("eth_getLogs", [FILTER])
            self.assertEqual(error.exception.kind, kind)
            replay.finish(); self.assertEqual(reader.transcript(), raw)
        for row in ({"method": "eth_getTransactionByHash", "params": [TRANSACTION], "limit": "range_limit"},
                    {"method": "eth_getLogs", "params": [FILTER], "limit": "remote secret details"},
                    {"method": "eth_getLogs", "params": [FILTER], "limit": "range_limit", "result": []}):
            raw = transcript([row])
            with self.assertRaises(MuseumError): rpc.PublicScopedReplayTransport(raw, keccak256(raw))

    def test_closed_request_shapes_and_write_methods_fail_before_transport(self):
        for method, params in (("eth_sendRawTransaction", ["0x00"]), ("eth_accounts", []),
                ("eth_getBlockByNumber", ["latest", False]), ("eth_getBlockByHash", [BLOCK, True]),
                ("eth_getTransactionByHash", [TRANSACTION, "latest"]), ("eth_getTransactionByHash", ["0x"+"00"*32]),
                ("eth_getLogs", [{**FILTER, "endpoint": "hidden"}]),
                ("eth_call", [{"to": ADDRESS, "data": "0x", "gas": "0x1"}, "latest"]),
                ("eth_getCode", [ADDRESS, {"blockHash": BLOCK, "requireCanonical": False}])):
            with self.subTest(method=method, params=params), patch.object(history.PublicRpcTransport, "request") as h, \
                    patch.object(transaction.PublicGovernanceRpcTransport, "request") as t:
                with self.assertRaises(MuseumError): rpc.PublicScopedRpcTransport("https://rpc.example").request(method, params)
                h.assert_not_called(); t.assert_not_called()

    def test_union_routes_transaction_and_history_to_exact_frozen_transports(self):
        with patch.object(history.PublicRpcTransport, "request", return_value="history") as h, \
                patch.object(transaction.PublicGovernanceRpcTransport, "request", return_value="transaction") as t:
            transport = rpc.PublicScopedRpcTransport("https://rpc.example")
            self.assertEqual(transport.request("eth_getLogs", [FILTER]), "history")
            self.assertEqual(transport.request("eth_getTransactionByHash", [TRANSACTION]), "transaction")
            h.assert_called_once_with("eth_getLogs", [FILTER])
            t.assert_called_once_with("eth_getTransactionByHash", [TRANSACTION])

    def test_external_hash_canonical_json_closed_envelope_and_rows(self):
        row = {"method": "eth_chainId", "params": [], "result": "0x1"}
        raw = transcript([row])
        with self.assertRaisesRegex(MuseumError, "external commitment"): rpc.PublicScopedReplayTransport(raw, H("wrong"))
        for value in ({"profile": rpc.PROFILE, "version": True, "calls": [row]},
                      {"profile": rpc.PROFILE, "version": 1, "calls": [row], "endpoint": "hidden"},
                      {"profile": rpc.PROFILE, "version": 1, "calls": [{**row, "error": "hidden"}]}):
            bad = dumps(value)
            with self.assertRaises(MuseumError): rpc.PublicScopedReplayTransport(bad, keccak256(bad))
        bad = raw+b"\n"
        with self.assertRaises(MuseumError): rpc.PublicScopedReplayTransport(bad, keccak256(bad))

    def test_replay_rejects_reorder_unconsumed_and_exhausted_calls(self):
        raw = transcript([{"method": "eth_chainId", "params": [], "result": "0x1"}])
        replay = rpc.PublicScopedReplayTransport(raw, keccak256(raw))
        with self.assertRaisesRegex(MuseumError, "unconsumed"): replay.finish()
        with self.assertRaisesRegex(MuseumError, "order"): replay.request("eth_getTransactionByHash", [TRANSACTION])
        replay = rpc.PublicScopedReplayTransport(raw, keccak256(raw))
        replay.request("eth_chainId", []); replay.finish()
        with self.assertRaisesRegex(MuseumError, "missing call"): replay.request("eth_chainId", [])

    def test_immutable_copies_for_both_kinds_of_replay_and_recording(self):
        for method, params in (("eth_getBlockByHash", [BLOCK, False]), ("eth_getTransactionByHash", [TRANSACTION])):
            response = {"nested": ["original"]}
            raw = transcript([{"method": method, "params": params, "result": response}]*2)
            replay = rpc.PublicScopedReplayTransport(raw, keccak256(raw))
            first = replay.request(method, params); first["nested"][0] = "caller mutation"
            self.assertEqual(replay.request(method, params), response)
            reader = rpc.PublicScopedRecordingReader(Answers(response), BLOCK)
            first = reader.request(method, params); first["nested"][0] = "mutation"
            self.assertEqual(reader.rows[0]["result"]["nested"], ["original"])
            if method == "eth_getTransactionByHash": self.assertEqual(response["nested"], ["original"])

    def test_repeated_results_or_limit_conflicts_fail_for_both_methods(self):
        for method, params in (("eth_getTransactionByHash", [TRANSACTION]), ("eth_getBlockByHash", [BLOCK, False])):
            transport = Answers({"a": "original"}); reader = rpc.PublicScopedRecordingReader(transport, BLOCK)
            reader.request(method, params); transport.result = {"a": "changed"}
            with self.assertRaisesRegex(MuseumError, "repeated RPC result differs"): reader.request(method, params)
        raw = transcript([{"method": "eth_getLogs", "params": [FILTER], "limit": "range_limit"},
            {"method": "eth_getLogs", "params": [FILTER], "result": []}])
        reader = rpc.PublicScopedRecordingReader(rpc.PublicScopedReplayTransport(raw, keccak256(raw)), BLOCK)
        with self.assertRaises(history.PublicLimitError): reader.request("eth_getLogs", [FILTER])
        with self.assertRaisesRegex(MuseumError, "repeated RPC result differs"): reader.request("eth_getLogs", [FILTER])

    def test_per_response_call_and_transcript_bounds(self):
        row = {"method": "eth_getTransactionByHash", "params": [TRANSACTION], "result": "x"*rpc.MAX_RESPONSE}
        with self.assertRaisesRegex(MuseumError, "response byte bound"): rpc._row(row)
        reader = rpc.PublicScopedRecordingReader(Answers(row["result"]), BLOCK)
        with self.assertRaisesRegex(MuseumError, "response byte bound"): reader.request(row["method"], row["params"])
        raw = transcript([{"method": "eth_chainId", "params": [], "result": "0x1"}]*3)
        with patch.object(rpc, "MAX_CALLS", 2):
            with self.assertRaisesRegex(MuseumError, "call bound"): rpc.PublicScopedReplayTransport(raw, keccak256(raw))
            reader = rpc.PublicScopedRecordingReader(Answers(None), BLOCK)
            reader.rows.extend([{}, {}])
            with self.assertRaisesRegex(MuseumError, "call bound"): reader.request("eth_getTransactionByHash", [TRANSACTION])
        reader = rpc.PublicScopedRecordingReader(Answers(None), BLOCK)
        reader.size = rpc.MAX_TRANSCRIPT-rpc.MAX_RESPONSE
        with self.assertRaisesRegex(MuseumError, "transcript byte bound"): reader.request("eth_getTransactionByHash", [TRANSACTION])

    def test_endpoint_and_full_traceback_redaction_on_both_routes(self):
        endpoint = "https://rpc.example/fake-credential-marker?token=do-not-retain"
        for method, params in (("eth_getBlockByHash", [BLOCK, False]), ("eth_getTransactionByHash", [TRANSACTION])):
            with patch.object(history.urllib.request, "build_opener") as opener:
                opener.return_value.open.side_effect = http.client.BadStatusLine(endpoint)
                try: rpc.PublicScopedRpcTransport(endpoint).request(method, params)
                except MuseumError:
                    rendered = traceback.format_exc()
                    self.assertNotIn("fake-credential-marker", rendered)
                    self.assertNotIn("do-not-retain", rendered)
                else: self.fail("malformed HTTP response accepted")
        for endpoint in ("http://outside.example", "file:///private", "https://rpc.example/#fragment"):
            with self.assertRaises(MuseumError): rpc.PublicScopedRpcTransport(endpoint)

    def test_malformed_or_remote_error_response_never_retains_remote_text(self):
        marker = "FAKE_REMOTE_SECRET"
        class Response:
            def __init__(self, raw): self.raw = raw
            def __enter__(self): return self
            def __exit__(self, *_): pass
            def read(self, maximum): return self.raw[:maximum]
        for method, params in (("eth_chainId", []), ("eth_getTransactionByHash", [TRANSACTION])):
            for raw in (b'{"secret":"'+marker.encode()+b'\xff"}',
                        dumps({"jsonrpc":"2.0", "id":1, "error":{"message":marker,"data":marker}})):
                with patch.object(history.urllib.request, "build_opener") as opener:
                    opener.return_value.open.return_value = Response(raw)
                    try: rpc.PublicScopedRpcTransport("https://rpc.example").request(method, params)
                    except MuseumError: self.assertNotIn(marker, traceback.format_exc())
                    else: self.fail("remote error accepted")


if __name__ == "__main__": unittest.main()
