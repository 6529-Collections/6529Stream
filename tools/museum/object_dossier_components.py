"""Pinned supplied dossier components: byte agreement, never semantic acceptance.

``admit`` returns ``(original_envelope, requirement_hashes)``. Every occurrence
and its order remains in the envelope; each mapping value is a sorted unique
tuple of content keccak256 hashes. Both outputs describe supplied_unverified
evidence only. A complete supplied list cannot establish dossier conformance.
Supplied files are inert bytes: this module never executes or fetches them.
The required public-disclosure declaration is supplied, not authenticated.
"""
from hashlib import sha256
from pathlib import Path
import re

from jsonschema import Draft202012Validator
from jsonschema.exceptions import ValidationError

from .bagit import MAX_BYTES, MAX_FILES, MAX_MANIFEST, _paths, _text
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, subject_id, uint
from .citations import parse_citation
from .object_dossier_inventory import REQUIREMENTS


MODE = "object_dossier_supplied_components"
EVIDENCE_STATUS = "supplied_unverified"
QUALIFICATION = ("External envelope commitment, original-token/source-state agreement and local file fixity only. "
    "The public-disclosure field is a caller declaration, not verified disclosure authority. "
    "Supplied component contents, profile names, requirement labels and assertions remain semantically unverified. "
    "These inputs never establish full object-dossier conformance or satisfy canonical evidence requirements by themselves.")
REQUIREMENT_CODES = tuple(sorted(row["code"] for row in REQUIREMENTS))
SOURCE_FIELDS = ("chainId", "core", "collectionId", "tokenId", "collectionSerial", "subjectId",
    "blockNumber", "blockHash", "canonicalCitation")
PROFILE_PATTERN = r"^[A-Za-z][A-Za-z0-9._:/-]*[._:/-][vV][1-9][0-9]*$"
SCHEMA_PATH = Path(__file__).resolve().parents[2] / "schemas/museum/object-dossier/components-schema.json"


def _object(properties):
    return {"type": "object", "properties": properties, "required": list(properties), "additionalProperties": False}


_UINT = {"type": "string", "pattern": r"^(0|[1-9][0-9]*)$", "maxLength": 78}
_HASH = {"type": "string", "pattern": r"^0x[0-9a-f]{64}$"}
_ADDRESS = {"type": "string", "pattern": r"^0x[0-9a-f]{40}$"}
_TEXT = {"type": "string", "minLength": 1, "maxLength": 256,
    "pattern": r"^[^\u0000-\u0020\u007f](?:[^\u0000-\u001f\u007f]*[^\u0000-\u0020\u007f])?$"}
SOURCE_STATE_SCHEMA = _object({"chainId": _UINT, "core": _ADDRESS, "collectionId": _UINT,
    "tokenId": _UINT, "collectionSerial": _UINT, "subjectId": _HASH, "blockNumber": _UINT, "blockHash": _HASH,
    "canonicalCitation": {"type": "string", "minLength": 1, "maxLength": 300}})
SCHEMA = {"$schema": "https://json-schema.org/draft/2020-12/schema",
    "$id": "urn:6529stream:schema:OBJECT_DOSSIER_SUPPLIED_COMPONENTS_V1",
    "title": "Object dossier supplied components V1", "description": QUALIFICATION,
    **_object({"mode": {"const": MODE}, "version": {"const": "1"}, "disclosure": {"const": "public"},
        "sourceState": SOURCE_STATE_SCHEMA,
        "components": {"type": "array", "maxItems": MAX_FILES, "items": _object({
            "id": _TEXT, "requirement": {"type": "string", "enum": list(REQUIREMENT_CODES)},
            "profile": {"type": "string", "minLength": 1, "maxLength": 256, "pattern": PROFILE_PATTERN},
            "path": {"type": "string", "minLength": 1, "maxLength": 1024},
            "bytes": _UINT, "sha256": _HASH, "keccak256": _HASH})}})}
SCHEMA_BYTES = dumps(SCHEMA)
SCHEMA_HASH = keccak256(SCHEMA_BYTES)
_VALIDATOR = Draft202012Validator(SCHEMA)


def _require(condition, message):
    if not condition:
        raise MuseumError(message)


