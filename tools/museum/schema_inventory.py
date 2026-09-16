"""Exact applicable source inventory for a pinned local-reference schema profile."""

from dataclasses import dataclass
from importlib.metadata import version

from jsonschema import validators
from jsonschema.exceptions import SchemaError
from referencing import Registry, Resource
from referencing.exceptions import NoSuchResource, Unresolvable
from referencing.jsonschema import DRAFT202012

from .canonical import MuseumError, dumps, keccak256, loads
from .coverage import Field, _escape
from .linked_art import format_checker
from .validation import StreamValidator


EVALUATION_PROFILE_BYTES = dumps({
    "name": "STREAM_LOCAL_SCHEMA_INVENTORY_V1", "mode": "candidate_unregistered",
    "jsonschema": "4.25.1", "rfc3986-validator": "0.1.1", "rfc3339-validator": "0.1.4",
    "rfc8785": "0.1.4", "instanceDepth": "64", "schemaNodes": "20000", "evaluationSteps": "100000",
    "validationKeywordSteps": "100000", "formats": "exact-uri-rfc3339-no-leap-seconds-v1",
    "dialect": "2020-12 only; checked declarations omitted from private evaluation copy to retain custom keywords and budgets",
    "input": "exact canonical JSON with typed decimals and protocol integer strings; no source conversion",
    "branches": "all valid anyOf; exact oneOf; all allOf",
    "references": "local JSON Pointer only, no percent encoding; active schema-location/instance-path cycle detection",
    "coverage": "all actual nodes/array positions and applicable absent declared properties",
})
EVALUATION_PROFILE_HASH = keccak256(EVALUATION_PROFILE_BYTES)

ANNOTATIONS = {"$schema", "$id", "$comment", "title", "description", "examples", "default", "deprecated",
               "readOnly", "writeOnly", "x-stream-document-status", "x-stream-schema-id",
               "x-stream-semantic-checks", "x-stream-profile"}
KEYWORDS = {"$defs", "$ref", "type", "const", "enum", "properties", "required", "additionalProperties",
            "items", "minItems", "maxItems", "uniqueItems", "minProperties", "maxProperties",
            "minLength", "maxLength", "pattern", "minimum", "maximum", "exclusiveMinimum",
            "exclusiveMaximum", "multipleOf", "oneOf", "anyOf", "allOf", "format", "x-stream-unsigned-bits"}


@dataclass(frozen=True)
class BranchDecision:
    schema_hash: str
    schema_location: str
    instance_pointer: str
    keyword: str
    valid_branches: tuple[str, ...]


@dataclass(frozen=True)
class Inventory:
    schema_hash: str
    payload_hash: str
    evaluation_hash: str
    fields: tuple[Field, ...]
    branches: tuple[BranchDecision, ...]


