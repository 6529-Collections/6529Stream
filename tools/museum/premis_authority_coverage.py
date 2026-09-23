"""Complete, explicit authority-field accounting for the unchanged PREMIS profile."""
from collections import Counter
from hashlib import sha256
from pathlib import Path
import re

from tools.metadata.genesis_premis_profile import profile as original_profile
from . import premis_authority_snapshot as v1
from .bagit import _paths, read_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint

ROOT = Path(__file__).resolve().parents[2]
NAME = "STREAM_MUSEUM_PREMIS_AUTHORITY_COVERAGE_V2"
MODE = "premis_authority_field_coverage"
BASE = "http://id.loc.gov/vocabulary/preservation/"
MAX_SNAPSHOTS, MAX_INPUT, MAX_TOTAL, MAX_PACKAGE = 64, 131072, 8 * 1048576, 32 * 1048576
ORIGINAL_PROFILE_BYTES, ORIGINAL_PROFILE_HASH = v1.ORIGINAL_PROFILE_BYTES, v1.ORIGINAL_PROFILE_HASH
need, closed = v1.need, v1.closed
QUALIFICATION = ("Complete accounting of the original profile's enumerated authority fields, not complete PREMIS semantics. "
    "Retained HTTP observations and supplied RDF are not publisher authentication or proof of current authority. "
    "Exact label support is a prospective field binding; close matches are explicit unreviewed proposals, never equivalence. "
    "Profile-local and unresolved fields remain visible. No identity merge, network access, schema admission or institutional acceptance.")


def fields():
    """The closed original field inventory; identifiers and authority-wide roles are separate."""
    p = original_profile()
    groups = (("eventTypes", p["eventTypes"], BASE + "eventType"),
        ("outcomes", p["outcomes"], BASE + "eventOutcome"), ("agent/classes", p["agent"]["classes"], BASE + "agentType"),
        ("rights/bases", p["rights"]["bases"], BASE + "rightsBasis"),
        ("fixityAlgorithms", p["fixityAlgorithms"], BASE + "cryptographicHashFunctions"))
    return [{"sourcePointer": "/" + group + "/" + str(i), "original": row,
        "targetLabel": row["target"], "profileLocal": row.get("profileLocal", False),
        "declaredAuthority": row.get("authority", p["rights"]["basisAuthority"] if group == "rights/bases" else None),
        "expectedScheme": scheme, "family": group} for group, rows, scheme in groups for i, row in enumerate(rows)]


