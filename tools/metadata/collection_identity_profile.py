"""Prospective collection-identity JSON and bounded supplied-context consistency.

The component lives at properties.stream.collection. This module does not read
Core, derive an AA-DISPLAY attribution line, or authenticate supplied context.
The examined native renderer does not yet emit this normative component.
"""

import argparse
import json
from pathlib import Path

import jsonschema
import rfc8785
from Crypto.Hash import keccak


ROOT = Path(__file__).resolve().parents[2]
SCHEMA_NAME = "STREAM_COLLECTION_IDENTITY_V1"
STATUS = "prospective_unregistered"
MAX_UINT256 = (1 << 256) - 1
# An interpreter resource ceiling, not a new native text-field restriction.
# It accommodates the existing renderer's bounded collection/display fields.
MAX_COMPONENT_BYTES = 65536
FIELDS = ("id", "name", "artist", "serial", "catalog_number")
NUMERIC_FIELDS = ("id", "serial", "catalog_number")
SOURCE_REVISION = "6292287bdabe1d2452f11b1254ced325e259b731"
QUALIFICATION = (
    "Prospective unregistered collection-identity component. Validation establishes "
    "the five-member JSON shape and, when requested, equality to explicitly supplied "
    "Core identity, global token ID, typed collection name and derived AA-DISPLAY line. "
    "It does not authenticate those inputs, prove renderer conformance or schema "
    "registration, or establish artist identity, authority, attribution state or truth."
)


class CollectionIdentityError(ValueError):
    pass


def canonical(value):
    """RFC8785 bytes, without a trailing newline or Unicode normalization."""
    return rfc8785.dumps(value)


def digest(raw):
    return "0x" + keccak.new(digest_bits=256, data=raw).hexdigest()


def _uint256_pattern():
    """Portable ECMA/Python regex with an exact decimal-string uint256 ceiling."""
    ceiling = str(MAX_UINT256)
    alternatives = ["0", "[1-9][0-9]{0,76}"]
    for index, character in enumerate(ceiling):
        low, high = (1 if index == 0 else 0), int(character) - 1
        if high < low:
            continue
        digit = str(low) if low == high else f"[{low}-{high}]"
        remaining = len(ceiling) - index - 1
        suffix = f"[0-9]{{{remaining}}}" if remaining else ""
        alternatives.append(ceiling[:index] + digit + suffix)
    alternatives.append(ceiling)
    # Unlike $, this end assertion cannot accept a final newline.
    return "^(?:" + "|".join(alternatives) + r")(?![\s\S])"


UINT256_PATTERN = _uint256_pattern()


def schema():
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "title": SCHEMA_NAME,
        "description": QUALIFICATION,
        "type": "object",
        "properties": {
            "id": {"$ref": "#/$defs/uint256"},
            "name": {"type": "string"},
            "artist": {"type": "string"},
            "serial": {"$ref": "#/$defs/uint256"},
            "catalog_number": {"$ref": "#/$defs/uint256"},
        },
        "required": list(FIELDS),
        "additionalProperties": False,
        "$defs": {
            "uint256": {
                "type": "string",
                "minLength": 1,
                "maxLength": 78,
                "pattern": UINT256_PATTERN,
                "description": "Exact base-10 uint256; no sign, whitespace or redundant leading zero.",
            }
        },
        "x-stream-status": STATUS,
        "x-stream-component-path": "properties.stream.collection",
        "x-stream-normative-home": "docs/collection-metadata-contract.md#collection-identity-token-json-cmc-collection-identity-json",
        "x-stream-constraints": [
            "The schema document is canonical RFC8785 JSON. Rendered component JSON need not itself be RFC8785 ordered.",
            "id and serial must equal the Core tokenCollectionIdentity(tokenId) collectionId and collectionSerial. catalog_number is the same global tokenId, not a facade-local ID.",
            "name equals typed CollectionIdentity.name. artist equals the separately derived AA-DISPLAY attribution line, never an independent source of attribution authority.",
            "This component does not encode attribution state or authenticate artist names. Platform and degraded display treatment remains owned by AA-DISPLAY.",
            "No additional nonempty-string or text-length rule is introduced. An empty string passes component shape validation and still requires the same exact supplied-context comparison.",
            "Zero is a valid uint256 lexical value; an allocated-token consistency check additionally requires mappingExists and nonzero collectionId, collectionSerial and tokenId.",
        ],
    }


SCHEMA_BYTES = canonical(schema())
SCHEMA_HASH = digest(SCHEMA_BYTES)
_VALIDATOR = jsonschema.Draft202012Validator(schema())


def validate(value):
    """Validate one component object, preserving its exact string values.

    The 64 KiB ceiling bounds this interpreter, independently of the schema's
    member semantics. Empty text and all valid Unicode scalars are retained.
    """
    if type(value) is not dict or set(value) != set(FIELDS):
        raise CollectionIdentityError("collection identity requires exactly five members")
    if any(type(value[field]) is not str for field in FIELDS):
        raise CollectionIdentityError("collection identity members must be strings")
    if any(len(value[field]) > MAX_COMPONENT_BYTES for field in FIELDS):
        raise CollectionIdentityError("collection identity interpreter byte bound")
    try:
        raw = canonical(value)
        if len(raw) > MAX_COMPONENT_BYTES:
            raise CollectionIdentityError("collection identity interpreter byte bound")
        _VALIDATOR.validate(value)
    except (jsonschema.ValidationError, ValueError, TypeError, UnicodeError) as exc:
        if isinstance(exc, CollectionIdentityError):
            raise
        raise CollectionIdentityError("invalid collection identity component") from exc
    return dict(value)