def validate_source_state(source_state):
    """Pure equivalent of token_scope, plus the exact retained capture fields.

    Keep this boundary free of capture/statement-generation imports. Token
    identity uses the same canonical primitives as token_media_inputs.token_scope.
    The caller must separately authenticate the supplied reference state.
    """
    _require(type(source_state) is dict and set(source_state) == set(SOURCE_FIELDS)
        and all(type(value) is str for value in source_state.values()), "component source state fields/types differ")
    for key in ("chainId", "collectionId", "tokenId", "collectionSerial"):
        _require(uint(source_state[key]) > 0, "component source identity must be nonzero: " + key)
    _require(any(hex_bytes(source_state["core"], 20)), "component source Core must be nonzero")
    uint(source_state["blockNumber"])
    _require(any(hex_bytes(source_state["blockHash"], 32)), "component source block hash must be nonzero")
    expected_subject = subject_id("token", source_state["chainId"], source_state["core"],
        source_state["collectionId"], token_id=source_state["tokenId"])
    _require(source_state["subjectId"] == expected_subject, "component source original token subject differs")
    citation = parse_citation(source_state["canonicalCitation"], require_state=True)
    _require((citation["chainId"], citation["core"], citation["tokenId"]) == (
        source_state["chainId"], source_state["core"], source_state["tokenId"]),
        "component source original token citation differs")
    return source_state


def admit(raw: bytes, expected_hash: str, files: dict[str, bytes], source_state: dict):
    """Validate one optional supplied envelope without upgrading any evidence.

    ``expected_hash`` is an independently supplied keccak256 pin, not a field
    read from the envelope. ``source_state`` must come from the assembler's
    already verified capture. Rows retain their IDs, paths, roles and order,
    including multiple occurrences containing byte-identical content.
    """
    _require(type(raw) is bytes and 0 < len(raw) <= MAX_MANIFEST, "component envelope byte bound")
    _require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
        "component envelope external hash differs")
    value = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    try:
        _VALIDATOR.validate(value)
    except ValidationError as exc:
        raise MuseumError("component envelope closed schema differs at " + exc.json_path) from exc
    validate_source_state(source_state)
    validate_source_state(value["sourceState"])
    _require(value["sourceState"] == source_state, "component envelope source state differs from verified capture")
    rows = value["components"]
    identifiers = [row["id"] for row in rows]
    _require(identifiers == sorted(set(identifiers)), "component IDs must be sorted and unique")
    paths = [row["path"] for row in rows]
    _paths(paths)
    _require(type(files) is dict and len(files) <= MAX_FILES, "component files must be a bounded exact dictionary")
    _require(all(type(name) is str and type(content) is bytes for name, content in files.items()),
        "component files must map paths to original bytes")
    _paths(files)
    _require(set(paths) == set(files), "component file set differs from envelope")
    _require(len(raw) + sum(len(content) for content in files.values()) <= MAX_BYTES,
        "component aggregate byte bound")
    commitments = {}
    for row in rows:
        _text(row["id"], 256)
        _text(row["profile"], 256)
        _require(re.fullmatch(PROFILE_PATTERN, row["profile"]) is not None, "component profile needs a versioned name")
        content = files[row["path"]]
        _require(uint(row["bytes"]) == len(content), "component byte length differs")
        _require(any(hex_bytes(row["sha256"], 32)) and "0x" + sha256(content).hexdigest() == row["sha256"],
            "component SHA-256 differs")
        _require(any(hex_bytes(row["keccak256"], 32)) and keccak256(content) == row["keccak256"],
            "component keccak256 differs")
        commitments.setdefault(row["requirement"], set()).add(row["keccak256"])
    return value, {code: tuple(sorted(hashes)) for code, hashes in sorted(commitments.items())}


def generate(*, check=False):
    """Write/check only this prospective closed schema; never register it."""
    Draft202012Validator.check_schema(SCHEMA)
    if check:
        _require(SCHEMA_PATH.is_file() and SCHEMA_PATH.read_bytes() == SCHEMA_BYTES,
            "stale object dossier component schema")
    else:
        SCHEMA_PATH.parent.mkdir(parents=True, exist_ok=True)
        SCHEMA_PATH.write_bytes(SCHEMA_BYTES)


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("definitions",))
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    generate(check=args.check)


if __name__ == "__main__":
    main()
