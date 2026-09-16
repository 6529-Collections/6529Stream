"""Offline media requirements from an already verified semantic export.

This adapter does not authenticate an export, retrieve media, identify a file
format, or infer a preservation role.  Its caller must first verify the V3
semantic-export package.  The adapter then keeps the exact admitted assertion
rows that justify each local byte requirement.
"""

from collections.abc import Mapping
from hashlib import sha256
import re

from .canonical import MuseumError, dumps, loads, uint
from .iiif import FIELDS as IIIF_FIELDS
from .iiif_model import MIMES, XSD
from .iiif_uri import content_uri_facts
from .premis import FIELDS as PREMIS_FIELDS


ASSERTIONS_PATH = "semantic/assertions.json"
ENTITY_INDEX_PATH = "semantic/entityIndex.json"
MAX_ASSERTIONS_BYTES = 64 * 1024 * 1024
MAX_INDEX_BYTES = 2 * 1024 * 1024
MAX_SELECTED_CLAIMS = 32768
MAX_MEDIA = 512

_PRESENTATION = IIIF_FIELDS["presentation-of"]
_TYPE = IIIF_FIELDS["presentation-type"]
_MIME = IIIF_FIELDS["mime"]
_URI = IIIF_FIELDS["content-uri"]
_SIZE = PREMIS_FIELDS["size"]
_DIGEST = PREMIS_FIELDS["digest"]
_MEDIA_RELATIONS = {_PRESENTATION, _TYPE, _MIME, _URI, _SIZE, _DIGEST}


def _need(condition, message):
    if not condition:
        raise MuseumError(message)


def _export_json(export_files, path, maximum):
    _need(isinstance(export_files, Mapping), "semantic export files mapping required")
    try:
        raw = export_files[path]
    except KeyError as exc:
        raise MuseumError("semantic export media input missing: " + path) from exc
    _need(type(raw) is bytes, "semantic export file bytes required: " + path)
    return loads(raw, maximum=maximum, canonical=True)


def _assertion(row, label):
    _need(isinstance(row, dict) and isinstance(row.get("assertion"), dict),
          label + " admitted assertion row required")
    _need(isinstance(row.get("selector"), dict), label + " admitted selector required")
    value = row["assertion"]
    _need(isinstance(value.get("subject"), str) and value["subject"],
          label + " assertion subject required")
    _need(isinstance(value.get("relation"), str) and value["relation"],
          label + " assertion relation required")
    _need(isinstance(value.get("object"), dict), label + " assertion object required")
    return value


def _literal(row, relation, datatype):
    value = _assertion(row, "selected")
    _need(value["relation"] == relation, "media assertion relation mismatch")
    obj = value["object"]
    _need(set(obj) == {"literal"} and isinstance(obj["literal"], dict),
          "media assertion requires an exact literal")
    literal = obj["literal"]
    _need(set(literal) == {"lexicalValue", "datatype", "language", "unit", "precision"},
          "media assertion literal shape differs")
    _need(literal["datatype"] == datatype and literal["language"] is None
          and literal["unit"] is None and literal["precision"] is None
          and isinstance(literal["lexicalValue"], str),
          "media assertion exact unqualified datatype required")
    return literal["lexicalValue"]


def _one(claims, entity, relation, label):
    rows = claims.get((entity, relation), [])
    _need(len(rows) == 1, entity + " requires exactly one selected " + label + " assertion")
    return rows[0]


