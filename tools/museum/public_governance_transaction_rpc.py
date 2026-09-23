"""Bounded original-transaction RPC profile; frozen history transports stay unchanged."""
import http.client
import urllib.error
import urllib.request

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require
from .public_history_rpc import PublicRpcTransport as _EndpointPolicy, _NoRedirect

PROFILE = "STREAM_MUSEUM_PUBLIC_GOVERNANCE_TRANSACTION_RPC_V1"
VERSION = 1
MAX_RESPONSE = 1048576
MAX_TRANSCRIPT = 4194304
MAX_CALLS = 3
METHODS = {"eth_chainId", "eth_getTransactionByHash"}
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "transcriptVersion": VERSION,
    "methods": sorted(METHODS), "maximumResponseBytes": str(MAX_RESPONSE),
    "maximumTranscriptBytes": str(MAX_TRANSCRIPT), "maximumCalls": str(MAX_CALLS),
    "requests": "One chain ID followed by original scheduled and executed event transaction hashes, in that order. No current roles, state changes or transaction submission.",
    "outcomes": "Exact canonical JSON result retained, including null. A null result means not_returned; pruning is not inferred. Errors abort with sanitized messages and never become absence.",
    "transport": "HTTPS except loopback HTTP, redirects refused, thirty-second timeout, bounded response. Endpoint and remote error details are not retained.",
    "replay": "Exact ordered requests; every row consumed; identical requests must have identical results. Original transaction JSON and input bytes are provider observations, not signed transaction envelopes.",
    "trust": "No transaction-hash/signature reconstruction, consensus, historical role/policy or EVM execution verification."})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _params(method, params):
    require(type(method) is str and method in METHODS and type(params) is list, "governance RPC method/params")
    if method == "eth_chainId": require(params == [], "governance RPC chain params")
    else:
        require(len(params) == 1 and any(hex_bytes(params[0], 32)), "governance RPC transaction hash params")


def _row(row):
    require(type(row) is dict and set(row) == {"method", "params", "result"}, "governance RPC transcript row shape")
    _params(row["method"], row["params"])
    require(len(dumps(row["result"])) <= MAX_RESPONSE, "governance RPC response byte bound")


class PublicGovernanceRpcTransport(_EndpointPolicy):
    def request(self, method, params):
        _params(method, params)
        self._sequence += 1
        try:
            request = urllib.request.Request(self._endpoint, data=dumps({"jsonrpc": "2.0",
                "id": self._sequence, "method": method, "params": params}),
                headers={"Content-Type": "application/json", "User-Agent": "6529Stream-readonly-capture/1"}, method="POST")
            with urllib.request.build_opener(_NoRedirect()).open(request, timeout=30) as response:
                raw = response.read(MAX_RESPONSE + 1)
        except (urllib.error.URLError, http.client.HTTPException, TimeoutError, OSError, ValueError):
            raise MuseumError("governance RPC transport failed") from None
        require(len(raw) <= MAX_RESPONSE, "governance RPC response byte bound")
        try: value = loads(raw, maximum=MAX_RESPONSE)
        except (ValueError, TypeError, RecursionError):
            raise MuseumError("governance RPC malformed response") from None
        require(type(value) is dict and value.get("jsonrpc") == "2.0"
            and type(value.get("id")) is int and value["id"] == self._sequence,
            "governance RPC mismatched response")
        require("error" not in value, "governance RPC response failed")
        require("result" in value, "governance RPC missing result")
        return value["result"]


class PublicGovernanceReplayTransport:
    def __init__(self, raw, expected_hash):
        require(type(raw) is bytes and any(hex_bytes(expected_hash, 32))
            and keccak256(raw) == expected_hash, "governance transcript external commitment differs")
        value = loads(raw, maximum=MAX_TRANSCRIPT, canonical=True)
        require(type(value) is dict and set(value) == {"profile", "version", "calls"}
            and value["profile"] == PROFILE and type(value["version"]) is int and value["version"] == VERSION,
            "governance transcript profile/version differs")
        require(type(value["calls"]) is list and len(value["calls"]) <= MAX_CALLS, "governance transcript call bound")
        for row in value["calls"]: _row(row)
        self._rows, self._cursor = value["calls"], 0

    def request(self, method, params):
        _params(method, params)
        require(self._cursor < len(self._rows), "governance transcript missing call")
        row = self._rows[self._cursor]; self._cursor += 1
        require(row["method"] == method and row["params"] == params, "governance transcript call/order differs")
        return loads(dumps(row["result"]), maximum=MAX_RESPONSE)

    def finish(self): require(self._cursor == len(self._rows), "governance transcript unconsumed calls")


class PublicGovernanceRecordingReader:
    def __init__(self, transport):
        self.transport, self.rows, self._seen = transport, [], {}

    def request(self, method, params):
        _params(method, params)
        require(len(self.rows) < MAX_CALLS, "governance read call bound")
        result = self.transport.request(method, params)
        row = {"method": method, "params": params, "result": result}; _row(row)
        key, outcome = dumps([method, params]), dumps(result)
        require(key not in self._seen or self._seen[key] == outcome, "governance repeated RPC result differs")
        self._seen[key] = outcome
        self.rows.append(loads(dumps(row), maximum=MAX_RESPONSE + 1024))
        require(len(self.transcript()) <= MAX_TRANSCRIPT, "governance transcript byte bound")
        return loads(outcome, maximum=MAX_RESPONSE)

    def transcript(self): return dumps({"profile": PROFILE, "version": VERSION, "calls": self.rows})
