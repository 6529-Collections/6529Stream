"""Inventory source structure before mapping. Unsupported schema constructs fail."""

from dataclasses import dataclass
from jsonschema import Draft202012Validator

from .canonical import MuseumError, dumps


@dataclass(frozen=True)
class Field:
    pointer: str
    presence: str
    kind: str
    exact: bytes


def _escape(key):
    return key.replace("~", "~0").replace("/", "~1")


def inventory(schema: dict, payload) -> tuple[Field, ...]:
    def preflight(node):
        if isinstance(node, dict):
            if any(k in node for k in ("$ref", "$dynamicRef", "oneOf", "anyOf", "allOf",
                                       "if", "then", "else", "patternProperties", "prefixItems")):
                raise MuseumError("unsupported source schema inventory construct")
            for child in node.values():
                preflight(child)
        elif isinstance(node, list):
            for child in node:
                preflight(child)

    # Run before jsonschema so a hostile $ref cannot invoke any remote loader.
    preflight(schema)
    Draft202012Validator.check_schema(schema)
    errors = list(Draft202012Validator(schema).iter_errors(payload))
    if errors:
        raise MuseumError("source does not satisfy its schema")
    result = []

    def walk(spec, value, path, depth=0):
        if depth > 64:
            raise MuseumError("schema inventory depth")
        if any(k in spec for k in ("$ref", "$dynamicRef", "oneOf", "anyOf", "allOf",
                                    "if", "then", "else", "patternProperties", "prefixItems")):
            raise MuseumError("unsupported source schema inventory construct")
        kind = spec.get("type")
        if value is None:
            result.append(Field(path, "present", "null", b"null"))
        elif isinstance(value, dict):
            if kind != "object" or spec.get("additionalProperties") is not False:
                raise MuseumError("source object must have a closed schema")
            result.append(Field(path, "present", "object", dumps(sorted(value))))
            for key, child in sorted(spec.get("properties", {}).items()):
                pointer = path + "/" + _escape(key)
                if key not in value:
                    result.append(Field(pointer, "absent", "absent", b""))
                else:
                    walk(child, value[key], pointer, depth + 1)
        elif isinstance(value, list):
            if kind != "array" or not isinstance(spec.get("items"), dict):
                raise MuseumError("source array needs homogeneous item schema")
            # Index paths preserve order; lengths preserve empty versus absent.
            result.append(Field(path, "present", "array", dumps(str(len(value)))))
            for index, item in enumerate(value):
                walk(spec["items"], item, path + "/" + str(index), depth + 1)
        else:
            if (kind not in ("string", "integer", "boolean", "number") and not isinstance(kind, list)
                    and "const" not in spec and "enum" not in spec):
                raise MuseumError("source leaf must have an explicit type")
            result.append(Field(path, "present", type(value).__name__, dumps(value)))

    walk(schema, payload, "")
    return tuple(result)


def verify_coverage(fields: tuple[Field, ...], dispositions: list[dict]):
    expected = {f.pointer: f for f in fields}
    observed = {}
    for row in dispositions:
        path = row.get("pointer")
        if path in observed or path not in expected:
            raise MuseumError("duplicate or extraneous coverage path")
        if row.get("disposition") not in ("mapped", "retained_stream_only", "not_applicable"):
            raise MuseumError("invalid coverage disposition")
        if not row.get("rule") or not row.get("reason"):
            raise MuseumError("coverage needs rule and reason")
        # Byte identity also covers absent/null and structural rows.
        f = expected[path]
        if row.get("presence") != f.presence or row.get("exactHex") != "0x" + f.exact.hex():
            raise MuseumError("coverage source value mismatch")
        observed[path] = row
    if observed.keys() != expected.keys():
        raise MuseumError("missing source coverage")
    return True