def inventory_exact(schema_bytes, payload_bytes, *, schema_hash, payload_hash, evaluation_hash):
    if (keccak256(schema_bytes) != schema_hash or keccak256(payload_bytes) != payload_hash
            or evaluation_hash != EVALUATION_PROFILE_HASH):
        raise MuseumError("inventory input or evaluation hash mismatch")
    profile = loads(EVALUATION_PROFILE_BYTES)
    for package in ("jsonschema", "rfc3986-validator", "rfc3339-validator", "rfc8785"):
        if version(package) != profile[package]:
            raise MuseumError("inventory evaluator version mismatch")
    schema = loads(schema_bytes, maximum=524288, canonical=True)
    payload = loads(payload_bytes, canonical=True)
    nodes, validation_steps = 0, 0
    locations, references = {}, []

    def preflight(spec, location="#", depth=0):
        nonlocal nodes
        nodes += 1
        if nodes > 20000 or depth > 64 or not isinstance(spec, dict):
            raise MuseumError("unsupported or oversized inventory schema")
        if set(spec) - ANNOTATIONS - KEYWORDS:
            raise MuseumError("unsupported inventory schema keyword")
        locations[location] = spec
        if "$id" in spec and location != "#":
            raise MuseumError("nested schema identity outside inventory profile")
        if "$schema" in spec and spec["$schema"] != "https://json-schema.org/draft/2020-12/schema":
            raise MuseumError("inventory schema dialect mismatch")
        if "format" in spec and spec["format"] not in ("uri", "date-time"):
            raise MuseumError("unsupported inventory format")
        if "$ref" in spec and (not isinstance(spec["$ref"], str)
                               or "%" in spec["$ref"]
                               or not (spec["$ref"] == "#" or spec["$ref"].startswith("#/"))):
            raise MuseumError("inventory reference must be local")
        if "$ref" in spec:
            references.append(spec["$ref"])
        if "x-stream-unsigned-bits" in spec:
            bits = spec["x-stream-unsigned-bits"]
            if type(bits) is not int or not 1 <= bits <= 256:
                raise MuseumError("unsupported inventory unsigned width")
        for key in ("$defs", "properties"):
            if not isinstance(spec.get(key, {}), dict):
                raise MuseumError("inventory schema map required")
            for name, child in spec.get(key, {}).items():
                preflight(child, location + "/" + key + "/" + _escape(name), depth + 1)
        for key in ("oneOf", "anyOf", "allOf"):
            if not isinstance(spec.get(key, []), list):
                raise MuseumError("inventory schema branch array required")
            for index, child in enumerate(spec.get(key, [])):
                preflight(child, location + "/" + key + "/" + str(index), depth + 1)
        if "items" in spec:
            preflight(spec["items"], location + "/items", depth + 1)
        if "additionalProperties" in spec and spec["additionalProperties"] is not False:
            raise MuseumError("inventory requires closed object declarations")

    preflight(schema)
    for ref in references:
        if ref not in locations:
            raise MuseumError("local reference does not select an admitted schema location")
    try:
        StreamValidator.check_schema(schema)
    except SchemaError as exc:
        raise MuseumError("invalid inventory schema") from exc
    # jsonschema.evolve selects its ordinary validator when it encounters a
    # '$schema' declaration. All declarations were checked above; omit them
    # only from this private parsed evaluation tree so root references cannot
    # drop our unsigned keyword or work budget. Original bytes/hash stay exact.
    for spec in locations.values():
        spec.pop("$schema", None)
    identity = schema.get("$id", "urn:6529stream:inventory:source")

    def retrieve(uri):
        raise NoSuchResource(ref=uri)

    resource = Resource.from_contents(schema, default_specification=DRAFT202012)
    registry = Registry(retrieve=retrieve).with_resource(identity, resource)

    def budgeted(function):
        def check(validator, keyword_value, instance, subschema):
            nonlocal validation_steps
            validation_steps += 1
            if validation_steps > 100000:
                raise MuseumError("inventory validation keyword step limit")
            yield from function(validator, keyword_value, instance, subschema)
        return check

    evaluator = validators.extend(StreamValidator, {k: budgeted(v) for k, v in StreamValidator.VALIDATORS.items()})
    validator = evaluator(schema, registry=registry, format_checker=format_checker())
    try:
        if not validator.is_valid(payload):
            raise MuseumError("source does not satisfy complete schema")
    except (RecursionError, Unresolvable) as exc:
        raise MuseumError("schema validation recursion limit") from exc

    fields, decisions, steps = [], [], 0

    def step():
        nonlocal steps
        steps += 1
        if steps > 100000:
            raise MuseumError("inventory evaluation step limit")

    def resolve(ref):
        return locations[ref]

    def applicable(spec, location, value, path, active):
        step()
        key = (location, path)
        if key in active:
            raise MuseumError("non-advancing schema reference cycle")
        active = active | {key}
        result = [(spec, location)]
        if "$ref" in spec:
            ref = spec["$ref"]
            result += applicable(resolve(ref), ref, value, path, active)
        for keyword in ("allOf", "oneOf", "anyOf"):
            if keyword not in spec:
                continue
            branches = spec[keyword]
            try:
                valid = tuple(i for i, branch in enumerate(branches) if validator.evolve(schema=branch).is_valid(value))
            except (RecursionError, Unresolvable) as exc:
                raise MuseumError("branch validation recursion limit") from exc
            if ((keyword == "allOf" and len(valid) != len(branches))
                    or (keyword == "oneOf" and len(valid) != 1) or not valid):
                raise MuseumError("branch evidence disagrees with whole validation")
            locations = tuple(location + "/" + keyword + "/" + str(i) for i in valid)
            decisions.append(BranchDecision(schema_hash, location, path, keyword, locations))
            for i, child_location in zip(valid, locations):
                result += applicable(branches[i], child_location, value, path, active)
        return result

    def walk(specs, value, path, depth=0):
        if depth > 64:
            raise MuseumError("inventory instance depth limit")
        effective = []
        for spec, location in specs:
            effective += applicable(spec, location, value, path, set())
        effective = [(spec, location) for location, spec in {location: spec for spec, location in effective}.items()]
        if isinstance(value, dict):
            if not any(spec.get("additionalProperties") is False for spec, _ in effective):
                raise MuseumError("source object has no applicable closed declaration")
            properties = {}
            for spec, location in effective:
                for name, child in spec.get("properties", {}).items():
                    step()
                    properties.setdefault(name, []).append((child, location + "/properties/" + _escape(name)))
            if set(value) - set(properties):
                raise MuseumError("actual source property missing from applicable schema")
            fields.append(Field(path, "present", "object", dumps(sorted(value))))
            for name, children in sorted(properties.items()):
                step()
                child_path = path + "/" + _escape(name)
                if name not in value:
                    fields.append(Field(child_path, "absent", "absent", b""))
                else:
                    walk(children, value[name], child_path, depth + 1)
        elif isinstance(value, list):
            children = [(spec["items"], location + "/items") for spec, location in effective if "items" in spec]
            if not children:
                raise MuseumError("source array has no applicable homogeneous item schema")
            fields.append(Field(path, "present", "array", dumps(str(len(value)))))
            for index, item in enumerate(value):
                step()
                walk(children, item, path + "/" + str(index), depth + 1)
        else:
            if not any(any(key in spec for key in ("type", "const", "enum")) for spec, _ in effective):
                raise MuseumError("source leaf has no explicit declaration")
            fields.append(Field(path, "present", "null" if value is None else type(value).__name__, dumps(value)))

    walk([(schema, "#")], payload, "")
    unique_decisions = tuple(sorted(set(decisions), key=lambda d: (d.instance_pointer, d.schema_location, d.keyword)))
    return Inventory(schema_hash, payload_hash, evaluation_hash, tuple(fields), unique_decisions)


