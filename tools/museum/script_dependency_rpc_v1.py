"""Bounded script-dependency RPC observations, including unavailable calls.

Only eth_call may retain a sanitized unavailable outcome. A failed read never
means an absent record. Mandatory source reads use call() and therefore abort;
the source consumer must explicitly choose call_outcome() for optional reads.
"""
import http.client
import urllib.error
import urllib.request

from . import public_history_rpc as public
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads

PROFILE = 'STREAM_MUSEUM_SCRIPT_DEPENDENCY_RPC_V1'
VERSION = 1
MAX_RESPONSE = public.MAX_RESPONSE
MAX_TRANSCRIPT = public.MAX_TRANSCRIPT
MAX_CALLS = public.MAX_CALLS
MAX_REQUEST = 65536
UNAVAILABLE_KINDS = {'provider_error', 'response_size', 'transport_unavailable'}
PublicLimitError = public.PublicLimitError
PROFILE_BYTES = dumps({'id': PROFILE, 'version': '1', 'transcriptVersion': VERSION,
    'basePublicHistoryProfileHash': public.PROFILE_HASH,
    'methods': sorted(public.METHODS), 'maximumResponseBytes': str(MAX_RESPONSE),
    'maximumRequestBytes': str(MAX_REQUEST), 'maximumTranscriptBytes': str(MAX_TRANSCRIPT),
    'maximumCalls': str(MAX_CALLS),
    'parameters': 'Unchanged closed public-history method shapes and EIP-1898 requireCanonical block hashes.',
    'outcomes': 'Exactly result, original public log-limit, or eth_call-only unavailable {kind,code}. '
        'Provider errors retain only a signed int32 JSON-RPC code. Size/transport failures retain code null. '
        'No remote message, data, endpoint, HTTP status or exception text is retained.',
    'strictness': 'Malformed envelopes, mismatched response IDs and noncanonical successful call bytes abort. '
        'Empty successful 0x is available bytes, never inferred absence. Mandatory calls rethrow unavailable.',
    'replay': 'Externally pinned canonical transcript, exact ordered requests/outcomes, repeated query consistency '
        'and complete consumption. Captured rows and replay results do not alias caller-owned data.',
    'trust': 'Provider-admitted observations only; unavailable is not native rejection, record absence, '
        'current eligibility, consensus, source authenticity or actual-chain acceptance.'})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _params(method, params):
    if len(dumps([method, params])) > MAX_REQUEST:
        raise MuseumError('script RPC request byte bound')
    public._params(method, params)


def _unavailable(value):
    if (type(value) is not dict or set(value) != {'kind', 'code'}
            or type(value['kind']) is not str or value['kind'] not in UNAVAILABLE_KINDS):
        raise MuseumError('script RPC unavailable shape')
    code = value['code']
    if value['kind'] == 'provider_error':
        if type(code) is not int or not -(1 << 31) <= code < (1 << 31):
            raise MuseumError('script RPC unavailable provider code')
    elif code is not None:
        raise MuseumError('script RPC unavailable code must be null')


class CallUnavailable(MuseumError):
    def __init__(self, kind, code=None):
        value = {'kind': kind, 'code': code}
        _unavailable(value)
        self.kind, self.code = kind, code
        super().__init__('script RPC call unavailable: ' + kind)


class RpcTransport(public.PublicRpcTransport):
    """Use the unchanged transport for mandatory non-call public methods."""
    def request(self, method, params):
        _params(method, params)
        if method != 'eth_call':
            return super().request(method, params)
        self._sequence += 1
        body = dumps({'jsonrpc': '2.0', 'id': self._sequence, 'method': method, 'params': params})
        try:
            request = urllib.request.Request(self._endpoint, data=body,
                headers={'Content-Type': 'application/json', 'User-Agent': '6529Stream-readonly-capture/1'}, method='POST')
            with urllib.request.build_opener(public._NoRedirect()).open(request, timeout=30) as response:
                raw = response.read(MAX_RESPONSE + 1)
        except urllib.error.HTTPError as exc:
            raise CallUnavailable('response_size' if exc.code == 413 else 'transport_unavailable') from None
        except (urllib.error.URLError, http.client.HTTPException, TimeoutError, OSError, ValueError):
            raise CallUnavailable('transport_unavailable') from None
        if len(raw) > MAX_RESPONSE:
            raise CallUnavailable('response_size')
        try:
            value = loads(raw, maximum=MAX_RESPONSE)
        except (ValueError, TypeError, RecursionError):
            raise MuseumError('script RPC malformed response') from None
        if (type(value) is not dict or set(value) not in ({'jsonrpc', 'id', 'result'}, {'jsonrpc', 'id', 'error'})
                or value['jsonrpc'] != '2.0' or type(value['id']) is not int or value['id'] != self._sequence):
            raise MuseumError('script RPC mismatched response')
        if 'error' in value:
            error = value['error']
            if type(error) is not dict or type(error.get('code')) is not int or not -(1 << 31) <= error['code'] < (1 << 31):
                raise MuseumError('script RPC invalid provider error')
            raise CallUnavailable('provider_error', error['code'])
        try:
            hex_bytes(value['result'])
        except (ValueError, TypeError):
            raise MuseumError('script RPC noncanonical call result') from None
        return value['result']


