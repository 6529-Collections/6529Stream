"""Explicit duplicate-property interpretation for one pinned schema source.

Ordinary source records and JSON-LD documents still reject every duplicate key.
This parser retains ordered pairs until the exact schema-only rule is checked.
"""

import json
import math

from .canonical import MuseumError, keccak256


class _ObjectPairs(list):
    pass


def conjoin_duplicate_schema(raw: bytes, rule: dict):
    if (rule.get("operation") != "conjoin_exact_duplicate_property"
            or set(rule) != {"schemaUri", "contentHash", "operation", "pointer", "expectedValues", "reason"}
            or keccak256(raw) != rule["contentHash"]
            or rule["pointer"] != "/properties/used_for"
            or not isinstance(rule["expectedValues"], list) or len(rule["expectedValues"]) != 2
            or not all(isinstance(v, dict) for v in rule["expectedValues"])):
        raise MuseumError("schema duplicate interpretation identity mismatch")
    applied = False

    def constant(_):
        raise MuseumError("nonfinite schema constant")

    def convert(node, pointer="", depth=0):
        nonlocal applied
        if depth > 64:
            raise MuseumError("schema nesting limit")
        if isinstance(node, _ObjectPairs):
            groups = {}
            for key, value in node:
                key.encode("utf-8")
                child = pointer + "/" + key.replace("~", "~0").replace("/", "~1")
                groups.setdefault(key, []).append(convert(value, child, depth + 1))
            result = {}
            for key, values in groups.items():
                if len(values) == 1:
                    result[key] = values[0]
                else:
                    child = pointer + "/" + key.replace("~", "~0").replace("/", "~1")
                    if applied or child != rule["pointer"] or values != rule["expectedValues"]:
                        raise MuseumError("unapproved duplicate schema key")
                    result[key] = {"allOf": values}
                    applied = True
            return result
        if isinstance(node, list):
            return [convert(v, pointer + "/" + str(i), depth + 1) for i, v in enumerate(node)]
        if isinstance(node, str):
            node.encode("utf-8")
        elif isinstance(node, float) and not math.isfinite(node):
            raise MuseumError("nonfinite schema number")
        elif type(node) is int and abs(node) > (1 << 53) - 1:
            raise MuseumError("inexact schema integer")
        return node

    try:
        result = convert(json.loads(raw.decode("utf-8"), object_pairs_hook=_ObjectPairs, parse_constant=constant))
    except (ValueError, UnicodeError, RecursionError) as exc:
        raise MuseumError("invalid interpreted schema JSON") from exc
    if not applied:
        raise MuseumError("unapplied duplicate schema interpretation")
    return result
