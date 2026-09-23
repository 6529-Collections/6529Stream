"""Strict ABI subset for the versioned Museum read adapter.

Only descriptors declared in code are accepted. Re-encoding rejects ambiguous
offsets, gaps, overlapping tails, nonzero padding and trailing return bytes.
This is not a general ABI parser or a permissive Solidity decoder.
"""

from dataclasses import dataclass

from .canonical import MuseumError, hex_bytes, keccak256


@dataclass(frozen=True)
class Array:
    item: object
    maximum: int = 64


def dynamic(kind):
    return (kind in ("bytes", "string") if isinstance(kind, str) else
            isinstance(kind, Array) or any(dynamic(k) for k in kind))


def width(kind):
    return 32 if dynamic(kind) or isinstance(kind, str) else sum(width(k) for k in kind)


def _word(value):
    if type(value) is not int or not 0 <= value < 1 << 256:
        raise MuseumError("ABI unsigned value overflow")
    return value.to_bytes(32, "big")


def encode(kinds, values):
    if type(kinds) is not tuple or type(values) not in (tuple, list) or len(kinds) != len(values):
        raise MuseumError("ABI tuple shape")
    size = sum(width(k) for k in kinds)
    heads, tails = [], []
    for kind, value in zip(kinds, values):
        part = _encode(kind, value)
        if dynamic(kind):
            heads.append(_word(size))
            tails.append(part)
            size += len(part)
        else:
            heads.append(part)
    return b"".join(heads + tails)


def _encode(kind, value):
    if isinstance(kind, Array):
        if type(value) not in (tuple, list) or len(value) > kind.maximum:
            raise MuseumError("ABI array bound")
        return _word(len(value)) + encode((kind.item,) * len(value), value)
    if isinstance(kind, tuple):
        return encode(kind, value)
    if kind in ("bytes", "string"):
        if kind == "string":
            if type(value) is not str:
                raise MuseumError("ABI string type")
            try:
                value = value.encode("utf-8")
            except UnicodeError as exc:
                raise MuseumError("ABI invalid UTF-8") from exc
        if type(value) is not bytes:
            raise MuseumError("ABI bytes type")
        return _word(len(value)) + value + bytes(-len(value) % 32)
    if kind == "address":
        return bytes(12) + hex_bytes(value, 20)
    if kind == "bool":
        if type(value) is not bool:
            raise MuseumError("ABI bool type")
        return _word(int(value))
    if kind.startswith("uint"):
        bits = int(kind[4:])
        if bits not in range(8, 257, 8) or type(value) is not int or not 0 <= value < 1 << bits:
            raise MuseumError("ABI narrow unsigned overflow")
        return _word(value)
    if kind.startswith("bytes"):
        length = int(kind[5:])
        if not 1 <= length <= 32:
            raise MuseumError("ABI bytes width")
        return hex_bytes(value, length) + bytes(32 - length)
    raise MuseumError("unsupported ABI type")


def decode(kinds, data, *, maximum=32768):
    if type(data) is not bytes or len(data) > maximum or len(data) % 32:
        raise MuseumError("ABI return byte bound/alignment")
    values = _tuple(kinds, data, 0)
    if encode(kinds, values) != data:
        raise MuseumError("noncanonical ABI return")
    return values


def _take(data, offset, length):
    if offset < 0 or length < 0 or offset + length > len(data):
        raise MuseumError("ABI truncated value")
    return data[offset:offset + length]


def _number(data, offset):
    return int.from_bytes(_take(data, offset, 32), "big")


def _tuple(kinds, data, start):
    values, cursor = [], start
    for kind in kinds:
        target = start + _number(data, cursor) if dynamic(kind) else cursor
        values.append(_decode(kind, data, target))
        cursor += width(kind)
    return tuple(values)


def _decode(kind, data, offset):
    if isinstance(kind, Array):
        count = _number(data, offset)
        if count > kind.maximum:
            raise MuseumError("ABI array bound")
        return _tuple((kind.item,) * count, data, offset + 32)
    if isinstance(kind, tuple):
        return _tuple(kind, data, offset)
    if kind in ("bytes", "string"):
        part = _take(data, offset + 32, _number(data, offset))
        if kind == "bytes":
            return part
        try:
            return part.decode("utf-8")
        except UnicodeError as exc:
            raise MuseumError("ABI invalid UTF-8") from exc
    raw = _take(data, offset, 32)
    if kind == "address":
        return "0x" + raw[12:].hex()
    if kind == "bool":
        value = int.from_bytes(raw, "big")
        if value not in (0, 1):
            raise MuseumError("ABI noncanonical bool")
        return bool(value)
    if kind.startswith("uint"):
        return int.from_bytes(raw, "big")
    if kind.startswith("bytes"):
        return "0x" + raw[:int(kind[5:])].hex()
    raise MuseumError("unsupported ABI type")


def calldata(signature, kinds=(), values=()):
    return keccak256(signature.encode("ascii"))[:10] + encode(kinds, values).hex()
