"""Generate complete closed RIGHTS JSON definitions and independent literal fixtures.

The generated documents are proposed registration inputs, not evidence of an
onchain registration. All keys are ASCII and all JSON numbers are small integers;
compact sorted JSON therefore has the same bytes as RFC8785 for these documents.
"""

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
H = {"type": "string", "pattern": "^0x[0-9a-f]{64}$"}
NONZERO_H = {**H, "not": {"const": "0x" + "0" * 64}}
STATUS = ["unspecified", "granted", "granted_with_conditions", "denied"]
USES = ["ai_training", "derivative", "exhibition", "print", "publication", "reproduction"]


def closed(properties, required=None, **extra):
    return {"type": "object", "properties": properties,
            "required": list(properties) if required is None else required,
            "additionalProperties": False, **extra}


def text(maximum, *, empty=False):
    return {"type": "string", "minLength": 0 if empty else 1, "maxLength": maximum,
            "x-stream-max-utf8-bytes": maximum}


def nullable(value):
    return {"oneOf": [{"type": "null"}, value]}


def schema():
    date = {"type": "string", "pattern": "^[0-9]{4}-[0-9]{2}-[0-9]{2}$",
            "x-stream-gregorian-date": "0001-01-01 through 9999-12-31; valid month/day and Gregorian leap years"}
    reference = closed({"algorithm": {"const": 1}, "canonicalizationId": {"const": "0x220c6deb539ee172cf673a6dd0935cb8f841290a9368519d83add4dbedf24d1f"}, "digest": NONZERO_H},
                       **{"x-stream-hash-profile": "algorithm1 is keccak256; canonicalizationId must equal keccak256(UTF8(RAW_BYTES)); digest contains32 bytes"})
    document = closed({"hash": reference, "uri": {**text(2048), "x-stream-content-uri": "existing StreamMetadataRenderer content URI policy; nonempty"}})
    conditions = {"oneOf": [{"type": "null"}, closed({"kind": {"const": "text"}, "text": text(1024)}),
                             closed({"document": document, "kind": {"const": "document"}})]}
    grant = closed({"conditions": conditions, "extension": text(512, empty=True), "status": {"enum": STATUS}},
                   allOf=[{"if": {"properties": {"status": {"const": "granted_with_conditions"}}, "required": ["status"]},
                           "then": {"properties": {"conditions": {"not": {"type": "null"}}}}}])
    identity = {"oneOf": [
        closed({"artistId": NONZERO_H, "kind": {"const": "artist"}}),
        closed({"kind": {"const": "estate"}, "name": text(512)}),
        closed({"kind": {"const": "institution"}, "name": text(512)}),
        closed({"address": {"type": "string", "pattern": "^0x[0-9a-f]{40}$", "not": {"const": "0x" + "0" * 40}}, "kind": {"const": "address"}}),
    ]}
    properties = {
        "AI_TRAINING_PERMISSION": {"enum": STATUS},
        "basis": {"enum": ["copyright", "license", "statute", "public_domain", "contract", "unspecified"]},
        "effectiveDates": closed({"end": nullable(date), "start": date}, **{"x-stream-date-order": "non-null end must be on or after start; null explicitly means open end"}),
        "grants": closed({use: grant for use in USES}),
        "instrument": nullable(document),
        "licensor": closed({"identity": identity, "instrumentDigest": nullable(NONZERO_H)}),
        "predecessor": nullable(NONZERO_H),
        "profileHash": NONZERO_H, "subjectId": NONZERO_H, "version": {"const": 1},
    }
    conditions = []
    for status in STATUS:
        conditions.append({"if": {"properties": {"AI_TRAINING_PERMISSION": {"const": status}}, "required": ["AI_TRAINING_PERMISSION"]},
                           "then": {"properties": {"grants": {"properties": {"ai_training": {"properties": {"status": {"const": status}}}}}}}})
    return {"$schema": "https://json-schema.org/draft/2020-12/schema", "title": "STREAM_RIGHTS_V1",
            **closed(properties, [key for key in properties if key != "AI_TRAINING_PERMISSION"], allOf=conditions),
            "x-stream-cross-field-constraints": [
                "licensor.instrumentDigest is null iff instrument is null; otherwise it equals instrument.hash.digest",
                "subjectId and profileHash must equal independently authenticated envelope/profile identities",
                "predecessor existence, original authorship, scope and current selection require the authenticated consumer",
            ]}


