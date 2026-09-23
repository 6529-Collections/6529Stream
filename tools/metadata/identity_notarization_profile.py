"""Closed prospective identity-notarization JSON; no personhood or authority claim."""
import argparse
import copy
import json
import re
from pathlib import Path

import jsonschema
import rfc8785
from Crypto.Hash import keccak


ROOT = Path(__file__).resolve().parents[2]
ZERO = "0x" + "0" * 64
RAW = "0x220c6deb539ee172cf673a6dd0935cb8f841290a9368519d83add4dbedf24d1f"
SCHEMA_NAME = "STREAM_IDENTITY_NOTARIZATION_V1"
PROFILE_NAME = "STREAM_IDENTITY_NOTARIZATION_JSON_PROFILE_V1"
MAX_PAYLOAD_BYTES = 8192


class NotarizationError(ValueError):
    pass


def digest(raw):
    return "0x" + keccak.new(digest_bits=256, data=raw).hexdigest()


def canonical(value):
    return rfc8785.dumps(value)


def _closed(properties):
    return {
        "type": "object",
        "properties": properties,
        "required": list(properties),
        "additionalProperties": False,
    }


def _nonzero_hash():
    return {
        "type": "string",
        "pattern": "^0x[0-9a-f]{64}$",
        "not": {"const": ZERO},
    }


def _reference_schema():
    return _closed(
        {
            "hash": _closed(
                {
                    "algorithm": {"type": "integer", "enum": [1, 2, 3, 4, 5, 6]},
                    "canonicalizationId": _nonzero_hash(),
                    "digest": {
                        "type": "string",
                        "pattern": "^0x(?:[0-9a-f]{2}){1,128}$",
                    },
                }
            ),
            "uri": {
                "type": "string",
                "minLength": 1,
                "maxLength": 2048,
                "x-stream-max-utf8-bytes": 2048,
                "x-stream-content-uri": True,
            },
        }
    )


def schema():
    reference = _reference_schema()
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "title": SCHEMA_NAME,
        **_closed(
            {
                "version": {"type": "integer", "const": 1},
                "profileHash": _nonzero_hash(),
                "artistId": _nonzero_hash(),
                "operativeIdentityRecordHash": _nonzero_hash(),
                "legalPersonRef": copy.deepcopy(reference),
                "instrumentRef": copy.deepcopy(reference),
                "officiatingAuthorityIdentityRef": copy.deepcopy(reference),
                "verifyingInstitutionIdentityRef": copy.deepcopy(reference),
            }
        ),
        "x-stream-constraints": [
            "Complete payload is canonical RFC8785 JSON and 1..8192 bytes.",
            "Every field is required and closed; artistId, operativeIdentityRecordHash and profileHash are exact nonzero bytes32 values.",
            "Hash algorithms 1 Keccak-256, 2 SHA-256, 3 BLAKE3 and 6 Arweave transaction ID require 32 digest bytes; algorithms 4 multihash and 5 IPFS CID retain 1..128 opaque bytes.",
            "Reference URIs are exact Stream content URIs with a 2048 decoded-UTF8-byte bound; no normalization, retrieval, availability, inner-codec or fixity claim is made.",
            "The four references are evidence supplied by the attester. Shape validation does not prove a legal person, identity, instrument, officiating authority, institution, reviewer qualification or authority.",
            "Actual schema/profile registration, original signed receipt, signature bundle, operative identity and record-type verification are external authenticated joins.",
        ],
    }


def profile():
    return {
        "name": PROFILE_NAME,
        "version": 1,
        "semanticSchema": SCHEMA_NAME,
        "canonicalization": "RFC8785_JCS",
        "maxPayloadBytes": MAX_PAYLOAD_BYTES,
        "recordTypes": ["INSTITUTIONAL_VERIFICATION", "ESTATE_VERIFICATION"],
        "verificationClass": "SIGNER_VERIFIED",
        "meaning": (
            "A typed claim linking one stable artistId and one exact operative identity document "
            "to four retained documentary references: legal-person identification, the instrument, "
            "the officiating authority identity and the verifying institution identity."
        ),
        "authority": (
            "The payload carries no authority or reviewer flag. Qualification requires an exact "
            "native SIGNER_VERIFIED institutional or estate receipt and its complete signature "
            "bundle; a generic writer receipt or URI is insufficient."
        ),
        "identity": (
            "artistId is stable across supported artist-address rotation. "
            "operativeIdentityRecordHash names the exact identity document attested at publication; "
            "a later identity revision does not rewrite this historical claim."
        ),
        "references": (
            "All four references use the existing Stream Reference JSON shape. Algorithms 1/2/3/6 "
            "have exact 32-byte digests; 4/5 retain opaque 1..128-byte digests. "
            "Canonicalization IDs are nonzero and content URIs are exact lexical evidence locators."
        ),
        "status": (
            "Prospective immutable interpretation only. Validation establishes canonical shape and "
            "explicit context equality, not actual registration, legal identity, notarization, "
            "institutional standing, reviewer independence or truth."
        ),
    }


