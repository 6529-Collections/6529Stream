"""Generate and validate the complete bounded WORK_DESCRIPTION JSON interpretation.

These are prospective registration bytes and pure semantic checks. No function
establishes publication authority, current selection or actual catalog registration.
"""

import argparse
import datetime
import json
import re
from pathlib import Path

import jsonschema
import rfc8785
from Crypto.Hash import keccak

ROOT = Path(__file__).resolve().parents[2]
MAX_UINT = (1 << 256) - 1
ZERO = "0x" + "0" * 64
RAW = "0x220c6deb539ee172cf673a6dd0935cb8f841290a9368519d83add4dbedf24d1f"
H = {"type": "string", "pattern": "^0x[0-9a-f]{64}$"}
NH = {**H, "not": {"const": ZERO}}
UINT = {"type": "string", "pattern": "^[1-9][0-9]{0,77}$", "x-stream-maximum": str(MAX_UINT)}
LANG = r"[A-Za-z]{2,3}(?:-[A-Za-z]{4})?(?:-(?:[A-Za-z]{2}|[0-9]{3}))?"
PUID = r"(?:fmt|x-fmt)/[1-9][0-9]*"


class WorkError(ValueError):
    pass


def digest(raw):
    return "0x" + keccak.new(digest_bits=256, data=raw).hexdigest()


def canonical(value):
    return rfc8785.dumps(value)


def closed(properties, required=None, **extra):
    return {"type": "object", "properties": properties,
            "required": list(properties) if required is None else required,
            "additionalProperties": False, **extra}


def text(maximum):
    return {"type": "string", "minLength": 1, "maxLength": maximum,
            "x-stream-max-utf8-bytes": maximum}


def array(items, maximum):
    return {"type": "array", "items": items, "maxItems": maximum}


def mapping_schema():
    return {"oneOf": [closed({"kind": {"const": "pronom"},
                              "puid": {**text(32), "pattern": "^" + PUID + "$"}}),
                      closed({"kind": {"const": "specification"}, "specification": closed({
                          "hash": closed({"algorithm": {"const": 1}, "canonicalizationId": {"const": RAW}, "digest": NH}),
                          "uri": {**text(2048), "x-stream-content-uri": "StreamMetadataRenderer nonempty https/ipfs/ar policy"}})})]}


def catalog_schema():
    return {"$schema": "https://json-schema.org/draft/2020-12/schema", "title": "STREAM_WORK_FORMAT_CATALOG_V1",
            **closed({"entries": {**array(closed({"entryId": NH, "mapping": mapping_schema()}), 8), "minItems": 1},
                      "version": {"const": 1}}),
            "x-stream-constraints": ["Every entryId is unique. Original array order is preserved.",
                                     "Complete encoded document is at most8192 bytes; no unvalidated entries."]}


