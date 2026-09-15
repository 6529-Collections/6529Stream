"""Typed historical exhibition assertions, distinct from loans, rights and custody.

Admission/serialization helpers accept explicit synthetic test controls. Only
project_recorded_exhibitions accepts the concrete authenticated recorded adapter.
"""
from datetime import datetime
import re

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, subject_id, uint
from .linked_art import format_checker
from .preservation_graph import CONTEXT, VALIDATION_HASH, validator
from .recorded_semantic import RecordedSemanticSource, JCS_ID
from .review import _validate
from .schemas import HEX32, IRI, TEXT, UINT, arr, definitions, enum, obj

NAME = "STREAM_EXHIBITION_V1"
MODE = "recorded_independent_exhibition_projection"
FAMILY = schema_id("INDEPENDENT_EXHIBITION")
MAX_RECORDS = 64
ZERO = "0x" + "00" * 32
RULE = "urn:6529stream:museum:exhibition:v1:"
QUALIFICATION = "Historical independent-account exhibition assertion; occurrence, dates and named institution identity are not independently established."
CLAIMS = {"historicalPerformanceProven": False, "historicalTimeProven": False,
    "namedInstitutionIdentityProven": False, "displayAuthorized": False, "custodyTransferred": False,
    "rightsGranted": False, "institutionalConformance": False, "linkedArtApiConformance": False,
    "registeredExport": False, "referenceBytesRetrieved": False}


def nullable(value):
    return {"oneOf": [value, {"type": "null"}]}


def documents():
    reference = obj({"uri": IRI, "hash": definitions()["hashRef"]})
    name = obj({"value": dict(TEXT, minLength=1), "language": {"type": ["string", "null"], "maxLength": 128}})
    date = definitions()["date"]
    return {"$schema": "https://json-schema.org/draft/2020-12/schema",
        "title": NAME, "description": "Versioned closed exhibition documentation; no custody or display authorization.",
        **obj({"version": enum("1"), "exhibitionId": IRI,
            "status": enum("planned", "completed", "cancelled", "unknown"),
            "subject": obj({"kind": enum("collection", "token"), "collectionId": UINT, "tokenId": UINT}),
            "institution": obj({"entityId": IRI, "identity": obj({"kind": enum("address", "did", "record"), "value": TEXT}),
                "name": nullable(name), "reference": reference}),
            "venue": obj({"entityId": IRI, "name": nullable(name), "location": reference}),
            "title": obj({"name": nullable(name), "reference": reference}),
            "opening": date, "closing": date,
            "displayParameters": arr(obj({"parameter": IRI, "value": TEXT, "unit": {"type": ["string", "null"]}, "reference": reference}), maximum=32),
            "artistIntent": nullable(obj({"recordHash": HEX32, "reference": reference})),
            "catalogues": arr(reference, maximum=16), "wallLabels": arr(reference, maximum=16)})}


