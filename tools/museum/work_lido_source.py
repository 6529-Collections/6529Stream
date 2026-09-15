"""Exact typed WORK source and applicable-field inventory for the LIDO crosswalk.

This module checks meaning and bytes, not record publication or current selection.
It does not convert the earlier synthetic assertion profile into WORK records.
"""

from dataclasses import dataclass

import jsonschema

from tools.metadata import work_profile as work
from .canonical import MuseumError, dumps

WORK_SCHEMA_HASH = "0xc534a4212c652d620942266ff32d8699bcc40492aa9a323e0f5b711bbc5bba88"
WORK_PROFILE_HASH = "0x1c5e8281a5c12e06b334020bc158dc101dd33baaa449feeb8f504e20bd910353"
CATALOG_SCHEMA_HASH = "0xa2c03300254919dad0436cffd743bc869665f06434123b92ae48c5ff98a284ed"
CATALOG_PROFILE_HASH = "0x03799bc44aab386d3032a5859e6e7b7f6558bdb279f0e9906d3af535274a6514"
MAX_INVENTORY_BYTES = 4 * 1024 * 1024


@dataclass(frozen=True)
class WorkLidoSource:
    payload: bytes
    catalog: bytes | None
    payload_hash: str
    subject_id: str
    form: str
    inventory: bytes


def _escape(value):
    return value.replace("~", "~0").replace("/", "~1")


def _inventory(value, definition, source_name, schema_hash):
    """Only the pinned finite schemas are accepted, after all semantic checks.

    Record every actual object/array/leaf and each applicable absent optional.
    Branch evidence keeps original schema locations; nothing is counted from an
    inactive tagged variant. No external references or arbitrary schema execution.
    """
    fields, decisions = [], []

    def effective(spec, location, item, pointer):
        rows = [(spec, location)]
        for keyword in ("oneOf", "anyOf", "allOf"):
            if keyword not in spec:
                continue
            valid = [i for i, s in enumerate(spec[keyword]) if jsonschema.Draft202012Validator(s).is_valid(item)]
            if not valid or keyword == "oneOf" and len(valid) != 1 or keyword == "allOf" and len(valid) != len(spec[keyword]):
                raise MuseumError("WORK inventory branch disagreement")
            locations = [location + "/" + keyword + "/" + str(i) for i in valid]
            decisions.append({"source": source_name, "schemaHash": schema_hash, "schemaLocation": location,
                              "pointer": pointer, "keyword": keyword, "applicable": locations})
            for i, child_location in zip(valid, locations):
                rows += effective(spec[keyword][i], child_location, item, pointer)
        return rows

    def walk(specs, item, pointer, depth=0):
        if depth > 32 or len(fields) > 4096:
            raise MuseumError("WORK inventory bound")
        active = [row for s, loc in specs for row in effective(s, loc, item, pointer)]
        locations = sorted({loc for _, loc in active})
        kind = "object" if isinstance(item, dict) else "array" if isinstance(item, list) else "null" if item is None else type(item).__name__
        exact = dumps(sorted(item)) if isinstance(item, dict) else dumps(str(len(item))) if isinstance(item, list) else work.canonical(item)
        fields.append({"source": source_name, "pointer": pointer, "presence": "present", "kind": kind,
                       "exactHex": "0x" + exact.hex(), "schemaLocations": locations})
        if isinstance(item, dict):
            if not any(s.get("additionalProperties") is False for s, _ in active):
                raise MuseumError("WORK inventory object is not closed")
            properties = {}
            for s, loc in active:
                for key, child in s.get("properties", {}).items():
                    properties.setdefault(key, []).append((child, loc + "/properties/" + _escape(key)))
            if set(item) - set(properties):
                raise MuseumError("WORK source property has no declaration")
            for key, children in sorted(properties.items()):
                child_pointer = pointer + "/" + _escape(key)
                if key in item:
                    walk(children, item[key], child_pointer, depth + 1)
                else:
                    fields.append({"source": source_name, "pointer": child_pointer, "presence": "absent", "kind": "absent",
                                   "exactHex": "0x", "schemaLocations": sorted(loc for _, loc in children)})
        elif isinstance(item, list):
            children = [(s["items"], loc + "/items") for s, loc in active if "items" in s]
            if not children:
                raise MuseumError("WORK source array has no item declaration")
            for i, child in enumerate(item):
                walk(children, child, pointer + "/" + str(i), depth + 1)

    walk([(definition, "#")], value, "")
    return fields, decisions


def load_work_source(payload: bytes, *, expected_subject_id: str, catalog: bytes | None = None):
    """Load complete exact WORK bytes under the accepted pure meaning profile.

    expected_subject_id comes from the separate export context. Equality is not
    proof of actual Core membership, current selection or publication authority.
    """
    schemas = [(work.schema(), WORK_SCHEMA_HASH), (work.profile(), WORK_PROFILE_HASH),
               (work.catalog_schema(), CATALOG_SCHEMA_HASH), (work.catalog_profile(), CATALOG_PROFILE_HASH)]
    if any(work.digest(work.canonical(value)) != expected for value, expected in schemas):
        raise MuseumError("WORK definition/profile implementation changed")
    try:
        value = work.validate_payload(payload, catalog_bytes=catalog)
    except work.WorkError as exc:
        raise MuseumError("WORK source interpretation rejected") from exc
    if value["profileHash"] != WORK_PROFILE_HASH or value["subjectId"] != expected_subject_id:
        raise MuseumError("WORK source profile/subject mismatch")
    fields, branches = _inventory(value, schemas[0][0], "work", WORK_SCHEMA_HASH)
    if catalog is not None:
        more, branch = _inventory(work.validate_catalog(catalog), schemas[2][0], "catalog", CATALOG_SCHEMA_HASH)
        fields += more
        branches += branch
    inventory = dumps({
        "sourceSchemaHash": WORK_SCHEMA_HASH, "sourceProfileHash": WORK_PROFILE_HASH,
        "fields": fields, "branches": branches,
        "claims": {"actualRecordAuthority": False, "currentSelection": False, "registeredCatalog": False}})
    if len(inventory) > MAX_INVENTORY_BYTES:
        raise MuseumError("WORK inventory encoded bound")
    return WorkLidoSource(payload, catalog, work.digest(payload), value["subjectId"], value["form"], inventory)