def requirements(export_files: Mapping[str, bytes]):
    """Return stable media bindings from a caller-verified V3 export.

    A presentation body exists only when its exact ``presentation-of`` claim
    was selected.  Role-like annotations, filenames, MIME values, or entity
    declarations never select media by themselves.
    """
    sidecar = _export_json(export_files, ASSERTIONS_PATH, MAX_ASSERTIONS_BYTES)
    index = _export_json(export_files, ENTITY_INDEX_PATH, MAX_INDEX_BYTES)
    _need(isinstance(sidecar, dict) and isinstance(sidecar.get("base"), dict),
          "semantic assertion sidecar shape differs")
    base = sidecar["base"]
    selected = base.get("selectedClaims")
    withheld = base.get("withheldClaims")
    _need(isinstance(selected, list) and isinstance(withheld, list),
          "semantic assertion selections missing")
    _need(len(selected) <= MAX_SELECTED_CLAIMS and len(withheld) <= MAX_SELECTED_CLAIMS,
          "semantic assertion selection bound")
    _need(isinstance(index, list) and len(index) <= MAX_MEDIA * 4,
          "semantic entity index bound")

    entity_rows = {}
    for row in index:
        _need(isinstance(row, dict) and isinstance(row.get("id"), str),
              "semantic entity index row differs")
        entity_rows.setdefault(row["id"], []).append(row)

    claims, selected_by_subject = {}, {}
    presentation_entities = set()
    for row in selected:
        value = _assertion(row, "selected")
        key = (value["subject"], value["relation"])
        claims.setdefault(key, []).append(row)
        selected_by_subject.setdefault(value["subject"], []).append(row)
        if value["relation"] == _PRESENTATION:
            presentation_entities.add(value["subject"])
    _need(len(presentation_entities) <= MAX_MEDIA, "selected presentation media bound")

    for row in withheld:
        value = _assertion(row, "withheld")
        if value["subject"] in presentation_entities and value["relation"] in _MEDIA_RELATIONS:
            raise MuseumError("selected presentation media has a withheld conflicting assertion")

    result = []
    for entity in sorted(presentation_entities):
        declarations = entity_rows.get(entity, [])
        _need(len(declarations) == 1 and declarations[0].get("kind") == "linked_art"
              and declarations[0].get("type") == "DigitalObject",
              entity + " is not one exact admitted DigitalObject")

        presentation = _one(claims, entity, _PRESENTATION, "presentation-of")
        presentation_object = _assertion(presentation, "selected")["object"]
        _need(set(presentation_object) == {"entity"}
              and isinstance(presentation_object["entity"], str)
              and presentation_object["entity"],
              "presentation-of requires one exact entity object")

        type_row = _one(claims, entity, _TYPE, "presentation type")
        mime_row = _one(claims, entity, _MIME, "MIME")
        uri_row = _one(claims, entity, _URI, "content URI")
        size_row = _one(claims, entity, _SIZE, "byte size")
        digest_row = _one(claims, entity, _DIGEST, "SHA-256")
        presentation_type = _literal(type_row, _TYPE, XSD + "string")
        media_type = _literal(mime_row, _MIME, XSD + "string")
        uri = _literal(uri_row, _URI, XSD + "anyURI")
        byte_length = _literal(size_row, _SIZE, XSD + "nonNegativeInteger")
        digest = _literal(digest_row, _DIGEST, XSD + "string")
        uint(byte_length, 256)
        _need(re.fullmatch(r"[0-9a-f]{64}", digest) is not None,
              "selected media SHA-256 must be exact lowercase hex")
        _need(presentation_type in MIMES and media_type in MIMES[presentation_type],
              "selected media has unsupported IIIF type/MIME pair")
        content_uri_facts(uri, digest)

        # Retain every selected assertion about the presentation body. Only
        # the six closed relations above define the byte requirement; other
        # rows remain provenance and do not acquire preservation force.
        admitted = list(selected_by_subject[entity])
        admitted.sort(key=dumps)
        result.append({"entity": entity, "presentationOf": presentation_object["entity"],
            "presentationType": presentation_type, "sha256": digest,
            "byteLength": byte_length, "mediaType": media_type, "uri": uri,
            "renderCritical": True, "path": "media/" + digest + ".bin",
            "admittedClaims": admitted})
    result.sort(key=dumps)
    return result