def main():
    import argparse
    from pathlib import Path
    import sys
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("schema", type=Path)
    parser.add_argument("source", type=Path)
    parser.add_argument("--schema-hash", required=True)
    parser.add_argument("--source-hash", required=True)
    parser.add_argument("--evaluation-hash", required=True)
    args = parser.parse_args()
    with args.schema.open("rb") as file:
        schema = file.read(524289)
    with args.source.open("rb") as file:
        source = file.read(24577)
    result = inventory_exact(schema, source, schema_hash=args.schema_hash, payload_hash=args.source_hash,
                             evaluation_hash=args.evaluation_hash)
    sys.stdout.buffer.write(dumps({
        "mode": "candidate_source_inventory", "schemaHash": result.schema_hash,
        "sourceHash": result.payload_hash, "evaluationProfileHash": result.evaluation_hash,
        "fields": [{"pointer": f.pointer, "presence": f.presence, "kind": f.kind,
                    "exactHex": "0x" + f.exact.hex()} for f in result.fields],
        "branches": [{"schemaHash": b.schema_hash, "schemaLocation": b.schema_location,
                      "instancePointer": b.instance_pointer, "keyword": b.keyword,
                      "validBranches": b.valid_branches} for b in result.branches],
        "claims": {"sourceAuthority": False, "registeredProfile": False, "completeMuseumConformance": False},
    }) + b"\n")


if __name__ == "__main__":
    main()
