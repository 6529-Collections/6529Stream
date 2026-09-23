"""Read-only EIP-1898 transport and exact offline transcript replay.

The RPC endpoint is a trust boundary, not an Ethereum state-proof verifier.
Endpoint URLs/credentials are deliberately absent from retained transcripts.
"""

import urllib.error
import urllib.parse
import urllib.request

from .canonical import MuseumError, dumps, keccak256, loads


MAX_RESPONSE = 1048576
MAX_TRANSCRIPT = 67108864
METHODS = {"eth_chainId", "eth_getBlockByHash", "eth_call", "eth_getCode", "eth_getTransactionReceipt"}


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, response, code, message, headers, new_url):
        raise MuseumError("RPC redirect refused")


class RpcTransport:
    def __init__(self, endpoint):
        try:
            parsed = urllib.parse.urlparse(endpoint)
            hostname = parsed.hostname
        except (ValueError, TypeError):
            raise MuseumError("invalid RPC endpoint") from None
        if parsed.scheme not in ("http", "https") or not hostname or parsed.fragment:
            raise MuseumError("invalid RPC endpoint")
        if parsed.scheme == "http" and parsed.hostname not in ("127.0.0.1", "localhost", "::1"):
            raise MuseumError("nonlocal RPC requires HTTPS")
        self._endpoint = endpoint
        self._sequence = 0

    def request(self, method, params):
        if method not in METHODS:
            raise MuseumError("RPC method outside read-only profile")
        self._sequence += 1
        try:
            request = urllib.request.Request(self._endpoint, data=dumps({
                "jsonrpc": "2.0", "id": self._sequence, "method": method, "params": params}),
                headers={"Content-Type": "application/json"}, method="POST")
            with urllib.request.build_opener(_NoRedirect()).open(request, timeout=30) as response:
                raw = response.read(MAX_RESPONSE + 1)
        except (urllib.error.URLError, TimeoutError, OSError, ValueError):
            # Do not include a credential-bearing endpoint or remote error text.
            raise MuseumError("RPC transport failed") from None
        value = loads(raw, maximum=MAX_RESPONSE)
        if (not isinstance(value, dict) or value.get("jsonrpc") != "2.0"
                or type(value.get("id")) is not int or value["id"] != self._sequence
                or "error" in value or "result" not in value):
            raise MuseumError("RPC response failed or mismatched")
        return value["result"]


class ReplayTransport:
    def __init__(self, raw, expected_hash):
        if keccak256(raw) != expected_hash:
            raise MuseumError("transcript external commitment mismatch")
        value = loads(raw, maximum=MAX_TRANSCRIPT, canonical=True)
        if (not isinstance(value, dict) or set(value) != {"version", "calls"}
                or type(value["version"]) is not int or value["version"] != 1):
            raise MuseumError("transcript wire version")
        if not isinstance(value["calls"], list) or len(value["calls"]) > 100000:
            raise MuseumError("transcript call bound")
        self._rows = value["calls"]
        self._cursor = 0

    def request(self, method, params):
        if self._cursor >= len(self._rows):
            raise MuseumError("transcript missing call")
        row = self._rows[self._cursor]
        self._cursor += 1
        if not isinstance(row, dict) or set(row) != {"method", "params", "result"}:
            raise MuseumError("transcript row shape")
        if row["method"] != method or dumps(row["params"]) != dumps(params):
            raise MuseumError("transcript call/block/order mismatch")
        return row["result"]

    def finish(self):
        if self._cursor != len(self._rows):
            raise MuseumError("transcript has unconsumed calls")


class RecordingReader:
    def __init__(self, transport, block_hash):
        self.transport = transport
        self.block = {"blockHash": block_hash, "requireCanonical": True}
        self.rows = []
        self.size = 0

    def request(self, method, params):
        if method not in METHODS or len(self.rows) >= 100000:
            raise MuseumError("read profile call bound")
        result = self.transport.request(method, params)
        row = {"method": method, "params": params, "result": result}
        self.size += len(dumps(row))
        if self.size > MAX_TRANSCRIPT - 1048576:
            raise MuseumError("read profile transcript byte bound")
        self.rows.append(row)
        return result

    def call(self, target, data):
        return self.request("eth_call", [{"to": target, "data": data, "gas": "0x1312d00"}, self.block])

    def code(self, target):
        return self.request("eth_getCode", [target, self.block])

    def transcript(self):
        return dumps({"version": 1, "calls": self.rows})


def quantity(value):
    if (not isinstance(value, str) or not value.startswith("0x") or not value[2:]
            or any(c not in "0123456789abcdef" for c in value[2:])
            or (len(value) > 3 and value[2] == "0") or len(value) > 66):
        raise MuseumError("noncanonical RPC quantity")
    return int(value[2:], 16)
