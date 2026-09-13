"""Offline JSON Schema shape checks plus the registered exact-integer keyword."""

from jsonschema import Draft202012Validator, FormatChecker, ValidationError, validators

from .canonical import MuseumError, loads, uint


def _unsigned(validator, bits, instance, schema):
    try:
        uint(instance, bits)
    except MuseumError as exc:
        yield ValidationError(str(exc))


StreamValidator = validators.extend(Draft202012Validator, {"x-stream-unsigned-bits": _unsigned})


def validate_document(schema_bytes: bytes, payload_bytes: bytes):
    schema, payload = loads(schema_bytes, canonical=True), loads(payload_bytes, canonical=True)

    def local_refs(value):
        if isinstance(value, dict):
            for key, item in value.items():
                if key in ("$ref", "$dynamicRef") and not item.startswith("#/"):
                    raise MuseumError("external schema resolution prohibited")
                local_refs(item)
        elif isinstance(value, list):
            for item in value:
                local_refs(item)

    local_refs(schema)
    StreamValidator.check_schema(schema)
    errors = sorted(StreamValidator(schema, format_checker=FormatChecker()).iter_errors(payload),
                    key=lambda e: str(e.path))
    if errors:
        raise MuseumError("schema validation: " + errors[0].message)
    return payload