def _row(row):
    if type(row) is not dict or set(row) not in (
            {'method', 'params', 'result'}, {'method', 'params', 'limit'}, {'method', 'params', 'unavailable'}):
        raise MuseumError('script transcript row shape')
    _params(row['method'], row['params'])
    if 'unavailable' in row:
        if row['method'] != 'eth_call':
            raise MuseumError('script unavailable outside eth_call')
        _unavailable(row['unavailable'])
    else:
        public._row(row)
        if 'result' in row:
            if len(dumps(row['result'])) > MAX_RESPONSE:
                raise MuseumError('script transcript response byte bound')
            if row['method'] == 'eth_call':
                hex_bytes(row['result'])


def _outcome(row):
    return dumps({key: row[key] for key in ('result', 'limit', 'unavailable') if key in row})


class ReplayTransport:
    def __init__(self, raw, expected_hash):
        if type(raw) is not bytes or not 0 < len(raw) <= MAX_TRANSCRIPT:
            raise MuseumError('script transcript byte bound')
        hex_bytes(expected_hash, 32)
        if keccak256(raw) != expected_hash:
            raise MuseumError('script transcript external commitment mismatch')
        value = loads(raw, maximum=MAX_TRANSCRIPT, canonical=True)
        if (type(value) is not dict or set(value) != {'version', 'profile', 'calls'}
                or type(value['version']) is not int or value['version'] != VERSION or value['profile'] != PROFILE):
            raise MuseumError('script transcript profile/version')
        if type(value['calls']) is not list or len(value['calls']) > MAX_CALLS:
            raise MuseumError('script transcript call bound')
        seen = {}
        for row in value['calls']:
            _row(row)
            key, outcome = dumps([row['method'], row['params']]), _outcome(row)
            if seen.setdefault(key, outcome) != outcome:
                raise MuseumError('script repeated RPC outcome differs')
        self._rows, self._cursor = value['calls'], 0

    def request(self, method, params):
        _params(method, params)
        if self._cursor >= len(self._rows):
            raise MuseumError('script transcript missing call')
        row = self._rows[self._cursor]
        if row['method'] != method or dumps(row['params']) != dumps(params):
            raise MuseumError('script transcript call/block/order mismatch')
        self._cursor += 1
        if 'unavailable' in row:
            raise CallUnavailable(**row['unavailable'])
        if 'limit' in row:
            raise PublicLimitError(row['limit'])
        return loads(dumps(row['result']), maximum=MAX_RESPONSE)

    def finish(self):
        if self._cursor != len(self._rows):
            raise MuseumError('script transcript unconsumed calls')


class RecordingReader:
    def __init__(self, transport, block_hash):
        hex_bytes(block_hash, 32)
        self.transport = transport
        self.block = {'blockHash': block_hash, 'requireCanonical': True}
        self.rows, self.size, self._seen = [], 0, {}

    def request(self, method, params):
        _params(method, params)
        if len(self.rows) >= MAX_CALLS:
            raise MuseumError('script read call bound')
        params_raw = dumps(params)
        row = {'method': method, 'params': loads(params_raw, maximum=MAX_REQUEST)}
        failure = None
        try:
            result = self.transport.request(method, loads(params_raw, maximum=MAX_REQUEST))
            if len(dumps(result)) > MAX_RESPONSE:
                if method == 'eth_call':
                    raise CallUnavailable('response_size')
                if method == 'eth_getLogs':
                    raise PublicLimitError('response_size')
                raise MuseumError('script read response byte bound')
            if method == 'eth_call':
                hex_bytes(result)
            row['result'] = result
        except CallUnavailable as exc:
            if method != 'eth_call':
                raise MuseumError('script unavailable outside eth_call') from None
            row['unavailable'] = {'kind': exc.kind, 'code': exc.code}
            failure = CallUnavailable(exc.kind, exc.code)
        except PublicLimitError as exc:
            if method != 'eth_getLogs':
                raise MuseumError('script limit outside log query') from None
            row['limit'] = exc.kind
            failure = PublicLimitError(exc.kind)
        _row(row)
        encoded = dumps(row)
        key, outcome = dumps([method, row['params']]), _outcome(row)
        if key in self._seen and self._seen[key] != outcome:
            raise MuseumError('script repeated RPC outcome differs')
        if self.size + len(encoded) > MAX_TRANSCRIPT - MAX_RESPONSE:
            raise MuseumError('script transcript byte bound')
        self._seen[key] = outcome
        self.size += len(encoded)
        self.rows.append(loads(encoded, maximum=MAX_RESPONSE + MAX_REQUEST))
        if failure is not None:
            raise failure from None
        return result

    def call(self, target, data):
        return self.request('eth_call', [{'to': target, 'data': data, 'gas': '0x1312d00'}, self.block])

    def call_outcome(self, target, data):
        try:
            return {'status': 'available', 'result': self.call(target, data)}
        except CallUnavailable as exc:
            return {'status': 'unavailable', 'kind': exc.kind, 'code': exc.code}

    def code(self, target):
        return self.request('eth_getCode', [target, self.block])

    def transcript(self):
        return dumps({'version': VERSION, 'profile': PROFILE, 'calls': self.rows})
