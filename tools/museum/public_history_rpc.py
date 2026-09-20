"""Additive bounded public-history transport; provider answers remain a trust boundary."""
import http.client
import urllib.error
import urllib.parse
import urllib.request

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .chain_rpc import quantity

PROFILE = "STREAM_MUSEUM_PUBLIC_HISTORY_RPC_V1"
VERSION = 2
MAX_RESPONSE = 1048576
MAX_TRANSCRIPT = 67108864
MAX_CALLS = 100000
METHODS = {"eth_chainId", "eth_getBlockByHash", "eth_getBlockByNumber", "eth_getLogs",
    "eth_call", "eth_getCode", "eth_getTransactionReceipt"}
LIMITS = {"range_limit", "response_size"}
PROFILE_BYTES = dumps({"id": PROFILE, "version": "1", "transcriptVersion": VERSION,
    "methods": sorted(METHODS), "maximumResponseBytes": str(MAX_RESPONSE),
    "maximumTranscriptBytes": str(MAX_TRANSCRIPT), "maximumCalls": str(MAX_CALLS),
    "parameters": "Closed method shapes; numeric canonical block quantities, exact hash headers, EIP-1898 canonical state reads, positional log topics and inclusive explicit ranges.",
    "outcomes": "Exactly result or sanitized limit. Only eth_getLogs may retain range_limit or response_size; errors retain no remote message, data or endpoint.",
    "limits": "HTTP413 or oversized log response becomes response_size; JSON-RPC -32005 or explicit range/result-size wording becomes range_limit. Other failures abort, never become empty pages.",
    "replay": "Exact ordered requests and outcomes; all calls consumed. Identical requests must have identical outcomes across a capture.",
    "transport": "HTTPS except loopback HTTP; redirects refused; thirty-second request timeout. HTTP protocol and response parser failures are sanitized without exception chaining. No credentials or endpoint is included in evidence.",
    "trust": "RPC provider claims only; no consensus, trie proof, complete-log proof or actual-chain acceptance inferred."})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _params(method, params):
    if type(method) is not str or method not in METHODS or type(params) is not list: raise MuseumError("public RPC method/params")
    if method == "eth_chainId":
        if params: raise MuseumError("public RPC chain params")
    elif method in ("eth_getBlockByHash", "eth_getBlockByNumber"):
        if len(params) != 2 or params[1] is not False: raise MuseumError("public RPC header params")
        if method == "eth_getBlockByHash": hex_bytes(params[0], 32)
        else: quantity(params[0])
    elif method == "eth_getTransactionReceipt":
        if len(params) != 1: raise MuseumError("public RPC receipt params")
        hex_bytes(params[0], 32)
    elif method == "eth_getLogs":
        if len(params) != 1 or type(params[0]) is not dict or set(params[0]) != {"address", "topics", "fromBlock", "toBlock"}:
            raise MuseumError("public RPC log params")
        f = params[0]; hex_bytes(f["address"], 20)
        if quantity(f["fromBlock"]) > quantity(f["toBlock"]): raise MuseumError("public RPC reversed log range")
        if type(f["topics"]) is not list or len(f["topics"]) > 4: raise MuseumError("public RPC topic positions")
        for term in f["topics"]:
            if term is None: continue
            if type(term) is list:
                if not 0 < len(term) <= 64: raise MuseumError("public RPC topic OR bound")
                for topic in term: hex_bytes(topic, 32)
                if len(set(term)) != len(term): raise MuseumError("public RPC duplicate OR topic")
            else: hex_bytes(term, 32)
    else:
        if len(params) != 2 or type(params[1]) is not dict or set(params[1]) != {"blockHash", "requireCanonical"} or params[1]["requireCanonical"] is not True:
            raise MuseumError("public RPC EIP-1898 params")
        hex_bytes(params[1]["blockHash"], 32)
        if method == "eth_getCode": hex_bytes(params[0], 20)
        else:
            if type(params[0]) is not dict or set(params[0]) != {"to", "data", "gas"}: raise MuseumError("public RPC call params")
            hex_bytes(params[0]["to"], 20); hex_bytes(params[0]["data"])
            quantity(params[0]["gas"])


class PublicLimitError(MuseumError):
    def __init__(self, kind):
        if kind not in LIMITS: raise MuseumError("unknown public RPC limit")
        self.kind = kind
        super().__init__("public RPC " + kind)


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, response, code, message, headers, new_url):
        raise MuseumError("public RPC redirect refused")