def _pairs(rows):
    value = {}
    for key, item in rows:
        if key in value:
            raise CollectionIdentityError("duplicate JSON member")
        value[key] = item
    return value


def validate_bytes(raw, *, canonical=False):
    """Validate exact bounded UTF-8 bytes; optionally require RFC8785 encoding."""
    if type(canonical) is not bool:
        raise CollectionIdentityError("canonical option must be boolean")
    if type(raw) is not bytes or not 0 < len(raw) <= MAX_COMPONENT_BYTES:
        raise CollectionIdentityError("collection identity interpreter byte bound")

    def reject_number(_):
        raise CollectionIdentityError("collection identity numbers must be decimal strings")

    try:
        value = json.loads(raw.decode("utf-8"), object_pairs_hook=_pairs,
            parse_int=reject_number, parse_float=reject_number, parse_constant=reject_number)
        result = validate(value)
        if canonical and rfc8785.dumps(result) != raw:
            raise CollectionIdentityError("noncanonical collection identity JSON")
        return result
    except (ValueError, TypeError, UnicodeError, RecursionError) as exc:
        if isinstance(exc, CollectionIdentityError):
            raise
        raise CollectionIdentityError("invalid collection identity JSON") from exc


def _context_uint(value, name):
    if type(value) is not int or not 1 <= value <= MAX_UINT256:
        raise CollectionIdentityError(name + " must be a nonzero uint256 integer")
    return str(value)


def validate_context(value, *, core_identity, token_id, collection_name, artist_display_line):
    """Check equality to supplied facts, without fetching or authenticating them.

    core_identity is the exact decoded four-field Core tuple
    (mappingExists, collectionId, collectionSerial, burned). Burned mappings are
    retained and accepted; the tuple alone does not prove mint completion.
    artist_display_line must already be derived under AA-DISPLAY by the caller.
    No platform/degraded default or current-authority inference is performed.
    """
    result = validate(value)
    if (type(core_identity) not in (tuple, list) or len(core_identity) != 4
            or type(core_identity[0]) is not bool or type(core_identity[3]) is not bool):
        raise CollectionIdentityError("Core identity must be the exact four-field tuple")
    if not core_identity[0]:
        raise CollectionIdentityError("Core identity has no token mapping")
    if type(collection_name) is not str or type(artist_display_line) is not str:
        raise CollectionIdentityError("collection name and AA display line must be strings")
    expected = {
        "id": _context_uint(core_identity[1], "collectionId"),
        "name": collection_name,
        "artist": artist_display_line,
        "serial": _context_uint(core_identity[2], "collectionSerial"),
        "catalog_number": _context_uint(token_id, "tokenId"),
    }
    if result != expected:
        raise CollectionIdentityError("collection identity differs from supplied context")
    return result


def examples():
    artist = {"id": "1", "name": "Example Collection", "artist": "Example Artist",
        "serial": "23", "catalog_number": "123"}
    platform = {"id": "2", "name": "Example Platform Collection", "artist": "",
        "serial": "1", "catalog_number": "124"}
    degraded = {"id": "1", "name": "Example Collection", "artist": "",
        "serial": "24", "catalog_number": "125"}
    large = {"id": "9007199254740993", "name": "Exact Unicode: e\u0301 🎨", "artist": "",
        "serial": str(MAX_UINT256), "catalog_number": str(MAX_UINT256)}
    components = {"artist-bound.json": artist, "platform-works-supplied.json": platform,
        "degraded-supplied.json": degraded, "uint256-shape.json": large}
    cases = []
    for filename, value in components.items():
        cases.append({"componentFile": filename, "suppliedContext": {
            "coreIdentity": {"mappingExists": True, "collectionId": value["id"],
                "collectionSerial": value["serial"], "burned": filename == "degraded-supplied.json"},
            "tokenId": value["catalog_number"], "typedCollectionName": value["name"],
            "derivedArtistDisplayLine": value["artist"]},
            "qualification": (
                "Synthetic supplied values only; not an RPC result, reachable-state proof or native renderer golden. "
                "Context numeric strings are decoded to exact integers before validate_context. "
                "The empty platform/degraded line is explicitly supplied for this example, not derived "
                "or prescribed by this module. The uint256 example demonstrates representation, not allocation."
            )})
    components["worked-contexts.json"] = {"schema": SCHEMA_NAME, "schemaHash": SCHEMA_HASH,
        "status": STATUS, "qualification": QUALIFICATION, "examples": cases,
        "sourceObservation": {
            "revision": SOURCE_REVISION,
            "renderer": "smart-contracts/domains/metadata/StreamMetadataTokenRenderer.sol",
            "attributionRenderer": "smart-contracts/domains/metadata/StreamArtistDisplayJSON.sol",
            "qualification": (
                "At this revision the token renderer emits legacy flat numeric identities and no "
                "properties.stream.collection object. The AA-DISPLAY helper supports platform and "
                "attribution_unavailable objects, but specifies no collection.artist line for them. "
                "These worked components are prospective consistency examples, not current renderer output."
            )}}
    return components


def outputs():
    result = {f"schemas/records/{SCHEMA_NAME}.json": SCHEMA_BYTES}
    result.update({"schemas/records/examples/collection-identity/" + name: canonical(value)
        for name, value in examples().items()})
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    for relative, raw in outputs().items():
        path = ROOT / relative
        if args.check:
            if not path.is_file() or path.read_bytes() != raw:
                raise SystemExit("collection identity generated bytes differ: " + relative)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
    print(f"Collection identity schema and {len(examples())} example documents exact: {SCHEMA_HASH}")


if __name__ == "__main__":
    main()