SCHEMA_BYTES = dumps(documents())
SCHEMA_HASH = keccak256(SCHEMA_BYTES)
PROFILE_BYTES = dumps({"id": "STREAM_MUSEUM_RECORDED_EXHIBITION_PROFILE_V1", "version": "1",
    "status": "prospective_unregistered_export_profile", "sourceSchemaId": schema_id(NAME), "sourceSchemaHash": SCHEMA_HASH,
    "sourceFamily": FAMILY, "validationPolicyHash": VALIDATION_HASH, "context": CONTEXT,
    "bounds": {"records": str(MAX_RECORDS), "payloadBytes": "8192", "planBytes": "524288"},
    "qualification": QUALIFICATION, "claims": CLAIMS,
    "rules": {
        "authority": "Exact selected public class-5 independent receipt, original registered schema bytes and registered JCS; account authorship is separate from named institution identity.",
        "identity": "Source-declared stable exhibition/institution/venue IRIs. Selected declaration reuse rejects; names, wallets and byte equality cannot merge entities.",
        "status": "Only completed source claims create an Activity. Planned/cancelled/unknown remain full nonperformed sidecars.",
        "institution": "Explicitly named exhibiting institution -> Group and participant (CRM P11), not organizer, legal owner or rights holder. Original address/DID/record identity stays a separately attributed source field.",
        "names": "Exact source text; language declarations stay in the complete sidecar without guessing authority language IRIs. TimeSpan display joins original opening and closing expressions with the fixed separator space/slash/space.",
        "venue": "Explicit named venue/location -> Place and took_place_at; no external match, geometry or coordinates inferred.",
        "dates": "Exact Gregorian UTC bounds only; source expression, precision, calendar and timezone retained. Unknown dates have no invented bounds; other calendars/timezones remain Stream-only.",
        "references": "Full URI and original HashRef retained for title, institution, location, display, intent, catalogue and labels. No remote fetching, hash verification of unprovided documents, or permission inferred.",
        "coverage": "Every source scalar, null and empty collection retained in sidecar with source pointer. Every emitted claim maps to exact original selector/fields and rule.",
        "selection": "Exact source-state hash and full record selectors, sorted by record hash. No latest-head authority, institution independence, loan or custody policy inferred."},
    "crosswalk": [
        {"source": "/exhibitionId,/status,/title", "target": "Activity/id,identified_by", "rule": RULE + "activity", "cardinality": "one per completed selected record", "authority": "original independent account", "uncertainty": "reported occurrence only", "reverse": "original record and pointers", "positive": "test_completed_exhibition_has_exact_entities_participant_venue_and_dates", "negative": "test_noncompleted_and_missing_names_never_invent_activity"},
        {"source": "/institution,/venue", "target": "Group,Place,participant,took_place_at", "rule": RULE + "entity", "cardinality": "one each per supported event", "authority": "original independent account", "uncertainty": "named identity unproven", "reverse": "original identity/name/reference retained", "positive": "test_completed_exhibition_has_exact_entities_participant_venue_and_dates", "negative": "test_identity_collision_and_account_equivalence_reject"},
        {"source": "/opening,/closing", "target": "TimeSpan bounds and source-date sidecar", "rule": RULE + "date", "cardinality": "zero to four explicit bounds", "authority": "original independent account", "uncertainty": "original precision retained", "reverse": "exact original expression/bounds", "positive": "test_unknown_and_other_calendar_dates_keep_exact_source_without_fabricated_bounds", "negative": "test_dates_reject_contradiction_invalid_calendar_dates_and_exact_ranges"}]})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def need(condition, message):
    if not condition: raise MuseumError("exhibition " + message)


def _iri(value):
    need(format_checker().conforms(value, "uri"), "invalid absolute source IRI")


def _reference(value):
    _iri(value["uri"])
    h = value["hash"]
    need(uint(h["algorithm"], 16) != 0 and h["canonicalizationId"] != ZERO
        and any(hex_bytes(h["digest"])), "reference commitment missing")