def _check_requirements(rows):
    _need(isinstance(rows, list) and len(rows) <= MAX_MEDIA, "media requirements list required")
    paths, entities = set(), set()
    for row in rows:
        _need(isinstance(row, dict) and set(row) == {"entity", "presentationOf", "presentationType",
              "sha256", "byteLength", "mediaType", "uri", "renderCritical", "path",
              "admittedClaims"}, "media requirement shape differs")
        digest = row["sha256"]
        _need(isinstance(row["entity"], str) and row["entity"] and row["entity"] not in entities,
              "media requirement entity differs")
        _need(isinstance(digest, str) and re.fullmatch(r"[0-9a-f]{64}", digest) is not None,
              "media requirement SHA-256 differs")
        _need(row["path"] == "media/" + digest + ".bin" and row["renderCritical"] is True,
              "media requirement payload binding differs")
        uint(row["byteLength"], 256)
        _need(isinstance(row["presentationType"], str) and isinstance(row["mediaType"], str)
              and row["presentationType"] in MIMES
              and row["mediaType"] in MIMES[row["presentationType"]],
              "media requirement IIIF type/MIME differs")
        content_uri_facts(row["uri"], digest)
        _need(isinstance(row["presentationOf"], str) and row["presentationOf"]
              and isinstance(row["admittedClaims"], list) and len(row["admittedClaims"]) >= 6,
              "media requirement provenance differs")
        _need(row["admittedClaims"] == sorted(row["admittedClaims"], key=dumps),
              "media requirement provenance order differs")
        claims = {}
        for admitted in row["admittedClaims"]:
            value = _assertion(admitted, "admitted")
            _need(value["subject"] == row["entity"], "media requirement provenance subject differs")
            claims.setdefault(value["relation"], []).append(admitted)
        for relation, label in ((_PRESENTATION, "presentation-of"), (_TYPE, "presentation type"),
                                (_MIME, "MIME"), (_URI, "content URI"),
                                (_SIZE, "byte size"), (_DIGEST, "SHA-256")):
            _need(len(claims.get(relation, [])) == 1,
                  "media requirement provenance needs one " + label)
        presentation = _assertion(claims[_PRESENTATION][0], "admitted")["object"]
        _need(set(presentation) == {"entity"} and presentation["entity"] == row["presentationOf"],
              "media requirement presentation provenance differs")
        _need(_literal(claims[_TYPE][0], _TYPE, XSD + "string") == row["presentationType"]
              and _literal(claims[_MIME][0], _MIME, XSD + "string") == row["mediaType"]
              and _literal(claims[_URI][0], _URI, XSD + "anyURI") == row["uri"]
              and _literal(claims[_SIZE][0], _SIZE, XSD + "nonNegativeInteger") == row["byteLength"]
              and _literal(claims[_DIGEST][0], _DIGEST, XSD + "string") == digest,
              "media requirement value differs from admitted provenance")
        entities.add(row["entity"]); paths.add(row["path"])
    _need(rows == sorted(rows, key=dumps), "media requirements must retain canonical order")
    return paths


def validate_media(requirement_rows, supplied: Mapping[str, bytes]):
    """Validate exact local supplies and return deduplicated embedded paths."""
    paths = _check_requirements(requirement_rows)
    _need(isinstance(supplied, Mapping), "media supplies mapping required")
    expected_names = {path.rsplit("/", 1)[1] for path in paths}
    _need(all(type(name) is str for name in supplied), "media supply filename must be a string")
    actual_names = set(supplied)
    missing, extra = sorted(expected_names - actual_names), sorted(actual_names - expected_names)
    if missing:
        raise MuseumError("missing media supply: " + ", ".join(missing))
    if extra:
        raise MuseumError("unexpected media supply: " + ", ".join(extra))

    by_digest = {}
    for row in requirement_rows:
        digest = row["sha256"]
        raw = supplied[digest + ".bin"]
        _need(type(raw) is bytes, "media supply must be exact bytes: " + digest + ".bin")
        _need(len(raw) == uint(row["byteLength"], 256),
              "media supply byte length mismatch: " + digest + ".bin")
        _need(sha256(raw).hexdigest() == digest,
              "media supply SHA-256 mismatch: " + digest + ".bin")
        by_digest[digest] = raw
    return {"media/" + digest + ".bin": by_digest[digest] for digest in sorted(by_digest)}
