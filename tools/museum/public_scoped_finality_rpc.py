"""Additive scoped-finality transcript: bounded history plus original transactions."""
from . import public_history_rpc as history
from . import public_governance_transaction_rpc as transaction
from .canonical import dumps, hex_bytes, keccak256, loads
from .independent_wire import require

PROFILE = "STREAM_MUSEUM_PUBLIC_SCOPED_FINALITY_RPC_V1"
VERSION = 1
MAX_RESPONSE, MAX_TRANSCRIPT, MAX_CALLS = history.MAX_RESPONSE, history.MAX_TRANSCRIPT, history.MAX_CALLS
METHODS = history.METHODS | {"eth_getTransactionByHash"}
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "transcriptVersion": VERSION,
    "methods": sorted(METHODS), "historyPolicyHash": history.PROFILE_HASH,
    "transactionPolicyHash": transaction.PROFILE_HASH,
    "maximumResponseBytes": str(MAX_RESPONSE), "maximumTranscriptBytes": str(MAX_TRANSCRIPT),
    "maximumCalls": str(MAX_CALLS),
    "requests": "Pinned canonical state, complete bounded provider history and original scheduled/executed transaction hashes in one ordered transcript.",
    "transport": "Frozen public-history transport and original-transaction transport composed without changing either policy. No writes, redirects, endpoint retention or raw remote errors.",
    "outcomes": "Only log queries can retain sanitized limits. Transaction null means not_returned. Other errors abort; no absence is inferred.",
    "replay": "Exact ordered requests, all calls consumed, immutable copied results and identical repeated observations.",
    "trust": "Provider observations do not authenticate signed transaction envelopes, runtime provenance, consensus or historical execution."})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _params(method, params):
    if method == "eth_getTransactionByHash": transaction._params(method, params)
    else: history._params(method, params)


def _row(row):
    if type(row) is dict and row.get("method") == "eth_getTransactionByHash": transaction._row(row)
    else: history._row(row)
    if "result" in row: require(len(dumps(row["result"])) <= MAX_RESPONSE, "scoped RPC response byte bound")


class PublicScopedRpcTransport:
    def __init__(self, endpoint):
        self._history = history.PublicRpcTransport(endpoint)
        self._transaction = transaction.PublicGovernanceRpcTransport(endpoint)

    def request(self, method, params):
        _params(method, params)
        target = self._transaction if method == "eth_getTransactionByHash" else self._history
        return target.request(method, params)


class PublicScopedReplayTransport(history.PublicReplayTransport):
    def __init__(self, raw, expected_hash):
        require(type(raw) is bytes and any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
            "scoped transcript external commitment differs")
        value = loads(raw, maximum=MAX_TRANSCRIPT, canonical=True)
        require(type(value) is dict and set(value) == {"profile", "version", "calls"}
            and value["profile"] == PROFILE and type(value["version"]) is int and value["version"] == VERSION,
            "scoped transcript profile/version differs")
        require(type(value["calls"]) is list and len(value["calls"]) <= MAX_CALLS, "scoped transcript call bound")
        for row in value["calls"]: _row(row)
        self._rows, self._cursor = value["calls"], 0

    def request(self, method, params):
        _params(method, params)
        return loads(dumps(super().request(method, params)), maximum=MAX_RESPONSE)


class PublicScopedRecordingReader(history.PublicRecordingReader):
    def request(self, method, params):
        if method != "eth_getTransactionByHash": return super().request(method, params)
        _params(method, params)
        require(len(self.rows) < MAX_CALLS, "scoped read call bound")
        result = self.transport.request(method, params)
        row = {"method": method, "params": params, "result": result}; _row(row)
        encoded = dumps(row); key, outcome = dumps([method, params]), dumps({"result": result})
        require(key not in self._seen or self._seen[key] == outcome, "scoped repeated RPC result differs")
        require(self.size + len(encoded) <= MAX_TRANSCRIPT - MAX_RESPONSE, "scoped transcript byte bound")
        self._seen[key] = outcome; self.size += len(encoded)
        self.rows.append(loads(encoded, maximum=MAX_RESPONSE + 65536))
        return loads(dumps(result), maximum=MAX_RESPONSE)

    def transcript(self): return dumps({"profile": PROFILE, "version": VERSION, "calls": self.rows})