def schema():
    date = {"type": "string", "pattern": "^[0-9]{4}-[0-9]{2}-[0-9]{2}$", "x-stream-gregorian-date": True}
    creator = {"oneOf": [closed({"artistId": NH, "association": closed({"bindingGeneration": {**UINT, "x-stream-maximum": str((1 << 64) - 1)}, "bindingHash": NH}), "kind": {"const": "artist"}}),
                           closed({"kind": {"const": "named"}, "name": text(512)})]}
    creation = {"oneOf": [closed({"date": date, "kind": {"const": "date"}}),
                            closed({"end": date, "kind": {"const": "range"}, "start": date})]}
    fmt = {"oneOf": [closed({"kind": {"const": "nondigital"}}),
                     closed({"formatId": NH, "kind": {"const": "pronom"}, "puid": {**text(32), "pattern": "^" + PUID + "$"}}),
                     closed({"catalog": closed({"documentHash": NH, "documentId": NH, "name": {**text(128), "pattern": "^[A-Za-z0-9_.-]+$"}}),
                             "formatId": NH, "kind": {"const": "catalog"}, "mapping": mapping_schema()})]}
    rational = closed({"denominator": UINT, "numerator": UINT})
    measure = {"oneOf": [closed({"kind": {"const": "dimensionless_generative"}}),
        closed({"aspectRatio": rational, "durationSeconds": rational, "kind": {"const": "measured"},
                "pixels": closed({"height": UINT, "unit": {"const": "pixels"}, "width": UINT})}, ["kind"],
               anyOf=[{"required": [x]} for x in ["aspectRatio", "durationSeconds", "pixels"]])]}
    edition = {"oneOf": [closed({"kind": {"const": "unique"}}),
                          closed({"kind": {"const": "serial"}, "number": UINT, "total": UINT}),
                          closed({"kind": {"const": "open_series"}, "statement": text(512)})]}
    variant = {"oneOf": [closed({"field": {"enum": ["title", "medium", "creditLine", "inscription", "creatorName"]}, "language": {**text(16), "pattern": "^" + LANG + "$"}, "value": text(1024)}),
                           closed({"alternateTitleIndex": {"type": "string", "pattern": "^[0-7]$"}, "field": {"const": "alternateTitle"}, "language": {**text(16), "pattern": "^" + LANG + "$"}, "value": text(1024)})]}
    authority = {"oneOf": [closed({"authority": {"const": a}, "identifier": {"type": "string", "pattern": "^" + pattern + "$"}, "role": {"enum": roles}})
                           for a, pattern, roles in [("ulan", r"[1-9][0-9]{8}", ["creator"]), ("viaf", r"[1-9][0-9]{0,21}", ["creator"]),
                                                     ("wikidata", r"Q[1-9][0-9]{0,19}", ["creator"]), ("getty_aat", r"[1-9][0-9]{8}", ["medium", "technique"])]]}
    common = {"predecessor": {"oneOf": [{"type": "null"}, NH]}, "profileHash": NH, "subjectId": NH, "version": {"const": 1}}
    full = {"alternateTitles": array(text(256), 8), "authorityReferences": array(authority, 16), "creation": creation,
            "creator": creator, "creditLine": text(2048), "edition": edition, "form": {"const": "full"}, "format": fmt,
            "inscription": text(1024), "languageVariants": array(variant, 8), "measurements": measure, "medium": text(1024),
            **common, "title": text(512)}
    absent = {"absence": closed({"date": date, "reason": text(1024)}), "form": {"const": "description_absent"}, **common}
    return {"$schema": "https://json-schema.org/draft/2020-12/schema", "title": "STREAM_WORK_DESCRIPTION_V1",
            "oneOf": [closed(full, [x for x in full if x != "inscription"]), closed(absent)],
            "x-stream-constraints": [
                "Every x-stream constraint is executed by this profile validator and typed serializer; generic JSON Schema alone is insufficient.",
                "All dates are actual Gregorian0001..9999; ranges are inclusive and ordered.",
                "All decimal strings are canonical, positive and bounded by the stated unsigned width; rationals remain unreduced.",
                "PRONOM formatId is keccak256 UTF8(PRONOM:+puid). Catalog requires complete exact document witness, unique entry IDs and exact selected mapping.",
                "Language variants require their target field to exist; alternateTitleIndex is zero-based. No inferred language.",
                "Serial number<=total. Combined AV measurements are permitted; inactive union data is rejected.",
                "Payload is canonical RFC8785 bytes,1..8192. Authority, subject/profile identity, actual creator association, lineage, catalog registration and truth require separate authenticated evidence."]}