SCHEMA_BYTES = canonical(schema())
SCHEMA_HASH = digest(SCHEMA_BYTES)
PROFILE_BYTES = canonical(profile())
PROFILE_HASH = digest(PROFILE_BYTES)


def _pairs(rows):
    value = {}
    for key, item in rows:
        if key in value:
            raise NotarizationError("duplicate JSON key")
        value[key] = item
    return value


def _load(raw):
    if type(raw) is not bytes or not 0 < len(raw) <= MAX_PAYLOAD_BYTES:
        raise NotarizationError("complete payload byte bound")

    def reject(_):
        raise NotarizationError("inexact or nonfinite JSON number")

    try:
        value = json.loads(
            raw.decode("utf8"),
            object_pairs_hook=_pairs,
            parse_float=reject,
            parse_constant=reject,
        )
        if canonical(value) != raw:
            raise NotarizationError("noncanonical JSON")
        return value
    except (ValueError, UnicodeError, TypeError, RecursionError) as exc:
        if isinstance(exc, NotarizationError):
            raise
        raise NotarizationError(str(exc)) from exc


def _annotations(value, definition):
    if isinstance(value, dict):
        for key, item in value.items():
            _annotations(item, definition.get("properties", {}).get(key, {}))
    elif isinstance(value, list):
        for item in value:
            _annotations(item, definition.get("items", {}))
    elif isinstance(value, str):
        if "pattern" in definition and re.fullmatch(definition["pattern"], value) is None:
            raise NotarizationError("full lexical grammar")
        if len(value.encode("utf8")) > definition.get("x-stream-max-utf8-bytes", MAX_PAYLOAD_BYTES):
            raise NotarizationError("decoded UTF8 bound")
        if definition.get("x-stream-content-uri"):
            if not value.startswith(("https://", "ipfs://", "ar://")):
                raise NotarizationError("content URI scheme")
            offset = value.index("://") + 3
            if (
                len(value) == offset
                or any(ord(character) <= 32 or ord(character) == 127 for character in value)
                or value.startswith("https://") and value[offset] in "/?#"
            ):
                raise NotarizationError("content URI lexical rule")


def _context_hash(value, label):
    if type(value) is not str or re.fullmatch("0x[0-9a-f]{64}", value) is None or value == ZERO:
        raise NotarizationError("invalid expected " + label)
    return value


def validate(raw, *, artist_id, operative_identity_record_hash):
    """Validate exact canonical bytes against an authenticated external identity context."""
    expected_artist = _context_hash(artist_id, "artistId")
    expected_identity = _context_hash(operative_identity_record_hash, "identity record")
    value = _load(raw)
    try:
        definition = schema()
        jsonschema.Draft202012Validator(definition).validate(value)
        _annotations(value, definition)
        if value["profileHash"] != PROFILE_HASH:
            raise NotarizationError("profile hash differs")
        if value["artistId"] != expected_artist:
            raise NotarizationError("artistId differs")
        if value["operativeIdentityRecordHash"] != expected_identity:
            raise NotarizationError("operative identity record differs")
        for field in (
            "legalPersonRef",
            "instrumentRef",
            "officiatingAuthorityIdentityRef",
            "verifyingInstitutionIdentityRef",
        ):
            hash_ref = value[field]["hash"]
            size = (len(hash_ref["digest"]) - 2) // 2
            if hash_ref["algorithm"] in (1, 2, 3, 6) and size != 32:
                raise NotarizationError("fixed digest shape")
    except (jsonschema.ValidationError, ValueError, TypeError, KeyError) as exc:
        if isinstance(exc, NotarizationError):
            raise
        raise NotarizationError(str(exc)) from exc
    return value


def example():
    h = lambda number: "0x" + format(number, "064x")

    def reference(label, algorithm=2):
        return {
            "hash": {
                "algorithm": algorithm,
                "canonicalizationId": RAW,
                "digest": h(label),
            },
            "uri": "https://evidence.example/" + str(label),
        }

    return {
        "version": 1,
        "profileHash": PROFILE_HASH,
        "artistId": h(1),
        "operativeIdentityRecordHash": h(2),
        "legalPersonRef": reference(3),
        "instrumentRef": reference(4),
        "officiatingAuthorityIdentityRef": reference(5),
        "verifyingInstitutionIdentityRef": reference(6),
    }


def outputs():
    value = example()
    raw = canonical(value)
    validate(
        raw,
        artist_id=value["artistId"],
        operative_identity_record_hash=value["operativeIdentityRecordHash"],
    )
    return {
        "schemas/records/" + SCHEMA_NAME + ".json": SCHEMA_BYTES,
        "schemas/records/" + PROFILE_NAME + ".json": PROFILE_BYTES,
        "schemas/records/examples/identity-notarization/notarization.json": raw,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    for path, raw in outputs().items():
        target = ROOT / path
        if args.check:
            if not target.exists() or target.read_bytes() != raw:
                raise NotarizationError("generated bytes differ: " + path)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(raw)
    print(
        "Identity notarization schema, profile and example match."
        if args.check
        else "Generated identity notarization schema, profile and example."
    )


if __name__ == "__main__":
    main()