def profile():
    return {"name": "STREAM_RIGHTS_JSON_PROFILE_V1", "version": 1,
            "semanticSchema": "STREAM_RIGHTS_V1", "recordType": "RIGHTS_STATEMENT", "canonicalization": "RFC8785_JCS",
            "maxPayloadBytes": 8192, "dateGrammar": "Exact Gregorian YYYY-MM-DD, years0001..9999, inclusive ordered interval or explicit null end; no inferred timezone",
            "encodedIntegers": "Only literal version1 and algorithm1; no floating point or coerced identifiers",
            "hashProfile": "Embedded documents: algorithm1 keccak256,32-byte digest, RAW_BYTES canonicalization, nonempty content URI",
            "textPolicy": "Valid UTF8, no normalization, canonical JSON escapes; individual byte limits plus complete encoded payload limit",
            "optionalFields": "Only AI_TRAINING_PERMISSION may be omitted; when present it equals ai_training.status",
            "interpretation": "All six grants are explicit. None of basis, licensor or grant status establishes legal ownership or enforces a license.",
            "executionConstraints": "Every x-stream constraint in the complete semantic schema must be enforced by the typed consumer/serializer, not assumed from generic JSON Schema validation",
            "authority": "Original RIGHTS-family metadata receipt class7 or8; current selection and lineage require separate authorized checks",
            "registrationStatus": "Proposed immutable registration input; repository presence does not establish onchain registration"}


def examples():
    hex32 = lambda value: "0x" + format(value, "064x")
    s = {"basis": "unspecified", "effectiveDates": {"end": None, "start": "2026-09-12"},
         "grants": {use: {"conditions": None, "extension": "", "status": "unspecified"} for use in USES},
         "instrument": None, "licensor": {"identity": {"artistId": hex32(3), "kind": "artist"}, "instrumentDigest": None},
         "predecessor": None, "profileHash": hex32(2), "subjectId": hex32(1), "version": 1}
    first = json.loads(json.dumps(s))
    # Literal RAW_BYTES name hash, independently produced with Ethereum keccak256.
    raw = "0x220c6deb539ee172cf673a6dd0935cb8f841290a9368519d83add4dbedf24d1f"
    document = lambda uri, digest: {"hash": {"algorithm": 1, "canonicalizationId": raw, "digest": hex32(digest)}, "uri": uri}
    s["basis"] = "contract"
    s["grants"]["reproduction"] = {"conditions": {"document": document("ipfs://conditions", 4), "kind": "document"}, "extension": "", "status": "denied"}
    s["instrument"] = document("https://example.org/license", 5)
    s["licensor"] = {"identity": {"kind": "institution", "name": "Named rights-holding entity"}, "instrumentDigest": hex32(5)}
    s["AI_TRAINING_PERMISSION"] = "denied"
    s["grants"]["ai_training"]["status"] = "denied"
    s["effectiveDates"]["end"] = "2026-12-31"
    s["predecessor"] = hex32(6)
    return first, s


def outputs():
    a, b = examples()
    return {"schemas/records/STREAM_RIGHTS_V1.json": schema(),
            "schemas/records/STREAM_RIGHTS_JSON_PROFILE_V1.json": profile(),
            "test/fixtures/metadata/rights-unspecified-v1.json": a,
            "test/fixtures/metadata/rights-complete-v1.json": b}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    for name, value in outputs().items():
        raw = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
        path = ROOT / name
        if args.check:
            if not path.exists() or path.read_bytes() != raw:
                raise SystemExit("generated record bytes differ: " + name)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
    print("Four rights definition/fixture documents are exact.")


if __name__ == "__main__":
    main()