def profile():
    return {"name": "STREAM_WORK_DESCRIPTION_JSON_PROFILE_V1", "version": 1, "semanticSchema": "STREAM_WORK_DESCRIPTION_V1",
            "recordType": "WORK_DESCRIPTION", "canonicalization": "RFC8785_JCS", "maxPayloadBytes": 8192,
            "forms": "full and description_absent are complete exclusive variants. Absence is authored, never a fallback.",
            "identity": "subjectId/profileHash are nonzero32-byte references; predecessor is explicit null or nonzero32-byte reference. Actual envelope/profile/lineage checks are external.",
            "creator": "artistId with bindingGeneration64 and bindingHash, or explicit named creator. No recorder/owner inference; actual association checked externally.",
            "dates": "Exact proleptic Gregorian YYYY-MM-DD years0001..9999, exact or closed ordered range. No BCE, uncertain, partial, open or inferred dates.",
            "quantities": "Canonical positive decimal strings through uint256; generation through uint64. Exact positive numerator/denominator, no reduction or rounding. Pixel unit is pixels; durationSeconds unit is seconds.",
            "optionalFields": "Only inscription may be omitted. All three arrays are explicit, bounded and ordered; duplicate entries remain observable. No empty present inscription or entries.",
            "languageTags": "Supported lexical BCP47 subset:2..3 ASCII letters, optional four-letter script, optional two-letter or three-digit region. Case preserved. No extensions/private use or language-registry lookup.",
            "authorityIdentifiers": "Lexical subset: ULAN/AAT nine digits with nonzero first; VIAF1..22 digits with nonzero first; Wikidata Q plus1..20 digits with nonzero first. Creator uses ULAN/VIAF/Wikidata; medium/technique uses AAT. No true-match claim.",
            "format": "Direct fmt/N or x-fmt/N with canonical positive decimal N and totalPUID<=32bytes; formatId=keccak256(PRONOM:+PUID). Catalog uses entire STREAM_WORK_FORMAT_CATALOG_V1 bytes, ordered unique entries and exact selected mapping; caller hash alone is insufficient.",
            "catalogProfile": "STREAM_WORK_FORMAT_CATALOG_JSON_PROFILE_V1",
            "text": "Valid UTF8; no normalization, coercion or trimming; fixed ASCII keys sorted and canonical escapes. Individual decoded UTF8 byte limits plus complete encoded limit.",
            "registrationStatus": "Proposed immutable registration inputs; pure interpretation does not establish recorded authority, registration, current selection, format identification or resource availability."}


def catalog_profile():
    return {"name": "STREAM_WORK_FORMAT_CATALOG_JSON_PROFILE_V1", "version": 1, "semanticSchema": "STREAM_WORK_FORMAT_CATALOG_V1",
            "canonicalization": "RFC8785_JCS", "maxPayloadBytes": 8192, "maxEntries": 8,
            "scope": "Versioned supported catalog subset, not a replacement for arbitrary Stream catalog schemas.",
            "registrationIdentity": "Name is1..128 ASCII letters/digits/underscore/dot/hyphen; documentId=keccak256 UTF8(name). Registration name and selected entry are external to document bytes.",
            "entries": "Full ordered list of unique nonzero entryIds. Every mapping validated, including unselected entries; selected ID must occur exactly once.",
            "mapping": "Exact PUID or full-specification content URI plus algorithm1 keccak25632-byte RAW_BYTES digest. URI/hash is a claim, not fetched bytes.",
            "authority": "Actual registry kind/name/bytes/hash/canonicalization and accepted interpretation must be joined externally. Pure serialization does not prove registration or availability."}


def _pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise WorkError("duplicate property")
        result[key] = value
    return result


def _load(raw):
    if not isinstance(raw, bytes) or not 1 <= len(raw) <= 8192:
        raise WorkError("encoded payload limit")
    try:
        value = json.loads(raw.decode("utf-8"), object_pairs_hook=_pairs,
                           parse_float=lambda _: (_ for _ in ()).throw(WorkError("float unsupported")),
                           parse_constant=lambda _: (_ for _ in ()).throw(WorkError("nonfinite unsupported")))
        if canonical(value) != raw:
            raise WorkError("noncanonical JSON")
        return value
    except (UnicodeError, ValueError, TypeError, RecursionError) as exc:
        raise WorkError(str(exc)) from exc