FIELDS = fields()
FIELD_MAP = {row["sourcePointer"]: row for row in FIELDS}
PROFILE_BYTES = dumps({"name": NAME, "version": "2", "mode": MODE,
    "status": "prospective_unregistered_source_adapter", "originalProfileHash": ORIGINAL_PROFILE_HASH,
    "parentSnapshotProfileHash": v1.PROFILE_HASH,
    "coverage": [{"sourcePointer": f["sourcePointer"], "original": f["original"],
        "expectedScheme": f["expectedScheme"]} for f in FIELDS],
    "scope": "Every enumerated event type, outcome, agent class, rights basis and fixity algorithm. Agent role has no original enumeration; identifiers, object-role relations, format registry and whole crosswalk semantics remain separate.",
    "selection": "Exactly one disposition per original field in original order; explicit candidates only, no label lookup or latest-source selection. Multiple candidates are ambiguous even when labels agree.",
    "relations": {"exact_label": "Exact original target label and explicit source scheme; no semantic equivalence.",
        "close_match": "Explicit rationale and retained candidate label; proposed and unreviewed, no automatic adoption."},
    "localFields": "Only fields marked profileLocal by the original profile can use profile_local disposition; retain original close-match values literally.",
    "source": "Original bounded N-Triples syntax and finite opaque <dlc> exception inherited from V1. Field-specific scheme paths must match explicit term membership. The outcome path is a prospective candidate restriction, not a claim that a current LoC eventOutcome vocabulary exists; absent usable source bytes keep fields unresolved.",
    "compatibleAdditionalType": "Only eventTypes may also carry the observed http://www.loc.gov/premis/rdf/v3/Action type. An Authority or Concept type is still required; no performed action is inferred.",
    "limits": {"fields": str(len(FIELDS)), "candidatesPerField": "4", "snapshots": str(MAX_SNAPSHOTS),
        "rawBytes": str(v1.MAX_RAW), "inputBytes": str(MAX_INPUT), "aggregateInputBytes": str(MAX_TOTAL),
        "packageFiles": "256", "packageBytes": str(MAX_PACKAGE)}, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _scheme(value):
    need(type(value) is str and re.fullmatch(re.escape(BASE) + r"[A-Za-z][A-Za-z0-9]{0,63}", value),
        "exact LoC preservation scheme IRI required")


def _term(value, scheme):
    _scheme(scheme)
    need(type(value) is str and re.fullmatch(re.escape(scheme) + r"/[A-Za-z0-9][A-Za-z0-9._-]{0,63}", value),
        "exact original term IRI required")


def _retrieval(raw, d, payload):
    if d["provenance"] != "retained_http_observation":
        need(raw is None, "retrieval observation supplied for other provenance")
        return None
    need(type(raw) is bytes and 0 < len(raw) <= MAX_INPUT, "retained retrieval observation required")
    value = loads(raw, maximum=MAX_INPUT)
    closed(value, "uri finalUri status contentType bytes sha256 retrievedAt", "retrieval observation")
    need(type(value["status"]) is int and value["status"] == 200 and type(value["bytes"]) is int
        and value["bytes"] == len(payload) and value["uri"] == value["finalUri"] == d["sourceUri"]
        and value["retrievedAt"] == d["retrievedAt"] and value["sha256"] == sha256(payload).hexdigest()
        and type(value["contentType"]) is str and value["contentType"].split(";", 1)[0].strip() == d["mediaType"],
        "retrieval observation differs from retained source")
    return {"observationHash": keccak256(raw), "observation": value, "publisherAuthenticated": False}


def parse_snapshot(descriptor_raw, raw, *, descriptor_hash, provenance, retrieval=None):
    d = v1._pinned(descriptor_raw, descriptor_hash, MAX_INPUT)
    closed(d, "version termIri schemeIri sourceUri retrievedAt contentHash byteLength mediaType attribution reuseTerms provenance", "descriptor")
    need(d["version"] == "1", "descriptor version")
    _term(d["termIri"], d["schemeIri"])
    need(d["sourceUri"] in (d["termIri"] + ".nt", "https:" + d["termIri"][5:] + ".nt"), "original term endpoint differs")
    v1._instant(d["retrievedAt"])
    need(provenance in v1.PROVENANCE and d["provenance"] == provenance, "external provenance differs")
    need(d["mediaType"] in ("application/n-triples", "text/plain"), "source media type")
    for name in ("attribution", "reuseTerms"): v1._text(d[name])
    closed(d["contentHash"], "algorithm digest canonicalizationId", "raw hash")
    h = d["contentHash"]
    need(h["algorithm"] in ("1", "2") and h["canonicalizationId"] == v1.RAW_BYTES, "raw hash algorithm/canonicalization")
    hex_bytes(h["digest"], 32)
    need(type(raw) is bytes and 0 < len(raw) <= v1.MAX_RAW and uint(d["byteLength"]) == len(raw), "raw size differs")
    need((keccak256(raw) if h["algorithm"] == "1" else "0x" + sha256(raw).hexdigest()) == h["digest"], "raw digest differs")
    observation = _retrieval(retrieval, d, raw)
    facts, opaque = v1._facts(raw)
    own = [f for f in facts if f["subject"] == {"type": "IRI", "value": d["termIri"]}]
    need(own, "original term absent")
    versions = v1._selected(facts, {d["termIri"]}, {v1.OWL + "versionInfo", v1.DCT + "hasVersion"})
    effective = v1._selected(facts, {d["termIri"]}, {v1.DCT + "valid"})
    links = v1._selected(facts, {d["termIri"]}, {v1.MADS + "adminMetadata", v1.SKOS + "changeNote"})
    linked = {f["object"]["value"] for f in links if f["object"]["type"] in ("IRI", "blank node")}
    return {"descriptor": d, "descriptorHash": descriptor_hash, "rawHash": keccak256(raw),
        "facts": facts, "opaqueReferences": opaque, "validNTriples": not opaque,
        "version": {"status": "supplied" if versions else "not_supplied", "facts": versions},
        "effectiveDates": {"status": "supplied" if effective else "not_supplied", "facts": effective},
        "recordHistory": {"links": links, "facts": [f for f in facts if f["subject"]["value"] in linked],
            "qualification": "Original lexical administrative dates; no effective-date or UTC inference."},
        "retrieval": observation, "publisherAuthenticated": False, "qualification": QUALIFICATION}


def _candidate(snapshot, candidate, field, as_of, age):
    closed(candidate, "snapshot termIri relation label requiredVersion requiredEffectiveDate", "candidate")
    d = snapshot["descriptor"]
    _term(candidate["termIri"], d["schemeIri"])
    need(candidate["relation"] in ("exact_label", "close_match"), "candidate relation")
    v1._text(candidate["label"], 256)
    if candidate["relation"] == "exact_label":
        need(candidate["label"] == field["targetLabel"], "exact candidate target label differs")
    for name in ("requiredVersion", "requiredEffectiveDate"):
        if candidate[name] is not None: v1._text(candidate[name], 256)
    own = [f for f in snapshot["facts"] if f["subject"] == {"type": "IRI", "value": candidate["termIri"]}]
    reasons, ambiguous = [], False
    if candidate["termIri"] != d["termIri"]: reasons.append("selected_term_differs")
    labels = [v1._literal(f) for f in own if f["predicate"]["value"] in (v1.MADS + "authoritativeLabel", v1.SKOS + "prefLabel")]
    values = {f["value"] for f in labels if (f.get("language"), f.get("datatype")) in
        ((None, v1.XSD + "string"), ("en", v1.RDF + "langString"))}
    if len(values) > 1: reasons.append("ambiguous_original_labels"); ambiguous = True
    if candidate["label"] not in values: reasons.append("selected_label_not_supported")
    codes = [v1._literal(f) for f in own if f["predicate"]["value"] in (v1.MADS + "code", v1.SKOS + "notation")]
    need(all(f.get("datatype") == v1.XSD + "string" and "language" not in f for f in codes), "plain original code required")
    code_values = {f["value"] for f in codes}
    if len(code_values) > 1: reasons.append("ambiguous_original_codes"); ambiguous = True
    if code_values != {candidate["termIri"].rsplit("/", 1)[-1]}: reasons.append("original_code_differs")
    memberships = [f["object"] for f in own if f["predicate"]["value"] in (v1.MADS + "isMemberOfMADSScheme", v1.SKOS + "inScheme")]
    need(all(o["type"] == "IRI" for o in memberships), "scheme membership is not an IRI")
    schemes = {o["value"] for o in memberships}
    if d["schemeIri"] not in schemes: reasons.append("exact_scheme_membership_missing")
    if schemes - {d["schemeIri"], BASE[:-1]}: reasons.append("ambiguous_scheme_membership"); ambiguous = True
    if field["expectedScheme"] is not None and field["expectedScheme"] != d["schemeIri"]:
        reasons.append("original_profile_scheme_differs")
    types = [f["object"] for f in own if f["predicate"]["value"] == v1.RDF + "type"]
    need(all(o["type"] == "IRI" for o in types), "type is not an IRI")
    type_values = {o["value"] for o in types}
    if not type_values & {v1.MADS + "Authority", v1.SKOS + "Concept"}: reasons.append("authority_concept_type_missing")
    allowed_types = {v1.MADS + "Authority", v1.SKOS + "Concept", v1.MADS + "DeprecatedAuthority"}
    if field["family"] == "eventTypes": allowed_types.add("http://www.loc.gov/premis/rdf/v3/Action")
    if type_values - allowed_types:
        reasons.append("ambiguous_original_types"); ambiguous = True
    if v1.MADS + "DeprecatedAuthority" in type_values: reasons.append("original_term_deprecated")
    for f in own:
        if f["predicate"]["value"] in (v1.DCT + "isReplacedBy", v1.MADS + "hasLaterEstablishedForm"):
            reasons.append("original_term_replaced")
        if f["predicate"]["value"] == v1.OWL + "deprecated" and v1._literal(f)["value"] in ("true", "1"):
            reasons.append("original_term_deprecated")
    existing = field["original"].get("valueUri")
    if existing is not None and candidate["relation"] == "exact_label" and existing != candidate["termIri"]:
        reasons.append("original_profile_value_uri_differs")
    for key, area in (("requiredVersion", "version"), ("requiredEffectiveDate", "effectiveDates")):
        if candidate[key] is not None:
            source_values = {v1._literal(f)["value"] for f in snapshot[area]["facts"]}
            if len(source_values) > 1: reasons.append("ambiguous_" + area); ambiguous = True
            if source_values != {candidate[key]}: reasons.append(key + "_not_supported")
    elapsed = (as_of - v1._instant(d["retrievedAt"])).total_seconds()
    stale = elapsed < 0 or elapsed > age
    if stale: reasons.append("retrieved_after_as_of" if elapsed < 0 else "snapshot_outside_freshness_window")
    status = "ambiguous" if ambiguous else "stale" if stale else "unresolved" if reasons else "supported"
    return {**candidate, "status": status, "reasons": sorted(set(reasons)),
        "sourceDescriptorHash": snapshot["descriptorHash"], "sourceRawHash": snapshot["rawHash"],
        "sourceProvenance": d["provenance"], "supportingFacts": own, "version": snapshot["version"],
        "effectiveDates": snapshot["effectiveDates"], "recordHistory": snapshot["recordHistory"],
        "opaqueReferences": snapshot["opaqueReferences"], "semanticEquivalenceProven": False}


def bind(original_profile_raw, request_raw, snapshots, *, original_profile_hash, request_hash, profile_hash):
    need(original_profile_hash == ORIGINAL_PROFILE_HASH and original_profile_raw == ORIGINAL_PROFILE_BYTES
        and profile_hash == PROFILE_HASH, "exact original/adapter profile differs")
    request = v1._pinned(request_raw, request_hash, MAX_INPUT)
    closed(request, "version mode profileHash originalProfileHash asOf maxSnapshotAgeSeconds fields", "request")
    need(request["version"] == "2" and request["mode"] == MODE and request["profileHash"] == PROFILE_HASH
        and request["originalProfileHash"] == ORIGINAL_PROFILE_HASH, "request profile binding")
    as_of, age = v1._instant(request["asOf"]), uint(request["maxSnapshotAgeSeconds"], 32)
    need(type(request["fields"]) is list and len(request["fields"]) == len(FIELDS), "complete original field inventory required")
    need(type(snapshots) is dict and len(snapshots) <= MAX_SNAPSHOTS, "snapshot count")
    total = len(original_profile_raw) + len(request_raw)
    for key, value in snapshots.items():
        need(type(key) is str and re.fullmatch(r"[a-z0-9][a-z0-9_-]{0,63}", key), "snapshot identifier")
        need(type(value) is tuple and len(value) == 5 and all(type(value[i]) is bytes for i in (0, 1))
            and (value[4] is None or type(value[4]) is bytes), "snapshot input tuple")
        total += len(value[0]) + len(value[1]) + (0 if value[4] is None else len(value[4]))
    need(total <= MAX_TOTAL, "aggregate source bound")
    output = {"source-profile.json": original_profile_raw, "profile.json": PROFILE_BYTES, "request.json": request_raw}
    parsed = {}
    for key, (descriptor, raw, pin, provenance, retrieval) in snapshots.items():
        parsed[key] = parse_snapshot(descriptor, raw, descriptor_hash=pin, provenance=provenance, retrieval=retrieval)
        output["sources/" + key + ".descriptor.json"] = descriptor
        output["sources/" + key + ".nt"] = raw
        if retrieval is not None: output["sources/" + key + ".retrieval.json"] = retrieval
        output["snapshots/" + key + ".json"] = dumps(parsed[key])
    rows, used = [], set()
    for entry, field in zip(request["fields"], FIELDS):
        closed(entry, "sourcePointer disposition rationale candidates", "field selection")
        need(entry["sourcePointer"] == field["sourcePointer"], "original field ordering/coverage differs")
        need(entry["disposition"] in ("authority", "profile_local", "unresolved"), "field disposition")
        v1._text(entry["rationale"], 2048)
        need(type(entry["candidates"]) is list and len(entry["candidates"]) <= 4, "candidate count")
        if entry["disposition"] == "profile_local": need(field["profileLocal"], "original field is not profile-local")
        if entry["disposition"] == "authority": need(not field["profileLocal"] and entry["candidates"], "authority candidate required for nonlocal field")
        if entry["disposition"] == "unresolved": need(not entry["candidates"], "unresolved disposition cannot hide candidate checks")
        candidates, seen = [], set()
        for candidate in entry["candidates"]:
            closed(candidate, "snapshot termIri relation label requiredVersion requiredEffectiveDate", "candidate")
            key = candidate["snapshot"]
            need(type(key) is str and key in parsed and key not in seen, "candidate snapshot absent/duplicate")
            if field["profileLocal"]: need(candidate["relation"] == "close_match", "profile-local field cannot become exact authority identity")
            seen.add(key); used.add(key)
            candidates.append(_candidate(parsed[key], candidate, field, as_of, age))
        status, uri = entry["disposition"], None
        if candidates:
            if len(candidates) > 1: status = "ambiguous"
            elif candidates[0]["status"] != "supported": status = candidates[0]["status"]
            elif candidates[0]["relation"] == "close_match": status = "proposed_close_match"
            else: status, uri = "bound", candidates[0]["termIri"]
        rows.append({**field, "disposition": entry["disposition"], "rationale": entry["rationale"],
            "status": status, "candidateValueUri": uri, "candidates": candidates,
            "originalCloseMatch": field["original"].get("skosCloseMatch"),
            "reviewed": False, "semanticEquivalenceProven": False})
    need(used == set(parsed), "unselected snapshot supplied")
    output["report.json"] = dumps({"version": "2", "mode": MODE, "profileHash": PROFILE_HASH,
        "originalProfileHash": ORIGINAL_PROFILE_HASH, "requestHash": request_hash,
        "asOf": request["asOf"], "maxSnapshotAgeSeconds": request["maxSnapshotAgeSeconds"],
        "fieldCount": str(len(rows)), "completeEnumeratedFieldAccounting": True,
        "counts": {key: str(value) for key, value in sorted(Counter(row["status"] for row in rows).items())},
        "fields": rows, "allFieldsBound": all(row["status"] == "bound" for row in rows),
        "originalProfileChanged": False, "publisherAuthenticated": False, "currentAuthorityProven": False,
        "fullCrosswalkConformance": False, "qualification": QUALIFICATION})
    return output


def _bound(files):
    need(type(files) is dict and len(files) <= 256 and all(type(p) is str and type(b) is bytes for p, b in files.items())
        and sum(map(len, files.values())) <= MAX_PACKAGE, "package bounds")
    _paths(files)


def build(original_profile_raw, request_raw, snapshots, **pins):
    need(set(pins) == {"original_profile_hash", "request_hash", "profile_hash"}, "package pins")
    files = bind(original_profile_raw, request_raw, snapshots, **pins)
    _bound(files)
    files["manifest.json"] = dumps({"version": "2", "mode": MODE, "pins": pins,
        "snapshots": {k: {"descriptorHash": value[2], "provenance": value[3],
            "retrievalHash": None if value[4] is None else keccak256(value[4])} for k, value in sorted(snapshots.items())},
        "files": v1._inventory(files), "qualification": QUALIFICATION})
    need(len(files["manifest.json"]) <= MAX_INPUT, "manifest bound")
    _bound(files)
    return files


def verify(files, manifest_hash):
    _bound(files)
    value = v1._pinned(files.get("manifest.json", b""), manifest_hash, MAX_INPUT)
    closed(value, "version mode pins snapshots files qualification", "manifest")
    need(value["version"] == "2" and value["mode"] == MODE and value["qualification"] == QUALIFICATION, "manifest constants")
    need(value["files"] == v1._inventory({p: b for p, b in files.items() if p != "manifest.json"}), "package inventory differs")
    closed(value["pins"], "original_profile_hash request_hash profile_hash", "manifest pins")
    need(type(value["snapshots"]) is dict and len(value["snapshots"]) <= MAX_SNAPSHOTS, "manifest snapshots")
    snapshots = {}
    try:
        for key, entry in value["snapshots"].items():
            need(type(key) is str and re.fullmatch(r"[a-z0-9][a-z0-9_-]{0,63}", key), "manifest snapshot identifier")
            closed(entry, "descriptorHash provenance retrievalHash", "manifest snapshot")
            retrieval = None if entry["retrievalHash"] is None else files["sources/" + key + ".retrieval.json"]
            if retrieval is not None: need(keccak256(retrieval) == entry["retrievalHash"], "retrieval observation hash differs")
            snapshots[key] = (files["sources/" + key + ".descriptor.json"], files["sources/" + key + ".nt"],
                entry["descriptorHash"], entry["provenance"], retrieval)
        rebuilt = build(files["source-profile.json"], files["request.json"], snapshots, **value["pins"])
    except KeyError as exc:
        raise MuseumError("PREMIS authority original package input missing") from exc
    need(rebuilt == files, "package reconstruction differs")
    return loads(rebuilt["report.json"], maximum=MAX_PACKAGE, canonical=True)


def definitions(check=False):
    path = ROOT / "schemas/museum/premis-authority-coverage/profile.json"
    if check: need(path.is_file() and path.read_bytes() == PROFILE_BYTES, "generated profile differs")
    else: path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(PROFILE_BYTES)
    return PROFILE_HASH


def example_package():
    """Replay the retained term example; discovery documents never substitute terms."""
    root = ROOT / "schemas/museum/premis-authority-coverage/example/input"
    index_raw = (root / "index.json").read_bytes()
    index = loads(index_raw, maximum=MAX_INPUT, canonical=True)
    closed(index, "version snapshots discovery", "example input index")
    need(index["version"] == "2" and type(index["snapshots"]) is dict
        and len(index["snapshots"]) <= MAX_SNAPSHOTS, "example input index bound")
    snapshots = {}
    for key, entry in index["snapshots"].items():
        need(type(key) is str and re.fullmatch(r"[a-z0-9][a-z0-9_-]{0,63}", key), "example snapshot identifier")
        closed(entry, "descriptorHash provenance retrievalHash", "example snapshot")
        retrieval = (root / "sources" / (key + ".retrieval.json")).read_bytes()
        need(keccak256(retrieval) == entry["retrievalHash"], "example retrieval observation differs")
        snapshots[key] = ((root / "sources" / (key + ".descriptor.json")).read_bytes(),
            (root / "sources" / (key + ".nt")).read_bytes(), entry["descriptorHash"], entry["provenance"], retrieval)
    request = (root / "request.json").read_bytes()
    package = build(ORIGINAL_PROFILE_BYTES, request, snapshots, original_profile_hash=ORIGINAL_PROFILE_HASH,
        request_hash=keccak256(request), profile_hash=PROFILE_HASH)
    verify(package, keccak256(package["manifest.json"]))
    return package


def _discovery(root, index):
    need(type(index) is dict and len(index) <= 16, "discovery index bound")
    rows, total = [], 0
    for key, entry in sorted(index.items()):
        need(type(key) is str and re.fullmatch(r"[a-z0-9][a-z0-9_-]{0,63}", key), "discovery identifier")
        closed(entry, "kind schemeIri rawHash retrievalHash", "discovery index")
        raw = (root / "discovery" / (key + ".bin")).read_bytes()
        retrieval = (root / "discovery" / (key + ".retrieval.json")).read_bytes()
        need(0 < len(raw) <= v1.MAX_RAW and 0 < len(retrieval) <= MAX_INPUT, "discovery source bound")
        total += len(raw) + len(retrieval)
        need(total <= MAX_TOTAL and keccak256(raw) == entry["rawHash"]
            and keccak256(retrieval) == entry["retrievalHash"], "discovery original bytes differ")
        value = loads(retrieval, maximum=MAX_INPUT)
        closed(value, "uri finalUri status contentType bytes sha256 retrievedAt", "discovery retrieval")
        need(type(value["bytes"]) is int and value["bytes"] == len(raw) and value["sha256"] == sha256(raw).hexdigest()
            and type(value["status"]) is int and value["finalUri"] == value["uri"]
            and type(value["uri"]) is str and re.fullmatch(r"https://id\.loc\.gov/vocabulary/preservation/[A-Za-z][A-Za-z0-9]*(?:/[A-Za-z0-9][A-Za-z0-9._-]*)?\.nt", value["uri"]),
            "discovery retrieval differs")
        v1._text(value["contentType"], 256); v1._instant(value["retrievedAt"])
        facts, opaque = [], []
        if entry["kind"] == "scheme":
            _scheme(entry["schemeIri"])
            need(value["status"] == 200 and value["uri"] == "https:" + entry["schemeIri"][5:] + ".nt"
                and value["contentType"].split(";", 1)[0].strip() in ("text/plain", "application/n-triples"), "scheme discovery endpoint")
            facts, opaque = v1._facts(raw)
            need(any(f["subject"] == {"type": "IRI", "value": entry["schemeIri"]}
                and f["predicate"]["value"] == v1.RDF + "type"
                and f["object"] in ({"type": "IRI", "value": v1.MADS + "MADSScheme"},
                    {"type": "IRI", "value": v1.SKOS + "ConceptScheme"}) for f in facts), "scheme declaration absent")
        else:
            need(entry["kind"] == "unavailable" and entry["schemeIri"] is None and 400 <= value["status"] <= 599,
                "unavailable observation shape")
        rows.append({"id": key, **entry, "retrieval": value, "facts": facts, "opaqueReferences": opaque,
            "supportsTermBinding": False, "absenceProven": False, "publisherAuthenticated": False})
    return {"observations": rows, "qualification": "Separate original scheme discovery and failed HTTP observations. No term-endpoint substitution, publisher authentication or proof of absence."}


def example_outputs():
    root = ROOT / "schemas/museum/premis-authority-coverage/example/input"
    index_raw = (root / "index.json").read_bytes()
    index = loads(index_raw, maximum=MAX_INPUT, canonical=True)
    package = example_package()
    discovery = dumps(_discovery(root, index["discovery"]))
    return {"expected/report.json": package["report.json"], "expected/discovery.json": discovery,
        "pins.json": dumps({"version": "2", "mode": MODE, "profileHash": PROFILE_HASH,
            "originalProfileHash": ORIGINAL_PROFILE_HASH, "parentSnapshotProfileHash": v1.PROFILE_HASH,
            "inputIndexHash": keccak256(index_raw), "requestHash": keccak256(package["request.json"]),
            "manifestHash": keccak256(package["manifest.json"]), "reportHash": keccak256(package["report.json"]),
            "discoveryHash": keccak256(discovery), "termSnapshots": str(len(index["snapshots"])),
            "discoveryObservations": str(len(index["discovery"])), "packageFiles": str(len(package)),
            "packageBytes": str(sum(map(len, package.values()))), "qualification": QUALIFICATION})}


def example(check=False):
    root = ROOT / "schemas/museum/premis-authority-coverage/example"
    output = example_outputs()
    for name, raw in output.items():
        path = root / name
        if check: need(path.is_file() and path.read_bytes() == raw, "generated example differs")
        else: path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(raw)
    return loads(output["pins.json"])


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    command = commands.add_parser("definitions"); command.add_argument("--check", action="store_true")
    command = commands.add_parser("example"); command.add_argument("--check", action="store_true")
    command = commands.add_parser("verify"); command.add_argument("directory", type=Path); command.add_argument("--manifest-hash", required=True)
    args = parser.parse_args()
    if args.command == "definitions": print(definitions(args.check))
    elif args.command == "example": print(dumps(example(args.check)).decode())
    else: print(dumps(verify(read_tree(args.directory), args.manifest_hash)).decode())


if __name__ == "__main__":
    main()