class PublicRpcTransport:
    def __init__(self, endpoint):
        try:
            parsed = urllib.parse.urlparse(endpoint)
            hostname = parsed.hostname
        except (ValueError, TypeError):
            raise MuseumError("invalid public RPC endpoint") from None
        if parsed.scheme not in ("http", "https") or not hostname or parsed.fragment:
            raise MuseumError("invalid public RPC endpoint")
        if parsed.scheme == "http" and hostname not in ("127.0.0.1", "localhost", "::1"):
            raise MuseumError("nonlocal public RPC requires HTTPS")
        self._endpoint, self._sequence = endpoint, 0

    def request(self, method, params):
        _params(method, params)
        self._sequence += 1
        try:
            request = urllib.request.Request(self._endpoint, data=dumps({"jsonrpc": "2.0",
                "id": self._sequence, "method": method, "params": params}),
                headers={"Content-Type": "application/json"}, method="POST")
            with urllib.request.build_opener(_NoRedirect()).open(request, timeout=30) as response:
                raw = response.read(MAX_RESPONSE + 1)
        except urllib.error.HTTPError as exc:
            if method == "eth_getLogs" and exc.code == 413: raise PublicLimitError("response_size") from None
            raise MuseumError("public RPC transport failed") from None
        except (urllib.error.URLError, http.client.HTTPException, TimeoutError, OSError, ValueError):
            raise MuseumError("public RPC transport failed") from None
        if len(raw) > MAX_RESPONSE:
            if method == "eth_getLogs": raise PublicLimitError("response_size")
            raise MuseumError("public RPC response byte bound")
        try:
            value = loads(raw, maximum=MAX_RESPONSE)
        except (ValueError, TypeError, RecursionError):
            raise MuseumError("public RPC malformed response") from None
        if not isinstance(value, dict) or value.get("jsonrpc") != "2.0" or type(value.get("id")) is not int or value["id"] != self._sequence:
            raise MuseumError("public RPC mismatched response")
        if "error" in value:
            error = value["error"]
            # Inspect only in memory. Never retain remote messages, data or endpoint URLs.
            if method == "eth_getLogs" and isinstance(error, dict):
                message = error.get("message", "")
                message = message.lower() if isinstance(message, str) else ""
                if error.get("code") == -32005 or any(term in message for term in
                    ("query returned more than", "block range", "too many results", "response size", "log response size")):
                    raise PublicLimitError("range_limit")
            raise MuseumError("public RPC response failed")
        if "result" not in value: raise MuseumError("public RPC missing result")
        return value["result"]


def _row(row):
    if not isinstance(row, dict) or set(row) not in ({"method", "params", "result"}, {"method", "params", "limit"}):
        raise MuseumError("public transcript row shape")
    _params(row["method"], row["params"])
    if "limit" in row and (row["method"] != "eth_getLogs" or type(row["limit"]) is not str or row["limit"] not in LIMITS):
        raise MuseumError("public transcript limit outcome")


class PublicReplayTransport:
    def __init__(self, raw, expected_hash):
        if keccak256(raw) != expected_hash: raise MuseumError("public transcript external commitment mismatch")
        value = loads(raw, maximum=MAX_TRANSCRIPT, canonical=True)
        if not isinstance(value, dict) or set(value) != {"version", "profile", "calls"} or type(value["version"]) is not int or value["version"] != VERSION or value["profile"] != PROFILE:
            raise MuseumError("public transcript wire profile/version")
        if type(value["calls"]) is not list or len(value["calls"]) > MAX_CALLS:
            raise MuseumError("public transcript call bound")
        for row in value["calls"]: _row(row)
        self._rows, self._cursor = value["calls"], 0

    def request(self, method, params):
        if self._cursor >= len(self._rows): raise MuseumError("public transcript missing call")
        row = self._rows[self._cursor]
        self._cursor += 1
        if row["method"] != method or dumps(row["params"]) != dumps(params):
            raise MuseumError("public transcript call/block/order mismatch")
        if "limit" in row: raise PublicLimitError(row["limit"])
        return row["result"]

    def finish(self):
        if self._cursor != len(self._rows): raise MuseumError("public transcript unconsumed calls")


class PublicRecordingReader:
    def __init__(self, transport, block_hash):
        self.transport = transport
        self.block = {"blockHash": block_hash, "requireCanonical": True}
        self.rows, self.size, self._seen = [], 0, {}

    def request(self, method, params):
        _params(method, params)
        if len(self.rows) >= MAX_CALLS: raise MuseumError("public read call bound")
        row = {"method": method, "params": params}
        limit = None
        try:
            result = self.transport.request(method, params)
            if len(dumps(result)) > MAX_RESPONSE:
                if method == "eth_getLogs": raise PublicLimitError("response_size")
                raise MuseumError("public read response byte bound")
            row["result"] = result
        except PublicLimitError as exc:
            if method != "eth_getLogs": raise MuseumError("public limit outside log query") from None
            limit = exc.kind
            row["limit"] = limit
        encoded = dumps(row)
        key, outcome = dumps([method, params]), dumps({k: v for k, v in row.items() if k in ("result", "limit")})
        if key in self._seen and self._seen[key] != outcome: raise MuseumError("public repeated RPC result differs")
        if self.size + len(encoded) > MAX_TRANSCRIPT - MAX_RESPONSE: raise MuseumError("public transcript byte bound")
        self._seen[key] = outcome
        self.size += len(encoded)
        # Retain an immutable JSON copy; caller mutations cannot rewrite captured evidence.
        self.rows.append(loads(encoded, maximum=MAX_RESPONSE + 65536))
        if limit is not None: raise PublicLimitError(limit)
        return result

    def call(self, target, data):
        return self.request("eth_call", [{"to": target, "data": data, "gas": "0x1312d00"}, self.block])

    def code(self, target):
        return self.request("eth_getCode", [target, self.block])

    def transcript(self):
        return dumps({"version": VERSION, "profile": PROFILE, "calls": self.rows})