def _pattern_checks(value, s):
    """Check actual applicable schema annotations and regex full consumption.

    The schema contains only these fixed local constructs; no arbitrary schema input.
    """
    if "oneOf" in s:
        valid = [branch for branch in s["oneOf"] if jsonschema.Draft202012Validator(branch).is_valid(value)]
        if len(valid) != 1:
            raise WorkError("variant")
        _pattern_checks(value, valid[0])
    if isinstance(value, dict):
        for key, item in value.items():
            _pattern_checks(item, s.get("properties", {}).get(key, {}))
    elif isinstance(value, list):
        for item in value:
            _pattern_checks(item, s.get("items", {}))
    elif isinstance(value, str):
        if "pattern" in s and not re.fullmatch(s["pattern"], value):
            raise WorkError("lexical grammar")
        if len(value.encode("utf-8")) > s.get("x-stream-max-utf8-bytes", 8192):
            raise WorkError("UTF8 byte bound")
        if "x-stream-maximum" in s and int(value) > int(s["x-stream-maximum"]):
            raise WorkError("unsigned overflow")
        if s.get("x-stream-gregorian-date"):
            try:
                datetime.date.fromisoformat(value)
            except ValueError as exc:
                raise WorkError("invalid Gregorian date") from exc
        if s.get("x-stream-content-uri"):
            _content_uri(value)


def _content_uri(value):
    # Exact nonempty content URI predicate used by the pinned Renderer: the ASCII
    # grammar is deliberately bounded, not a general URI parser or fetch operation.
    if not value.startswith(("https://", "ipfs://", "ar://")):
        raise WorkError("content URI scheme")
    prefix = value.index("://") + 3
    if (len(value) == prefix or any(ord(c) <= 32 or ord(c) == 127 for c in value)
            or value.startswith("https://") and value[prefix] in "/?#"):
        raise WorkError("content URI lexical policy")


def _validate(raw, definition):
    value = _load(raw)
    try:
        jsonschema.Draft202012Validator(definition).validate(value)
        _pattern_checks(value, definition)
    except (jsonschema.ValidationError, ValueError, TypeError) as exc:
        raise WorkError(str(exc)) from exc
    return value


def validate_catalog(raw):
    value = _validate(raw, catalog_schema())
    ids = [row["entryId"] for row in value["entries"]]
    if len(ids) != len(set(ids)):
        raise WorkError("duplicate catalog ID")
    return value


def validate_payload(raw, *, catalog_bytes=None):
    value = _validate(raw, schema())
    if value["form"] == "description_absent":
        if catalog_bytes is not None:
            raise WorkError("inactive catalog witness")
        return value
    creation = value["creation"]
    if creation["kind"] == "range" and creation["end"] < creation["start"]:
        raise WorkError("date order")
    edition = value["edition"]
    if edition["kind"] == "serial" and int(edition["number"]) > int(edition["total"]):
        raise WorkError("edition order")
    for v in value["languageVariants"]:
        if (v["field"] == "inscription" and "inscription" not in value
                or v["field"] == "creatorName" and value["creator"]["kind"] != "named"
                or v["field"] == "alternateTitle" and int(v["alternateTitleIndex"]) >= len(value["alternateTitles"])):
            raise WorkError("language target absent")
    fmt = value["format"]
    if fmt["kind"] == "catalog":
        if catalog_bytes is None:
            raise WorkError("complete catalog required")
        catalog = validate_catalog(catalog_bytes)
        if fmt["catalog"]["documentHash"] != digest(catalog_bytes) or fmt["catalog"]["documentId"] != digest(fmt["catalog"]["name"].encode("utf-8")):
            raise WorkError("catalog document identity")
        selected = [row for row in catalog["entries"] if row["entryId"] == fmt["formatId"]]
        if len(selected) != 1 or canonical(selected[0]["mapping"]) != canonical(fmt["mapping"]):
            raise WorkError("catalog selected mapping")
    elif catalog_bytes is not None:
        raise WorkError("inactive catalog witness")
    elif fmt["kind"] == "pronom" and fmt["formatId"] != digest(("PRONOM:" + fmt["puid"]).encode("ascii")):
        raise WorkError("PRONOM derivation")
    return value


