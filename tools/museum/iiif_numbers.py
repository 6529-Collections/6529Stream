"""Exact JSON numbers for the prospective IIIF target only.

Stream source canonicalization remains in canonical.py and still rejects floats.
This is a deterministic bounded target encoding, not RFC8785 canonicalization.
"""

from dataclasses import dataclass
from decimal import Decimal
import json
import re

from .canonical import MuseumError, _pairs

MAX_BYTES = 16 * 1024 * 1024
MAX_DEPTH = 64
MAX_NODES = 65536
MAX_DIGITS = 128
DECIMAL_LEXICAL = re.compile(r"(?:0|[1-9][0-9]*)(?:\.[0-9]+)?\Z")


@dataclass(frozen=True)
class ExactDecimal:
    lexical: str

    def __post_init__(self):
        if (not isinstance(self.lexical, str) or len(self.lexical) > MAX_DIGITS
                or DECIMAL_LEXICAL.fullmatch(self.lexical) is None):
            raise MuseumError("unsupported exact target decimal spelling")

    @property
    def value(self):
        return Decimal(self.lexical)


def target_dumps(value):
    """Encode exact decimal lexicals and integer values without float conversion."""
    count = 0

    def encode(v, depth):
        nonlocal count
        count += 1
        if count > MAX_NODES or depth > MAX_DEPTH:
            raise MuseumError("target JSON structure limit")
        if v is None:
            return "null"
        if type(v) is bool:
            return "true" if v else "false"
        if isinstance(v, ExactDecimal):
            return v.lexical
        if type(v) is int:
            if abs(v) > (1 << 256) - 1:
                raise MuseumError("target JSON integer limit")
            return str(v)
        if isinstance(v, str):
            v.encode("utf-8")
            return json.dumps(v, ensure_ascii=False, separators=(",", ":"))
        if isinstance(v, list):
            return "[" + ",".join(encode(item, depth + 1) for item in v) + "]"
        if isinstance(v, dict):
            if any(not isinstance(key, str) for key in v):
                raise MuseumError("target JSON keys must be strings")
            return "{" + ",".join(encode(key, depth + 1) + ":" + encode(v[key], depth + 1)
                                  for key in sorted(v)) + "}"
        raise MuseumError("target JSON requires exact values; float unsupported")

    try:
        raw = encode(value, 0).encode("utf-8")
    except (UnicodeError, RecursionError) as exc:
        raise MuseumError("invalid target JSON value") from exc
    if len(raw) > MAX_BYTES:
        raise MuseumError("target JSON byte limit")
    return raw


def target_loads(raw):
    """Parse a target without rounding; reject duplicate keys and unsupported numbers.

    Return Decimal for fraction tokens so a local JSON Schema can validate numeric
    values. Retain raw target bytes separately for exact regeneration comparison.
    """
    if type(raw) is not bytes or len(raw) > MAX_BYTES:
        raise MuseumError("target JSON byte limit")

    def fraction(text):
        return ExactDecimal(text).value

    def integer(text):
        if len(text) > 79:
            raise MuseumError("target JSON integer limit")
        value = int(text)
        if abs(value) > (1 << 256) - 1:
            raise MuseumError("target JSON integer limit")
        return value

    def constant(_):
        raise MuseumError("nonfinite target JSON constant")

    try:
        value = json.loads(raw.decode("utf-8"), object_pairs_hook=_pairs,
                           parse_float=fraction, parse_int=integer, parse_constant=constant)
        stack, count = [(value, 0)], 0
        while stack:
            item, depth = stack.pop()
            count += 1
            if count > MAX_NODES or depth > MAX_DEPTH:
                raise MuseumError("target JSON structure limit")
            if isinstance(item, str):
                item.encode("utf-8")
            elif isinstance(item, dict):
                stack.extend((part, depth + 1) for pair in item.items() for part in pair)
            elif isinstance(item, list):
                stack.extend((part, depth + 1) for part in item)
    except (ValueError, UnicodeError, RecursionError) as exc:
        raise MuseumError("invalid target JSON") from exc
    return value
