"""Exact offline LoC PREMIS event-term snapshots and prospective field bindings."""
from datetime import datetime
from hashlib import sha256
from pathlib import Path
import re

from pyld import jsonld

from tools.metadata.genesis_premis_profile import EVENT_AUTHORITY, profile as original_profile
from .authority_snapshot import RAW_BYTES, _absolute_iri, _utc
from .bagit import _paths, read_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint

ROOT = Path(__file__).resolve().parents[2]
MODE = "premis_authority_snapshot_bindings"
NAME = "STREAM_MUSEUM_PREMIS_AUTHORITY_SNAPSHOT_V1"
MAX_RAW = 1048576
MAX_INPUT = 65536
MAX_SNAPSHOTS = 16
MAX_TOTAL = 8 * 1048576
MAX_PACKAGE = 32 * 1048576
MAX_FACTS = 8192
RDF = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
MADS = "http://www.loc.gov/mads/rdf/v1#"
SKOS = "http://www.w3.org/2004/02/skos/core#"
OWL = "http://www.w3.org/2002/07/owl#"
DCT = "http://purl.org/dc/terms/"
RI = "http://id.loc.gov/ontologies/RecordInfo#"
CS = "http://purl.org/vocab/changeset/schema#"
XSD = "http://www.w3.org/2001/XMLSchema#"
PROVENANCE = ("synthetic_fixture", "supplied_bytes", "retained_http_observation")
ORIGINAL_PROFILE_BYTES = dumps(original_profile())
ORIGINAL_PROFILE_HASH = keccak256(ORIGINAL_PROFILE_BYTES)
QUALIFICATION = ("Exact retained LoC event-term bytes and prospective bindings to the unchanged CMC PREMIS profile. "
    "Source URI, retrieval time, attribution and provenance are caller-admitted observations, not publisher authentication. "
    "Source record change dates are not effective dates. Freshness is an explicit caller policy, not currentness or truth. "
    "No network access, identity merge, semantic equivalence, profile admission, signature authority or institutional acceptance.")
