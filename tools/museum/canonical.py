"""Exact new-schema values and canonical bytes. Never normalize source text."""

import json
import re
from decimal import Decimal

import rfc8785
from Crypto.Hash import keccak


class MuseumError(ValueError):
    pass


def uint(value: str, bits: int = 256) -> int:
    if type(bits) is not int or not 1 <= bits <= 256:
        raise MuseumError("unsupported unsigned width")
    if not isinstance(value, str) or not re.fullmatch(r"0|[1-9][0-9]*", value):
        raise MuseumError("noncanonical unsigned integer")
    if len(value) > len(str((1 << bits) - 1)):
        raise MuseumError("unsigned integer overflow")
    result = int(value)
    if result >= 1 << bits:
        raise MuseumError("unsigned integer overflow")
    return result


def hex_bytes(value: str, length: int | None = None) -> bytes:
    if not isinstance(value, str) or not re.fullmatch(r"0x(?:[0-9a-f]{2})*", value):
        raise MuseumError("noncanonical hex bytes")
    result = bytes.fromhex(value[2:])
    if length is not None and len(result) != length:
        raise MuseumError("incorrect byte length")
    return result


def keccak256(data: bytes) -> str:
    return "0x" + keccak.new(digest_bits=256, data=data).hexdigest()


def schema_id(name: str) -> str:
    return keccak256(name.encode("utf-8"))


def _pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise MuseumError("duplicate JSON property")
        result[key] = value
    return result


def _check(value, depth=0):
    if depth > 64:
        raise MuseumError("JSON nesting limit")
    if isinstance(value, str):
        try:
            value.encode("utf-8")
        except UnicodeError as exc:
            raise MuseumError("invalid Unicode") from exc
    elif isinstance(value, (float, Decimal)):
        raise MuseumError("exact decimals must use typed strings")
    elif type(value) is int and abs(value) > (1 << 53) - 1:
        raise MuseumError("protocol integers must use typed strings")
    elif isinstance(value, dict):
        for key, item in value.items():
            _check(key, depth + 1)
            _check(item, depth + 1)
    elif isinstance(value, list):
        for item in value:
            _check(item, depth + 1)


def dumps(value) -> bytes:
    _check(value)
    try:
        return rfc8785.dumps(value)
    except (ValueError, TypeError) as exc:
        raise MuseumError("invalid canonical JSON") from exc


def loads(data: bytes, *, maximum=24576, canonical=False):
    if not data or len(data) > maximum:
        raise MuseumError("JSON byte limit")
    try:
        value = json.loads(data.decode("utf-8"), object_pairs_hook=_pairs,
                           parse_float=Decimal, parse_constant=lambda _: (_ for _ in ()).throw(
                               MuseumError("invalid JSON constant")))
        _check(value)
    except (UnicodeError, json.JSONDecodeError, RecursionError) as exc:
        raise MuseumError("invalid JSON") from exc
    if canonical and dumps(value) != data:
        raise MuseumError("noncanonical JSON bytes")
    return value


def word(value: str, bits=256) -> bytes:
    return uint(value, bits).to_bytes(32, "big")


def subject_id(kind: str, chain_id: str, core: str, collection_id: str,
               *, token_id=None, object_id=None, scope_type=None, scope_id=None) -> str:
    domains = {k: schema_id("6529STREAM_SUBJECT_" + k.upper() + "_V1")
               for k in ("token", "media", "scope", "collection")}
    if kind not in domains:
        raise MuseumError("unknown subject kind")
    head = hex_bytes(domains[kind], 32) + word(chain_id) + bytes(12) + hex_bytes(core, 20)
    if kind == "token":
        tail = word(token_id)
    elif kind == "collection":
        tail = word(collection_id)
    elif kind == "media":
        tail = word(collection_id) + hex_bytes(object_id, 32)
    else:
        tail = word(collection_id) + word(scope_type, 8) + hex_bytes(scope_id, 32)
    return keccak256(head + tail)


def record_chain(chain_id: str, host: str, scope_key: str, record_type: str,
                 previous: str, record_hash: str, index: str) -> str:
    return keccak256(hex_bytes(schema_id("6529STREAM_RECORD_CHAIN_V1"), 32)
                     + word(chain_id) + bytes(12) + hex_bytes(host, 20)
                     + word(scope_key) + hex_bytes(record_type, 32)
                     + hex_bytes(previous, 32) + hex_bytes(record_hash, 32) + word(index, 64))
