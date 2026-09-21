"""Read-only RPC with retained failures and exact, externally pinned replay.

URLs, HTTP error bodies and RPC error messages are never retained. The transcript
is evidence of what one endpoint returned, not a state proof or finality proof.
"""

import hashlib
import http.client
import time
import urllib.error
import urllib.parse
import urllib.request

from tools.museum.canonical import MuseumError, dumps, loads

METHODS = frozenset({"eth_chainId", "eth_getBlockByHash", "eth_getBlockByNumber",
                     "eth_getCode", "eth_call", "eth_getLogs"})
ERRORS = frozenset({"transport_failed", "rpc_rejected", "malformed_response", "budget_exhausted"})
MAX_RESPONSE = 1048576
MAX_TRANSCRIPT = 16777216
MAX_CALLS = 2048


class RpcFailure(Exception):
    def __init__(self, code):
        if not isinstance(code, str) or code not in ERRORS:
            raise MuseumError("unknown RPC failure classification")
        self.code = code
        super().__init__(code)


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args):
        raise RpcFailure("transport_failed")


class HttpTransport:
    def __init__(self, endpoint, *, timeout=10, budget=60):
        try:
            parsed = urllib.parse.urlparse(endpoint)
            valid = parsed.scheme in ("http", "https") and parsed.hostname and not parsed.fragment
            local = parsed.hostname in ("127.0.0.1", "localhost", "::1")
        except (TypeError, ValueError):
            valid = False
        if not valid:
            raise MuseumError("invalid RPC endpoint")
        if parsed.scheme == "http" and not local:
            raise MuseumError("nonlocal RPC requires HTTPS")
        if not 0 < timeout <= 10 or not 0 < budget <= 60:
            raise MuseumError("RPC time budget outside monitor bounds")
        self._endpoint = endpoint
        self._timeout = timeout
        self._deadline = time.monotonic() + budget
        self._sequence = 0

    def request(self, method, params):
        if method not in METHODS:
            raise MuseumError("method outside read-only monitor")
        remaining = self._deadline - time.monotonic()
        if remaining <= 0:
            raise RpcFailure("budget_exhausted")
        self._sequence += 1
        try:
            request = urllib.request.Request(self._endpoint, data=dumps({
                "jsonrpc": "2.0", "id": self._sequence, "method": method, "params": params}),
                headers={"Content-Type": "application/json"}, method="POST")
            with urllib.request.build_opener(NoRedirect()).open(
                    request, timeout=min(self._timeout, remaining)) as response:
                raw = response.read(MAX_RESPONSE + 1)
        except (urllib.error.URLError, http.client.HTTPException, OSError, ValueError, TimeoutError):
            raise RpcFailure("transport_failed") from None
        try:
            value = loads(raw, maximum=MAX_RESPONSE)
        except MuseumError:
            raise RpcFailure("malformed_response") from None
        if (not isinstance(value, dict) or value.get("jsonrpc") != "2.0"
                or type(value.get("id")) is not int or value["id"] != self._sequence):
            raise RpcFailure("malformed_response")
        if "error" in value:
            raise RpcFailure("rpc_rejected")
        if "result" not in value:
            raise RpcFailure("malformed_response")
        return value["result"]


class Recorder:
    def __init__(self, transport):
        self.transport = transport
        self.rows = []
        self.size = 0

    def request(self, method, params):
        if method not in METHODS or len(self.rows) >= MAX_CALLS:
            raise MuseumError("monitor read/call bound")
        row = {"method": method, "params": params}
        failure = None
        try:
            result = self.transport.request(method, params)
            # Do not retain unrelated block fields or endpoint extension fields.
            if method in ("eth_getBlockByHash", "eth_getBlockByNumber") and isinstance(result, dict):
                result = {key: result.get(key) for key in ("hash", "number", "timestamp", "stateRoot")}
            row["result"] = result
        except RpcFailure as exc:
            failure = exc
            row["error"] = exc.code
        self.size += len(dumps(row))
        if self.size > MAX_TRANSCRIPT - 1024:
            raise MuseumError("monitor transcript byte bound")
        self.rows.append(row)
        if failure:
            raise failure
        return result

    def transcript(self):
        return dumps({"schema": "6529stream.monitor-transcript.v1", "calls": self.rows})


class Replay:
    def __init__(self, raw, expected_sha256):
        if hashlib.sha256(raw).hexdigest() != expected_sha256:
            raise MuseumError("transcript external commitment mismatch")
        value = loads(raw, maximum=MAX_TRANSCRIPT, canonical=True)
        if (not isinstance(value, dict) or set(value) != {"schema", "calls"}
                or value["schema"] != "6529stream.monitor-transcript.v1"
                or not isinstance(value["calls"], list) or len(value["calls"]) > MAX_CALLS):
            raise MuseumError("monitor transcript shape/bound")
        self.rows = value["calls"]
        self.cursor = 0

    def request(self, method, params):
        if method not in METHODS or self.cursor >= len(self.rows):
            raise MuseumError("transcript missing read-only call")
        row = self.rows[self.cursor]
        self.cursor += 1
        if (not isinstance(row, dict) or set(row) not in (
                {"method", "params", "result"}, {"method", "params", "error"})
                or row["method"] != method or dumps(row["params"]) != dumps(params)):
            raise MuseumError("transcript call/block/order mismatch")
        if "error" in row:
            raise RpcFailure(row["error"])
        return row["result"]

    def finish(self):
        if self.cursor != len(self.rows):
            raise MuseumError("transcript has unconsumed calls")