PROFILE_BYTES = dumps({"name": NAME, "version": "1", "mode": MODE,
    "status": "prospective_unregistered_source_adapter", "originalProfileHash": ORIGINAL_PROFILE_HASH,
    "scheme": EVENT_AUTHORITY, "syntax": "Bounded UTF-8 N-Triples lines, parsed with existing pinned PyLD; original literal ECHAR/UCHAR escapes are validated and decoded once. Named graphs and escaped IRIs are unsupported.",
    "relativeReferences": "Only original blank-node RecordInfo recordContentSource or ChangeSet creatorName <dlc> lines are retained as unresolved opaque references; never made absolute or treated as RDF facts.",
    "selection": "Explicit original eventTypes JSON Pointer, snapshot, term IRI and optional exact source version/effective-date lexical forms. No label-to-code lookup or automatic latest selection.",
    "dates": "Preserve all original source version/effective-date and linked admin/change-history facts with original line/byte selectors. Absent values stay not_supplied. No inferred UTC or effective date.",
    "freshness": "Required explicit asOf and maxSnapshotAgeSeconds; UTC timestamps have at most six fractional digits and historical inputs are retained even when outside that window.",
    "limits": {"snapshotBytes": str(MAX_RAW), "inputBytes": str(MAX_INPUT), "snapshots": str(MAX_SNAPSHOTS),
        "aggregateInputBytes": str(MAX_TOTAL), "factsPerSnapshot": str(MAX_FACTS), "packageBytes": str(MAX_PACKAGE)},
    "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def need(condition, message):
    if not condition:
        raise MuseumError("PREMIS authority " + message)


def closed(value, fields, label):
    need(type(value) is dict and set(value) == set(fields.split()), label + " fields")


def _pinned(raw, expected, maximum):
    need(type(raw) is bytes and 0 < len(raw) <= maximum, "input byte bound")
    hex_bytes(expected, 32)
    need(keccak256(raw) == expected, "external input hash differs")
    return loads(raw, maximum=maximum, canonical=True)


def _instant(value):
    _utc(value)
    need("." not in value or len(value.rsplit(".", 1)[1][:-1]) <= 6, "UTC precision exceeds microseconds")
    return datetime.fromisoformat(value[:-1] + "+00:00")


def _text(value, maximum=16384):
    need(type(value) is str and 0 < len(value) <= maximum and value.strip(), "text shape")


def _term_iri(value):
    need(type(value) is str and re.fullmatch(re.escape(EVENT_AUTHORITY) + r"/[a-z][a-z0-9]{0,31}", value),
        "exact LoC event term IRI required")


def _literal_lexical(line):
    # PyLD's line parser alone does not validate every ECHAR and can decode a
    # double-escaped sequence twice. Decode the original lexical token once.
    match = re.search(r'"((?:[^"\\\r\n]|\\.)*)"', line)
    need(match is not None, "original literal token absent")
    need("\\" not in line[:match.start()] + line[match.end():], "escaped IRI outside supported syntax")
    raw = match.group(1)
    escapes = {"t": "\t", "b": "\b", "n": "\n", "r": "\r", "f": "\f",
        '"': '"', "'": "'", "\\": "\\"}
    value, i = [], 0
    while i < len(raw):
        if raw[i] != "\\":
            value.append(raw[i]); i += 1; continue
        need(i + 1 < len(raw), "unterminated literal escape")
        marker = raw[i + 1]
        if marker in escapes:
            value.append(escapes[marker]); i += 2; continue
        need(marker in ("u", "U"), "unsupported literal escape")
        count = 4 if marker == "u" else 8
        digits = raw[i + 2:i + 2 + count]
        need(len(digits) == count and re.fullmatch(r"[0-9a-fA-F]+", digits), "Unicode escape shape")
        codepoint = int(digits, 16)
        need(codepoint <= 0x10ffff and not 0xd800 <= codepoint <= 0xdfff, "Unicode scalar escape")
        value.append(chr(codepoint)); i += 2 + count
    return "".join(value)


def _blank_node_lexical(line):
    # Inspect source tokens before PyLD normalizes blank-node identifiers.
    outside = re.sub(r'"(?:[^"\\\r\n]|\\.)*"', '""', line)
    for match in re.finditer(r"(?<!\S)(_:[^\s]+)", outside):
        token = match.group(1)
        tail = outside[match.end():].lstrip()
        if match.start() > 0 and token.endswith(".") and (not tail or tail.startswith("#")):
            token = token[:-1]  # The triple terminator may adjoin its object.
        need(not token.endswith("."), "blank-node label has a terminal dot")


def _facts(raw):
    need(type(raw) is bytes and 0 < len(raw) <= MAX_RAW, "raw byte bound")
    try:
        raw.decode("utf-8")
    except UnicodeError as exc:
        raise MuseumError("PREMIS authority raw UTF-8 required") from exc
    facts, opaque, offset = [], [], 0
    # The source's <dlc> references violate absolute-IRI N-Triples syntax.
    # Retain this finite observed exception without replacing any source byte.
    exception = re.compile(r'_:[A-Za-z0-9_](?:[A-Za-z0-9_.-]*[A-Za-z0-9_-])? <('
        + re.escape(RI + "recordContentSource") + "|" + re.escape(CS + "creatorName") + r')> <dlc> \.')
    for line_number, line in enumerate(raw.splitlines(keepends=True), 1):
        need(line_number <= MAX_FACTS and len(line) <= MAX_INPUT, "line bound")
        selector = {"line": str(line_number), "byteOffset": str(offset), "byteLength": str(len(line)),
            "rawHash": keccak256(line)}
        offset += len(line)
        text = line.decode("utf-8").rstrip("\r\n")
        _blank_node_lexical(text)
        if exception.fullmatch(text):
            opaque.append({"source": selector, "reason": "unresolved_original_relative_reference",
                "originalLine": text, "relativeLexicalValue": "dlc"})
            continue
        try:
            dataset = jsonld.JsonLdProcessor.parse_nquads(text)
        except (jsonld.JsonLdError, ValueError) as exc:
            raise MuseumError("PREMIS authority unsupported line syntax") from exc
        if not dataset:
            continue
        need(set(dataset) == {"@default"} and len(dataset["@default"]) == 1, "named graph or multiple triples")
        row = dataset["@default"][0]
        if row["object"]["type"] == "literal":
            row["object"]["value"] = _literal_lexical(text)
        else:
            need("\\" not in text, "escaped IRI outside supported syntax")
        for role in ("subject", "predicate", "object"):
            term = row[role]
            if term["type"] == "IRI":
                _absolute_iri(term["value"])
            if term["type"] == "literal" and "datatype" in term:
                _absolute_iri(term["datatype"])
        facts.append({**row, "source": selector})
    need(facts, "no RDF facts")
    return facts, opaque


def _selected(facts, subjects, predicates):
    return [f for f in facts if f["subject"]["value"] in subjects and f["predicate"]["value"] in predicates]


def parse_snapshot(descriptor_raw, raw, *, descriptor_hash, provenance):
    d = _pinned(descriptor_raw, descriptor_hash, MAX_INPUT)
    closed(d, "version termIri schemeIri sourceUri retrievedAt contentHash byteLength mediaType attribution reuseTerms provenance", "descriptor")
    need(d["version"] == "1" and d["schemeIri"] == EVENT_AUTHORITY, "descriptor version/scheme")
    _term_iri(d["termIri"])
    need(d["sourceUri"] in (d["termIri"] + ".nt", "https:" + d["termIri"][5:] + ".nt"),
        "documentary URI differs from explicit original term")
    _instant(d["retrievedAt"])
    need(provenance in PROVENANCE and d["provenance"] == provenance, "external provenance differs")
    need(d["mediaType"] in ("application/n-triples", "text/plain"), "unsupported source representation")
    for name in ("attribution", "reuseTerms"):
        _text(d[name])
    closed(d["contentHash"], "algorithm digest canonicalizationId", "raw content hash")
    h = d["contentHash"]
    need(h["algorithm"] in ("1", "2") and h["canonicalizationId"] == RAW_BYTES, "raw hash algorithm/canonicalization")
    hex_bytes(h["digest"], 32)
    need(type(raw) is bytes and 0 < len(raw) <= MAX_RAW and uint(d["byteLength"]) == len(raw), "raw size differs")
    digest = keccak256(raw) if h["algorithm"] == "1" else "0x" + sha256(raw).hexdigest()
    need(digest == h["digest"], "raw digest differs")
    facts, opaque = _facts(raw)
    own = _selected(facts, {d["termIri"]}, {f["predicate"]["value"] for f in facts})
    need(own, "original term subject absent")
    versions = _selected(facts, {d["termIri"]}, {OWL + "versionInfo", DCT + "hasVersion"})
    effective = _selected(facts, {d["termIri"]}, {DCT + "valid"})
    links = _selected(facts, {d["termIri"]}, {MADS + "adminMetadata", SKOS + "changeNote"})
    linked = {r["object"]["value"] for r in links if r["object"]["type"] in ("IRI", "blank node")}
    history = [f for f in facts if f["subject"]["value"] in linked]
    return {"descriptor": d, "descriptorHash": descriptor_hash, "rawHash": keccak256(raw),
        "provenance": provenance, "facts": facts, "opaqueReferences": opaque,
        "version": {"status": "supplied" if versions else "not_supplied", "facts": versions},
        "effectiveDates": {"status": "supplied" if effective else "not_supplied", "facts": effective},
        "recordHistory": {"links": links, "facts": history,
            "qualification": "Original administrative dates and status strings; no effective-date or timezone inference."},
        "publisherAuthenticated": False, "validNTriples": not opaque,
        "qualification": QUALIFICATION}


def _literal(fact):
    term = fact["object"]
    need(term["type"] == "literal", "expected literal fact")
    return term


def _check(snapshot, entry, original, as_of, age):
    d, facts = snapshot["descriptor"], snapshot["facts"]
    own = [r for r in facts if r["subject"] == {"type": "IRI", "value": entry["termIri"]}]
    reasons, ambiguous = [], False
    if entry["termIri"] != d["termIri"]:
        reasons.append("selected_term_differs")
    labels = [_literal(f) for f in own if f["predicate"]["value"] in (MADS + "authoritativeLabel", SKOS + "prefLabel")]
    labels = {(f["value"], f.get("language")) for f in labels
        if (f.get("language"), f.get("datatype")) in ((None, XSD + "string"), ("en", RDF + "langString"))}
    if len({value for value, _ in labels}) > 1:
        reasons.append("ambiguous_original_labels"); ambiguous = True
    if not any(value == original["target"] for value, _ in labels):
        reasons.append("profile_label_not_supported")
    code_terms = [_literal(f) for f in own if f["predicate"]["value"] in (MADS + "code", SKOS + "notation")]
    need(all(f.get("datatype") == XSD + "string" and "language" not in f for f in code_terms), "plain original code required")
    codes = {f["value"] for f in code_terms}
    if len(codes) > 1:
        reasons.append("ambiguous_original_codes"); ambiguous = True
    if codes != {entry["termIri"].rsplit("/", 1)[-1]}:
        reasons.append("original_code_differs")
    schemes = [f for f in own if f["predicate"]["value"] in (MADS + "isMemberOfMADSScheme", SKOS + "inScheme")]
    need(all(f["object"]["type"] == "IRI" for f in schemes), "scheme membership is not an IRI")
    scheme_values = {f["object"]["value"] for f in schemes}
    if EVENT_AUTHORITY not in scheme_values:
        reasons.append("exact_scheme_membership_missing")
    allowed_schemes = {EVENT_AUTHORITY, "http://id.loc.gov/vocabulary/preservation"}
    if scheme_values - allowed_schemes:
        reasons.append("ambiguous_scheme_membership"); ambiguous = True
    types = [f for f in own if f["predicate"]["value"] == RDF + "type"]
    need(all(f["object"]["type"] == "IRI" for f in types), "type is not an IRI")
    type_values = {f["object"]["value"] for f in types}
    if not type_values & {MADS + "Authority", SKOS + "Concept"}:
        reasons.append("authority_concept_type_missing")
    if type_values - {MADS + "Authority", SKOS + "Concept", MADS + "DeprecatedAuthority"}:
        reasons.append("ambiguous_original_types"); ambiguous = True
    if MADS + "DeprecatedAuthority" in type_values:
        reasons.append("original_term_deprecated")
    for f in own:
        if f["predicate"]["value"] in (DCT + "isReplacedBy", MADS + "hasLaterEstablishedForm"):
            reasons.append("original_term_replaced")
        if f["predicate"]["value"] == OWL + "deprecated" and _literal(f)["value"] in ("true", "1"):
            reasons.append("original_term_deprecated")
    if original["profileLocal"]:
        reasons.append("profile_local_mapping_requires_separate_review")
    elif original["valueUri"] is not None and original["valueUri"] != entry["termIri"]:
        reasons.append("original_profile_value_uri_differs")
    if original["authority"] != EVENT_AUTHORITY:
        reasons.append("original_profile_authority_differs")
    for required, field in (("requiredVersion", "version"), ("requiredEffectiveDate", "effectiveDates")):
        if entry[required] is not None:
            values = {_literal(f)["value"] for f in snapshot[field]["facts"]}
            if len(values) > 1:
                reasons.append("ambiguous_" + field); ambiguous = True
            if values != {entry[required]}:
                reasons.append(required + "_not_supported")
    elapsed = (as_of - _instant(d["retrievedAt"])).total_seconds()
    stale = elapsed < 0 or elapsed > age
    if stale:
        reasons.append("retrieved_after_as_of" if elapsed < 0 else "snapshot_outside_freshness_window")
    status = "ambiguous" if ambiguous else "stale" if stale else "unresolved" if reasons else "bound"
    return {"sourcePointer": entry["sourcePointer"], "snapshot": entry["snapshot"],
        "originalProfileEntry": original, "termIri": entry["termIri"], "status": status,
        "reasons": sorted(set(reasons)), "candidateValueUri": entry["termIri"] if status == "bound" else None,
        "sourceDescriptorHash": snapshot["descriptorHash"], "sourceRawHash": snapshot["rawHash"],
        "sourceProvenance": snapshot["provenance"], "supportingFacts": own,
        "version": snapshot["version"], "effectiveDates": snapshot["effectiveDates"],
        "recordHistory": snapshot["recordHistory"], "opaqueReferences": snapshot["opaqueReferences"]}


def bind(original_profile_raw, request_raw, snapshots, *, original_profile_hash, request_hash, profile_hash):
    need(profile_hash == PROFILE_HASH and original_profile_hash == ORIGINAL_PROFILE_HASH
        and original_profile_raw == ORIGINAL_PROFILE_BYTES, "exact original/adapter profile differs")
    request = _pinned(request_raw, request_hash, MAX_INPUT)
    closed(request, "version mode profileHash originalProfileHash asOf maxSnapshotAgeSeconds bindings", "request")
    need(request["version"] == "1" and request["mode"] == MODE and request["profileHash"] == profile_hash
        and request["originalProfileHash"] == original_profile_hash, "request profile binding differs")
    as_of = _instant(request["asOf"]); age = uint(request["maxSnapshotAgeSeconds"], 32)
    need(type(request["bindings"]) is list and len(request["bindings"]) <= MAX_SNAPSHOTS, "binding count")
    need(type(snapshots) is dict and len(snapshots) <= MAX_SNAPSHOTS, "snapshot count")
    total = len(request_raw) + len(original_profile_raw)
    for key, value in snapshots.items():
        need(type(key) is str and re.fullmatch(r"[a-z0-9][a-z0-9_-]{0,63}", key), "snapshot identifier")
        need(type(value) is tuple and len(value) == 4 and type(value[0]) is bytes and type(value[1]) is bytes, "snapshot input tuple")
        total += len(value[0]) + len(value[1])
    need(total <= MAX_TOTAL, "aggregate source bound")
    parsed, output = {}, {"source-profile.json": original_profile_raw, "request.json": request_raw, "profile.json": PROFILE_BYTES}
    for key, (descriptor, raw, pin, provenance) in snapshots.items():
        parsed[key] = parse_snapshot(descriptor, raw, descriptor_hash=pin, provenance=provenance)
        output["sources/" + key + ".descriptor.json"] = descriptor
        output["sources/" + key + ".nt"] = raw
        output["snapshots/" + key + ".json"] = dumps(parsed[key])
    used, rows, selections = set(), [], set()
    originals = original_profile()["eventTypes"]
    for entry in request["bindings"]:
        closed(entry, "sourcePointer snapshot termIri requiredVersion requiredEffectiveDate", "binding")
        pointer = entry["sourcePointer"]
        need(type(pointer) is str and re.fullmatch(r"/eventTypes/(0|[1-9][0-9]?)", pointer), "original field pointer")
        index = int(pointer.rsplit("/", 1)[1])
        need(index < len(originals), "original field absent")
        _term_iri(entry["termIri"])
        need(type(entry["snapshot"]) is str and entry["snapshot"] in parsed, "explicit snapshot absent")
        for name in ("requiredVersion", "requiredEffectiveDate"):
            if entry[name] is not None: _text(entry[name], 256)
        selection = (pointer, entry["snapshot"])
        need(selection not in selections, "duplicate binding selection"); selections.add(selection)
        used.add(entry["snapshot"])
        rows.append(_check(parsed[entry["snapshot"]], entry, originals[index], as_of, age))
    need(used == set(parsed), "unselected snapshot supplied")
    for row in rows:
        if sum(r["sourcePointer"] == row["sourcePointer"] for r in rows) > 1:
            row["status"] = "ambiguous"; row["candidateValueUri"] = None
            row["reasons"] = sorted(set(row["reasons"] + ["multiple_explicit_snapshots_for_field"]))
    output["report.json"] = dumps({"mode": MODE, "version": "1", "profileHash": PROFILE_HASH,
        "originalProfileHash": original_profile_hash, "requestHash": request_hash,
        "asOf": request["asOf"], "maxSnapshotAgeSeconds": request["maxSnapshotAgeSeconds"],
        "status": "bound" if rows and all(r["status"] == "bound" for r in rows) else "unresolved",
        "bindings": rows, "publisherAuthenticated": False, "currentAuthorityProven": False,
        "semanticEquivalenceProven": False, "originalProfileChanged": False, "qualification": QUALIFICATION})
    return output


def definitions(check=False):
    path = ROOT / "schemas/museum/premis-authority-snapshot/profile.json"
    if check:
        need(path.is_file() and path.read_bytes() == PROFILE_BYTES, "generated profile differs")
    else:
        path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(PROFILE_BYTES)
    return PROFILE_HASH


def _package_bound(files):
    need(type(files) is dict and len(files) <= 128 and all(type(p) is str and type(b) is bytes
        for p, b in files.items()) and sum(map(len, files.values())) <= MAX_PACKAGE, "package bounds")
    _paths(files)


def _inventory(files):
    return [{"path": p, "byteLength": str(len(b)), "keccak256": keccak256(b)} for p, b in sorted(files.items())]


def build(original_profile_raw, request_raw, snapshots, **pins):
    need(set(pins) == {"original_profile_hash", "request_hash", "profile_hash"}, "package pins")
    output = bind(original_profile_raw, request_raw, snapshots, **pins)
    _package_bound(output)
    manifest = dumps({"mode": MODE, "version": "1", "pins": pins,
        "snapshots": {key: {"descriptorHash": values[2], "provenance": values[3]}
            for key, values in sorted(snapshots.items())},
        "files": _inventory(output), "qualification": QUALIFICATION})
    need(len(manifest) <= MAX_INPUT, "manifest bound")
    output["manifest.json"] = manifest
    _package_bound(output)
    return output


def verify(files, manifest_hash):
    _package_bound(files)
    value = _pinned(files.get("manifest.json", b""), manifest_hash, MAX_INPUT)
    closed(value, "mode version pins snapshots files qualification", "manifest")
    need(value["mode"] == MODE and value["version"] == "1" and value["qualification"] == QUALIFICATION,
        "manifest constants")
    need(value["files"] == _inventory({p: b for p, b in files.items() if p != "manifest.json"}), "package inventory differs")
    need(type(value["snapshots"]) is dict and len(value["snapshots"]) <= MAX_SNAPSHOTS, "manifest snapshot count")
    closed(value["pins"], "original_profile_hash request_hash profile_hash", "manifest pins")
    snapshots = {}
    try:
        for key, row in value["snapshots"].items():
            need(type(key) is str and re.fullmatch(r"[a-z0-9][a-z0-9_-]{0,63}", key), "manifest snapshot identifier")
            closed(row, "descriptorHash provenance", "manifest snapshot")
            snapshots[key] = (files["sources/" + key + ".descriptor.json"], files["sources/" + key + ".nt"],
                row["descriptorHash"], row["provenance"])
        rebuilt = build(files["source-profile.json"], files["request.json"], snapshots, **value["pins"])
    except KeyError as exc:
        raise MuseumError("PREMIS authority original package input missing") from exc
    need(rebuilt == files, "package reconstruction differs")
    return loads(rebuilt["report.json"], maximum=MAX_PACKAGE, canonical=True)


def example_outputs():
    """Rebuild from retained inputs only. This function never retrieves a URI."""
    source = ROOT / "schemas/museum/premis-authority-snapshot/example/input"
    descriptor = (source / "ing.descriptor.json").read_bytes()
    raw = (source / "ing.nt").read_bytes()
    request = (source / "request.json").read_bytes()
    observation_raw = (source / "retrieval.json").read_bytes()
    observation = loads(observation_raw, maximum=MAX_INPUT)
    d = loads(descriptor, maximum=MAX_INPUT, canonical=True)
    closed(observation, "uri finalUri status contentType bytes sha256 retrievedAt", "example retrieval observation")
    need(observation["status"] == 200 and observation["uri"] == observation["finalUri"] == d["sourceUri"]
        and observation["retrievedAt"] == d["retrievedAt"] and observation["bytes"] == len(raw)
        and observation["sha256"] == sha256(raw).hexdigest()
        and observation["contentType"] == "text/plain; charset=UTF-8", "example retrieval observation differs")
    package = build(ORIGINAL_PROFILE_BYTES, request,
        {"ing": (descriptor, raw, keccak256(descriptor), d["provenance"])},
        original_profile_hash=ORIGINAL_PROFILE_HASH, request_hash=keccak256(request), profile_hash=PROFILE_HASH)
    verify(package, keccak256(package["manifest.json"]))
    return {"expected/report.json": package["report.json"], "expected/snapshot.json": package["snapshots/ing.json"],
        "pins.json": dumps({"mode": MODE, "version": "1", "profileHash": PROFILE_HASH,
            "originalProfileHash": ORIGINAL_PROFILE_HASH, "requestHash": keccak256(request),
            "descriptorHash": keccak256(descriptor), "rawSHA256": "0x" + sha256(raw).hexdigest(),
            "manifestHash": keccak256(package["manifest.json"]), "reportHash": keccak256(package["report.json"]),
            "snapshotHash": keccak256(package["snapshots/ing.json"]), "provenance": d["provenance"],
            "retrievalObservationHash": keccak256(observation_raw),
            "qualification": QUALIFICATION})}


def example(check=False):
    root = ROOT / "schemas/museum/premis-authority-snapshot/example"
    outputs = example_outputs()
    for name, raw in outputs.items():
        path = root / name
        if check:
            need(path.is_file() and path.read_bytes() == raw, "example output differs")
        else:
            path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(raw)
    return loads(outputs["pins.json"])


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("definitions", "example"):
        command = commands.add_parser(name); command.add_argument("--check", action="store_true")
    check = commands.add_parser("verify")
    check.add_argument("directory", type=Path); check.add_argument("--manifest-hash", required=True)
    args = parser.parse_args()
    if args.command == "definitions":
        print(definitions(args.check))
    elif args.command == "example":
        print(dumps(example(args.check)).decode())
    else:
        print(dumps(verify(read_tree(args.directory), args.manifest_hash)).decode())


if __name__ == "__main__":
    main()