def _instant(value):
    need(isinstance(value, str) and re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z", value), "unsupported UTC date lexical")
    try: return datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ")
    except ValueError as exc: raise MuseumError("exhibition invalid Gregorian date") from exc


def _date(value):
    early, late = value["earliest"], value["latest"]
    if value["precision"] == "unknown":
        need(early is None and late is None, "unknown date cannot contain bounds")
    else:
        need(early is not None and late is not None, "known date requires both explicit bounds")
    if value["precision"] == "exact": need(early == late, "exact date cannot be a range")
    if value["calendar"] != "gregorian" or value["timezone"] != "UTC": return False
    if early is not None:
        need(_instant(early) <= _instant(late), "date bounds reversed")
    return True


def admit(source, selectors):
    """Source shape admission; production caller separately requires RecordedSemanticSource."""
    need(isinstance(selectors, list) and len(selectors) <= MAX_RECORDS, "selected record bound")
    rows, seen, ids = [], set(), set()
    for selector in selectors:
        record = source.record(selector)
        need(selector["pointer"] == "" and record.disclosure == "public"
            and record.selector.authorization_class == "INDEPENDENT_ATTESTOR"
            and record.selector.record_type == FAMILY and record.selector.schema_id == schema_id(NAME)
            and record.schema == SCHEMA_BYTES and source.canonicalizations[record.selector.record_hash] == JCS_ID,
            "exact public original family/schema/class/JCS required")
        need(record.selector.record_hash not in seen, "duplicate selected record")
        seen.add(record.selector.record_hash)
        need(0 < len(record.payload) <= 8192, "source payload byte bound")
        value = _validate(SCHEMA_BYTES, record.payload)
        subject = value["subject"]
        cid, tid = uint(subject["collectionId"]), uint(subject["tokenId"])
        need(cid > 0 and ((subject["kind"] == "collection" and tid == 0) or (subject["kind"] == "token" and tid > 0)), "subject scope shape")
        actual = subject_id(subject["kind"], source.anchor["chainId"], source.anchor["core"], subject["collectionId"], token_id=subject["tokenId"])
        need(actual == record.selector.subject_id, "canonical original subject differs")
        for identifier in (value["exhibitionId"], value["institution"]["entityId"], value["venue"]["entityId"]):
            _iri(identifier)
            need(identifier not in ids and not identifier.casefold().startswith(("urn:6529stream:account:", "eip155:")), "ambiguous entity identity or account equivalence")
            ids.add(identifier)
        identity = value["institution"]["identity"]
        if identity["kind"] == "address": need(len(hex_bytes(identity["value"], 20)) == 20 and any(hex_bytes(identity["value"])), "institution address missing")
        elif identity["kind"] == "record": need(identity["value"] != ZERO and len(hex_bytes(identity["value"], 32)) == 32, "institution record missing")
        else:
            _iri(identity["value"])
            need(identity["value"].startswith("did:"), "institution DID required")
        for ref in [value["institution"]["reference"], value["venue"]["location"], value["title"]["reference"], *value["catalogues"], *value["wallLabels"]]: _reference(ref)
        for param in value["displayParameters"]:
            _iri(param["parameter"]); _reference(param["reference"])
        if value["artistIntent"] is not None:
            need(value["artistIntent"]["recordHash"] != ZERO, "intent record missing")
            _reference(value["artistIntent"]["reference"])
        opening, closing = _date(value["opening"]), _date(value["closing"])
        if opening and closing and value["opening"]["earliest"] is not None and value["closing"]["latest"] is not None:
            need(_instant(value["opening"]["earliest"]) <= _instant(value["closing"]["latest"]), "closing precedes opening")
        rows.append({"record": record, "selector": selector, "value": value, "datesSupported": [opening, closing]})
    return sorted(rows, key=lambda r: r["record"].selector.record_hash)


def fields(value, path=""):
    if isinstance(value, dict) and value:
        for key, item in value.items(): yield from fields(item, path + "/" + key.replace("~", "~0").replace("/", "~1"))
    elif isinstance(value, list) and value:
        for key, item in enumerate(value): yield from fields(item, path + "/" + str(key))
    else: yield path, value


def render(rows, linked_art):
    files, resources, provenance, sidecar, coverage, dispositions = {}, [], [], [], [], []
    def emit(value, row, rule, source_paths):
        raw = dumps(value); result = linked_art.validate_and_expand(raw)
        key = keccak256(value["id"].encode())[2:]; path = "exhibitions/resources/" + key + ".json"
        files[path] = raw; files["exhibitions/expanded/" + key + ".json"] = result.expanded_bytes
        resources.append({"id": value["id"], "type": value["type"], "path": path})
        for pointer, scalar in fields(value): provenance.append({"entity": value["id"], "path": pointer, "value": scalar,
            "source": row["selector"], "sourcePaths": source_paths, "rule": RULE + rule, "qualification": QUALIFICATION})
    def named(identifier, kind, name):
        return {"@context": CONTEXT, "id": identifier, "type": kind, "_label": name["value"],
            "identified_by": [{"type": "Name", "content": name["value"]}],
            "referred_to_by": [{"type": "LinguisticObject", "content": QUALIFICATION}]}
    for row in rows:
        value, selector = row["value"], row["selector"]
        sidecar.append({"source": selector, "sourcePayloadHash": row["record"].payload_hash,
            "authority": loads(row["record"].authority_evidence), "exhibition": value,
            "qualification": QUALIFICATION, "referenceStatus": "described_only; original commitments retained, bytes not retrieved",
            "institutionIdentity": "independent assertion; address/DID/record is not verified Group equivalence"})
        coverage += [{"source": selector, "sourcePath": p, "value": v, "disposition": "retained_stream_only", "sidecarRecord": str(len(sidecar)-1)} for p,v in fields(value)]
        reasons = []
        for path, name in (("title", value["title"]["name"]), ("institution", value["institution"]["name"]), ("venue", value["venue"]["name"])):
            if name is None: reasons.append(path + "_name_not_recorded")
        disposition = "nonperformed_source" if value["status"] != "completed" else "unsupported" if reasons else "activity"
        dispositions.append({"source": selector, "exhibitionId": value["exhibitionId"], "sourceStatus": value["status"], "disposition": disposition, "reasons": reasons})
        if disposition != "activity": continue
        institution = named(value["institution"]["entityId"], "Group", value["institution"]["name"])
        venue = named(value["venue"]["entityId"], "Place", value["venue"]["name"])
        event = named(value["exhibitionId"], "Activity", value["title"]["name"])
        event["participant"] = [{"id": institution["id"], "type": "Group"}]
        event["took_place_at"] = [{"id": venue["id"], "type": "Place"}]
        timespan = {"type": "TimeSpan", "identified_by": [{"type": "Name", "content": value["opening"]["expression"] + " / " + value["closing"]["expression"]}]}
        for index, source_key, target_keys in ((0, "opening", ("begin_of_the_begin", "end_of_the_begin")), (1, "closing", ("begin_of_the_end", "end_of_the_end"))):
            date = value[source_key]
            if row["datesSupported"][index] and date["earliest"] is not None:
                timespan[target_keys[0]], timespan[target_keys[1]] = date["earliest"], date["latest"]
        event["timespan"] = timespan
        emit(institution, row, "entity", ["/institution"]); emit(venue, row, "entity", ["/venue"])
        emit(event, row, "activity", ["/exhibitionId", "/status", "/title", "/institution", "/venue", "/opening", "/closing"])
    status = "unsupported" if not rows else "incomplete" if any(r["disposition"] == "unsupported" for r in dispositions) else "complete_with_stream_extensions"
    files["exhibitions/index.json"] = dumps({"resources": sorted(resources, key=lambda r:r["id"])})
    files["exhibitions/provenance.json"] = dumps(provenance)
    files["exhibitions/sidecar.json"] = dumps(sidecar)
    files["exhibitions/coverage.json"] = dumps(coverage)
    files["exhibitions/report.json"] = dumps({"mode": MODE, "version": "1", "profileHash": PROFILE_HASH,
        "validationPolicyHash": VALIDATION_HASH, "status": status, "reasonCode": "no_selected_exhibition_records" if not rows else None,
        "dispositions": dispositions, "activities": str(sum(r["disposition"] == "activity" for r in dispositions)),
        "sourceValuesRetained": str(len(coverage)), "claims": CLAIMS, "qualification": QUALIFICATION})
    return files


def project_recorded_exhibitions(source, plan_bytes, *, plan_hash, profile_hash, linked_art):
    need(type(source) is RecordedSemanticSource and source.state.mode == "recorded_state", "concrete recorded source required")
    need(profile_hash == PROFILE_HASH and keccak256(plan_bytes) == plan_hash, "profile/plan hash mismatch")
    plan = loads(plan_bytes, maximum=524288, canonical=True)
    need(isinstance(plan, dict) and set(plan) == {"version", "sourceStateHash", "records"} and plan["version"] == "1"
        and plan["sourceStateHash"] == keccak256(source.state.identity), "exact source-state-bound plan required")
    return render(admit(source, plan["records"]), linked_art)


def main():
    import argparse
    from pathlib import Path
    parser = argparse.ArgumentParser(description="Generate/check the prospective closed exhibition definitions; no registration.")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(); root = Path(__file__).resolve().parents[2] / "schemas/museum/exhibition"
    for name, raw in ((NAME + ".json", SCHEMA_BYTES), ("profile.json", PROFILE_BYTES)):
        path = root / name
        if args.check:
            if not path.is_file() or path.read_bytes() != raw: raise MuseumError("exhibition definition differs: " + name)
        else:
            root.mkdir(parents=True, exist_ok=True); path.write_bytes(raw)
    print(PROFILE_HASH)


if __name__ == "__main__": main()