def examples():
    h = lambda n: "0x" + format(n, "064x")
    common = {"predecessor": None, "profileHash": h(2), "subjectId": h(1), "version": 1}
    simple = {"alternateTitles": [], "authorityReferences": [], "creation": {"date": "2024-02-29", "kind": "date"},
              "creator": {"kind": "named", "name": "Declared creator"}, "creditLine": "Authored credit", "edition": {"kind": "unique"},
              "form": "full", "format": {"kind": "nondigital"}, "languageVariants": [], "measurements": {"kind": "dimensionless_generative"},
              "medium": "Generative instructions", "title": "Exact work title", **common}
    absent = {"absence": {"date": "2026-09-12", "reason": "An explicit authored absence."}, "form": "description_absent", **common}
    catalog = {"entries": [{"entryId": h(11), "mapping": {"kind": "pronom", "puid": "fmt/199"}},
                            {"entryId": h(12), "mapping": {"kind": "specification", "specification": {"hash": {"algorithm": 1, "canonicalizationId": RAW, "digest": h(13)}, "uri": "ipfs://format-specification"}}}], "version": 1}
    complete = json.loads(json.dumps(simple))
    complete.update({"predecessor": h(6), "title": "Quote \" slash / backslash \\ newline\ncontrol\u0001 astral \U0001f3a8 e\u0301",
                     "creator": {"artistId": h(3), "association": {"bindingGeneration": str((1 << 64) - 1), "bindingHash": h(4)}, "kind": "artist"},
                     "creation": {"end": "2026-09-12", "kind": "range", "start": "0001-01-01"},
                     "medium": "Digital audiovisual work", "creditLine": "Exact authored credit\r\n", "inscription": "Signature description, not a signature.",
                     "edition": {"kind": "serial", "number": str(MAX_UINT - 1), "total": str(MAX_UINT)},
                     "measurements": {"aspectRatio": {"denominator": "4", "numerator": "2"}, "durationSeconds": {"denominator": str(MAX_UINT), "numerator": str(MAX_UINT - 1)}, "kind": "measured", "pixels": {"height": "2160", "unit": "pixels", "width": "3840"}},
                     "alternateTitles": ["Titre", "Titre"],
                     "languageVariants": [{"field": "title", "language": "fr", "value": "Titre"}, {"field": "medium", "language": "sr-Latn-RS", "value": "Medij"}, {"field": "creditLine", "language": "und", "value": "Credit"}, {"field": "inscription", "language": "es-419", "value": "Inscripción"}, {"alternateTitleIndex": "1", "field": "alternateTitle", "language": "FR", "value": "Autre"}],
                     "authorityReferences": [{"authority": "ulan", "identifier": "500115588", "role": "creator"}, {"authority": "viaf", "identifier": "1234567890123456789012", "role": "creator"}, {"authority": "wikidata", "identifier": "Q12345678901234567890", "role": "creator"}, {"authority": "getty_aat", "identifier": "300264849", "role": "medium"}, {"authority": "getty_aat", "identifier": "300054698", "role": "technique"}],
                     "format": {"catalog": {"documentHash": digest(canonical(catalog)), "documentId": digest(b"WORK_FORMAT_FIXTURE_V1"), "name": "WORK_FORMAT_FIXTURE_V1"}, "formatId": h(12), "kind": "catalog", "mapping": catalog["entries"][1]["mapping"]}})
    return simple, absent, complete, catalog


def outputs():
    simple, absent, complete, catalog = examples()
    return {"schemas/records/STREAM_WORK_DESCRIPTION_V1.json": schema(),
            "schemas/records/STREAM_WORK_DESCRIPTION_JSON_PROFILE_V1.json": profile(),
            "schemas/records/STREAM_WORK_FORMAT_CATALOG_V1.json": catalog_schema(),
            "schemas/records/STREAM_WORK_FORMAT_CATALOG_JSON_PROFILE_V1.json": catalog_profile(),
            "test/fixtures/metadata/work-simple-v1.json": simple, "test/fixtures/metadata/work-absent-v1.json": absent,
            "test/fixtures/metadata/work-complete-v1.json": complete, "test/fixtures/metadata/work-catalog-v1.json": catalog}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--check", action="store_true")
    args = p.parse_args()
    for name, value in outputs().items():
        raw = canonical(value)
        path = ROOT / name
        if args.check:
            if not path.exists() or path.read_bytes() != raw:
                raise SystemExit("generated work bytes differ: " + name)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
    print("Eight work definition/fixture documents are exact.")


if __name__ == "__main__":
    main()
