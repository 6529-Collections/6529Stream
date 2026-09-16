"""Deterministic, snapshot-bound authority reconciliation; no live lookup or identity grant."""
from copy import deepcopy
from urllib.parse import urlsplit

from jsonschema import FormatChecker

from .canonical import MuseumError, dumps, keccak256, loads, uint
from .schemas import HEX32, IRI, TEXT, arr, definitions, enum, obj
from .validation import StreamValidator

NAME = "STREAM_MUSEUM_AUTHORITY_ALIGNMENT_BODY_V1"
PROFILE = "STREAM_MUSEUM_AUTHORITY_RECONCILIATION_V1"
RELATION = "urn:6529stream:authority-alignment:v1"
DATATYPE = "urn:6529stream:datatype:authority-alignment:v1"
RULE = "urn:6529stream:museum:mapping:authority-alignment-v1"
CONTEXT = "https://linked.art/ns/v1/linked-art.json"
RDF_TYPE = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
SKOS = "http://www.w3.org/2004/02/skos/core#"
GVP = "http://vocab.getty.edu/ontology#"
P31 = "http://www.wikidata.org/prop/direct/P31"
AUTHORITIES = ("GETTY_TGN", "GETTY_AAT", "GETTY_ULAN", "VIAF", "WIKIDATA")
KINDS = ("Place", "Person", "Group", "Type")
NATIVE_KINDS = {"Place": "place", "Person": "person", "Group": "group", "Type": "type"}
CLAIMS = {key: False for key in ("registeredProfile", "institutionalConformance", "authorityPublisherAuthenticated",
    "namedHumanIdentityEstablished", "independentHumanReviewEstablished", "signingAuthorityGranted",
    "geographicTruthProven", "coordinatesInferred", "cryptographicStateProof")}
MAX_INPUT = 524288

# Finite exact facts, not ontology inference or recognition from labels/coordinates.
TYPE_RULES = {
    "GETTY_TGN": {"Place": {GVP + s for s in ("PhysPlaceConcept", "AdminPlaceConcept", "PhysAdminPlaceConcept")}},
    "GETTY_AAT": {"Type": {SKOS + "Concept", GVP + "Concept"}},
    "GETTY_ULAN": {"Person": {GVP + "PersonConcept"}, "Group": {GVP + "GroupConcept"}},
    "VIAF": {"Person": {"http://xmlns.com/foaf/0.1/Person", "http://schema.org/Person"},
             "Group": {"http://xmlns.com/foaf/0.1/Organization", "http://schema.org/Organization"}},
    "WIKIDATA": {"Person": {"http://www.wikidata.org/entity/Q5"},
                 "Group": {"http://www.wikidata.org/entity/Q43229", "http://www.wikidata.org/entity/Q4830453"},
                 "Place": {"http://www.wikidata.org/entity/Q515", "http://www.wikidata.org/entity/Q6256", "http://www.wikidata.org/entity/Q23442"}},
}
FOCUS_TYPES = {
    "Place": {"http://schema.org/Place", "http://www.w3.org/2003/01/geo/wgs84_pos#SpatialThing"},
    "Person": {"http://schema.org/Person", "http://xmlns.com/foaf/0.1/Person"},
    "Group": {"http://schema.org/Organization", "http://xmlns.com/foaf/0.1/Organization"},
}


def need(condition, message):
    if not condition: raise MuseumError("authority " + message)


def body_schema():
    fact = obj({"subject": IRI, "predicate": IRI, "object": IRI,
        "sourcePointer": dict(TEXT, minLength=1)})
    check = obj({"scope": enum("authority_catalog_hierarchy"), "fact": fact,
        "localStatement": dict(TEXT, minLength=1), "conclusion": enum("consistent", "conflicting", "unknown"),
        "rationale": dict(TEXT, minLength=1)})
    change = obj({"previousAssertionId": IRI, "previousAssertionHash": HEX32,
        "previousSnapshotRef": definitions()["document"],
        "disposition": enum("rename", "merge", "split", "deprecation", "hierarchy_change", "correction"),
        "rationale": dict(TEXT, minLength=1)})
    return {"$schema": "https://json-schema.org/draft/2020-12/schema", "$defs": definitions(),
        "title": NAME, "x-stream-document-status": "candidate_unregistered",
        **obj({"alignment": definitions()["alignment"], "entityKind": enum(*KINDS),
            "typeEvidence": arr(fact, 1, 16), "contextChecks": arr(check, maximum=16),
            "change": {"oneOf": [change, {"type": "null"}]}})}


BODY_SCHEMA = body_schema()
BODY_SCHEMA_BYTES = dumps(BODY_SCHEMA)
BODY_SCHEMA_HASH = keccak256(BODY_SCHEMA_BYTES)
ASSERTION_SCHEMA = {"$defs": definitions(), **definitions()["assertion"]}
REQUEST_SCHEMA = obj({"version": {"const": "1"}, "requests": arr(obj({"entityId": IRI,
    "entityKind": enum(*KINDS), "authority": enum(*AUTHORITIES), "sourceText": TEXT}), 1, 64)})
PROFILE_BYTES = dumps({"id": PROFILE, "version": "1", "status": "candidate_unregistered_derivative",
    "bodySchemaHash": BODY_SCHEMA_HASH, "relation": RELATION, "datatype": DATATYPE, "mappingRule": RULE,
    "bounds": {"requests": "64", "assertions": "128", "snapshots": "64", "snapshotBytes": "1048576", "aggregateSnapshotBytes": "16777216"},
    "crosswalk": [{"authority": authority, "entityKind": kind, "sourceSchema": NAME,
        "sourceSchemaHash": BODY_SCHEMA_HASH, "sourceSelector": "/alignment", "subjectKind": "supplemental_entity",
        "recordedDeclarationSupport": kind != "Type",
        "targetClass": kind, "propertyPath": ["https://linked.art/ns/terms/equivalent"], "cardinality": "0..1 per entity/authority",
        "sourceTypePredicate": P31 if authority == "WIKIDATA" else RDF_TYPE, "sourceTypes": sorted(types),
        "transformation": "exact_identity_preserve_vocabulary_and_focus", "authorityRule": "selected_authenticated_mapping_review",
        "uncertaintyRule": "withhold_ambiguous_unresolved_weaker_unreviewed", "reverseCorrespondence": "exact original body, selector and snapshot term pointers",
        "positiveTest": "test_five_authority_codes_and_qualified_equivalence", "negativeTest": "test_type_context_and_focus_fail_closed"}
        for authority, rules in TYPE_RULES.items() for kind, types in rules.items()],
    "policy": {"draft": "Suggestions remain unreviewed and never emit equivalent.",
        "typeGuards": {"focusTypes": {key: sorted(value) for key, value in FOCUS_TYPES.items()},
            "focusIdentity": "Getty TGN -place and ULAN -agent remain distinct from the concept; unsupported focus identities withhold projection.",
            "deprecation": "Retain and withhold snapshots declaring GVP ObsoleteSubject, owl:deprecated true/1 or dct:isReplacedBy; never follow replacements silently."},
        "review": "Recorded independent-account mappings require opted-in original account SELF review, bound to exact assertion revision/profile/rule. Named or independently qualified human identity remains unproved.",
        "declarations": "Recorded candidates bind their exact original local declaration selector/hash. Reuse of an existing dossier identity requires that same selected declaration; external identities and competing new declarations withhold projection. Later declaration continuation requires a future explicit policy.",
        "conflict": "Multiple eligible distinct identities per entity/authority are ambiguous; no name, rank, coordinates or recency tie-breaker.",
        "weaker": "close_match and related_reference remain in the Stream sidecar; no owl:sameAs or skos:exactMatch.",
        "history": "Corrections require selected same-issuer predecessor, exact assertion hash/snapshot and later publication; retain every old assertion and snapshot.",
        "focus": "Linked Art uses the authority canonical identity. Separate focus relation retained without equating concept and focus.",
        "hierarchy": "Authority catalog context is an attributed consistency check, never an inferred physical containment or sovereignty claim."},
    "claims": CLAIMS})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _validate(schema, raw, maximum=MAX_INPUT):
    value = loads(raw, maximum=maximum, canonical=True)
    errors = sorted(StreamValidator(schema, format_checker=FormatChecker()).iter_errors(value), key=lambda e: str(e.path))
    need(not errors, "schema validation: " + (errors[0].message if errors else ""))
    return value


def _local_entity_iri(value):
    try:
        parsed = urlsplit(value); host = (parsed.hostname or "").lower().rstrip(".")
        parsed.port
    except ValueError as exc: raise MuseumError("authority malformed local entity IRI") from exc
    reserved = ("vocab.getty.edu", "wikidata.org", "viaf.org")
    need(not value.casefold().startswith(("eip155:", "urn:6529stream:account:"))
        and not any(host == name or host.endswith("." + name) for name in reserved),
        "authority/account IRI cannot be a local entity")


def alignment_literal(body):
    raw = dumps(body); _validate(BODY_SCHEMA, raw, 8192)
    return {"lexicalValue": raw.decode("utf-8"), "datatype": DATATYPE,
        "language": None, "unit": None, "precision": None}


def _body(assertion):
    _validate(ASSERTION_SCHEMA, dumps(assertion), 24576)
    need(assertion["relation"] == RELATION and assertion["mappingRule"] == RULE, "alignment relation/rule differs")
    literal = assertion["object"].get("literal")
    need(isinstance(literal, dict) and literal["datatype"] == DATATYPE
        and all(literal[key] is None for key in ("language", "unit", "precision")), "alignment literal differs")
    body = _validate(BODY_SCHEMA, literal["lexicalValue"].encode("utf-8"), 8192)
    a = body["alignment"]
    need(a["assertionId"] == assertion["id"] and a["entityId"] == assertion["subject"], "alignment assertion identity differs")
    need(a["basis"] and assertion["rationale"], "alignment rationale missing")
    if assertion["origin"] == "automated_mapping":
        need(assertion["reviewStatus"] == "unreviewed", "automated suggestion must start unreviewed")
    need((body["change"] is None and not assertion["corrects"]) or
        (body["change"] is not None and assertion["corrects"] == [body["change"]["previousAssertionId"]]), "correction lineage differs")
    return body


def _snapshots(values):
    from .authority_snapshot import parse_snapshot
    from .dependencies import safe_path
    from pathlib import Path
    need(isinstance(values, dict) and len(values) <= 64, "snapshot map bound")
    need(all(isinstance(item, tuple) and len(item) == 3 and type(item[0]) is bytes and type(item[1]) is bytes for item in values.values()), "snapshot value shape")
    need(sum(len(item[0]) + len(item[1]) for item in values.values()) <= 16777216, "aggregate snapshot bound")
    result, paths = {}, set()
    for path, item in values.items():
        safe_path(Path.cwd(), path)
        need(path.casefold() not in paths and isinstance(item, tuple) and len(item) == 3, "snapshot path/value shape")
        paths.add(path.casefold())
        descriptor_bytes, raw, descriptor_hash = item
        result[path] = parse_snapshot(descriptor_bytes, raw, descriptor_hash=descriptor_hash)
    return result


def _term_matches(fact, rows):
    return any(row["sourcePointer"] == fact["sourcePointer"] and row["subject"] == fact["subject"]
        and row["predicate"] == fact["predicate"] and row["object"] == {"type": "uri", "value": fact["object"]} for row in rows)


def _inspect(body, snapshots):
    """Return all eligibility limitations while retaining unsupported candidate bytes."""
    from .authority_snapshot import canonical_authority_iri
    a = body["alignment"]; reasons = []; used = []
    need(a["canonicalIri"] == canonical_authority_iri(a["authority"], a["identifier"]), "canonical authority identity differs")
    snap = snapshots.get(a["snapshotRef"]["path"])
    if snap is None: return ["snapshot_not_supplied"], used
    descriptor = snap["descriptor"]
    need(all(descriptor[key] == a[key] for key in ("authority", "identifier", "canonicalIri", "retrievedAt")), "snapshot alignment descriptor differs")
    need(all(a["snapshotRef"][key] == descriptor[key] for key in ("contentHash", "byteLength", "mediaType")), "snapshot reference differs")
    need(a["focusIri"] == snap["focusIri"], "snapshot focus relation differs")
    if a["focusIri"] is not None and a["authority"] in ("GETTY_TGN", "GETTY_ULAN"):
        suffix = "-place" if a["authority"] == "GETTY_TGN" else "-agent"
        if a["focusIri"] != a["canonicalIri"] + suffix: reasons.append("unsupported_focus_identity")
    labels = [row for row in snap["labels"] if row["value"] == a["labelAtReview"]["value"] and row["language"] == a["labelAtReview"]["language"]]
    need(labels, "reviewed label absent from exact snapshot")
    used.extend(row["sourcePointer"] for row in labels)
    revisions = {row["object"]["value"] for row in snap["revisions"]}
    need((a["authorityRevision"] == "not_supplied" and not revisions) or a["authorityRevision"] in revisions,
        "authority revision differs from snapshot")
    used.extend(row["sourcePointer"] for row in snap["revisions"])
    allowed = TYPE_RULES.get(a["authority"], {}).get(body["entityKind"], set())
    expected_predicate = P31 if a["authority"] == "WIKIDATA" else RDF_TYPE
    for fact in body["typeEvidence"]:
        need(_term_matches(fact, snap["typeFacts"]), "type evidence absent from snapshot")
        used.append(fact["sourcePointer"])
    if not any(f["subject"] == a["canonicalIri"] and f["predicate"] == expected_predicate and f["object"] in allowed for f in body["typeEvidence"]):
        reasons.append("unsupported_or_mismatched_entity_type")
    # A claimant cannot cherry-pick a compatible type while hiding a contradictory supported type.
    supported_other = set().union(*(types for kind, types in TYPE_RULES.get(a["authority"], {}).items() if kind != body["entityKind"]))
    if any(f["predicate"] == expected_predicate and f["object"]["value"] in supported_other for f in snap["typeFacts"]):
        reasons.append("conflicting_authority_entity_types")
    incompatible_focus = set().union(*(values for kind, values in FOCUS_TYPES.items() if kind != body["entityKind"]))
    if any(f["predicate"] == RDF_TYPE and f["object"]["value"] in incompatible_focus for f in snap["typeFacts"]):
        reasons.append("conflicting_authority_focus_type")
    for fact in snap["triples"]:
        if fact["subject"] != a["canonicalIri"]: continue
        term = fact["object"]
        if ((fact["predicate"] == RDF_TYPE and term == {"type": "uri", "value": GVP + "ObsoleteSubject"})
            or (fact["predicate"] == "http://www.w3.org/2002/07/owl#deprecated" and term["type"] == "literal" and term["value"] in ("true", "1"))
            or fact["predicate"] == "http://purl.org/dc/terms/isReplacedBy"):
            reasons.append("authority_record_deprecated_or_replaced"); used.append(fact["sourcePointer"])
    for check in body["contextChecks"]:
        need(_term_matches(check["fact"], snap["hierarchyFacts"]), "geographic context absent from snapshot")
        used.append(check["fact"]["sourcePointer"])
    if body["entityKind"] == "Place" and not body["contextChecks"]: reasons.append("geographic_context_not_checked")
    if any(check["conclusion"] != "consistent" for check in body["contextChecks"]): reasons.append("geographic_context_unresolved")
    return reasons, sorted(set(used))


def _reconcile(request_bytes, candidates, snapshots, *, request_hash, profile_hash, mode, model=None):
    from .exhibitions import fields
    need(profile_hash == PROFILE_HASH and keccak256(request_bytes) == request_hash, "external profile/request pin differs")
    plan = _validate(REQUEST_SCHEMA, request_bytes)
    need(len(candidates) <= 128, "assertion bound")
    snapshots = _snapshots(snapshots)
    requests = {(row["entityId"], row["authority"]): row for row in plan["requests"]}
    need(len(requests) == len(plan["requests"]), "duplicate entity/authority request")
    kinds = {}
    for row in plan["requests"]:
        need(row["entityId"] not in kinds or kinds[row["entityId"]] == row["entityKind"], "conflicting local entity kinds")
        _local_entity_iri(row["entityId"])
        kinds[row["entityId"]] = row["entityKind"]
    rows, by_id, referenced = [], {}, set()
    for candidate in candidates:
        assertion = candidate["assertion"]; body = _body(assertion); a = body["alignment"]
        need(assertion["id"] not in by_id, "duplicate assertion identity")
        need((a["entityId"], a["authority"]) in requests, "candidate outside requested scope")
        need(requests[(a["entityId"], a["authority"])]["entityKind"] == body["entityKind"], "local requested type differs")
        referenced.add(a["snapshotRef"]["path"])
        reasons, used = _inspect(body, snapshots)
        if mode == "recorded_account_authority_reconciliation" and body["entityKind"] == "Type":
            reasons.append("recorded_type_declaration_unsupported")
        if not candidate["eligible"]: reasons.append(candidate["eligibilityReason"])
        if assertion["reviewStatus"] in ("withdrawn", "disputed"): reasons.append("withdrawn_or_disputed_alignment")
        row = {"assertion": deepcopy(assertion), "assertionHash": keccak256(dumps(assertion)), "body": body,
            "source": candidate["source"], "reviewEvidence": candidate["reviews"], "selectionBasis": candidate["basis"],
            "position": candidate["position"], "reasons": sorted(set(reasons)), "snapshotPointers": used,
            "eligible": not reasons, "supersededBy": []}
        if "entityDeclaration" in candidate: row["entityDeclaration"] = deepcopy(candidate["entityDeclaration"])
        rows.append(row); by_id[assertion["id"]] = row
    need(set(snapshots) <= referenced, "unreferenced authority snapshot")
    # Use authenticated publication order where supplied; never recency as a truth tie-breaker.
    position = lambda row: tuple(uint(v, 64) for v in row["position"])
    for row in sorted(rows, key=lambda r: (position(r), r["assertion"]["id"])):
        change = row["body"]["change"]
        if change is None or not row["eligible"]: continue
        previous = by_id.get(change["previousAssertionId"])
        valid = previous is not None
        if valid:
            old, new = previous["body"]["alignment"], row["body"]["alignment"]
            valid = (change["previousAssertionHash"] == previous["assertionHash"]
                and change["previousSnapshotRef"] == old["snapshotRef"]
                and row["assertion"]["assertingAgent"] == previous["assertion"]["assertingAgent"]
                and (old["entityId"], old["authority"]) == (new["entityId"], new["authority"])
                and position(previous) < position(row)
                and (change["disposition"] == "correction" or old["snapshotRef"]["contentHash"] != new["snapshotRef"]["contentHash"]))
        if not valid:
            row["eligible"] = False; row["reasons"].append("unresolved_predecessor_or_disposition")
        else: previous["supersededBy"].append(row["assertion"]["id"])
    results, resources, provenance = [], {}, []
    for key, request in sorted(requests.items()):
        scoped = [row for row in rows if (row["body"]["alignment"]["entityId"], row["body"]["alignment"]["authority"]) == key]
        eligible = [row for row in scoped if row["eligible"] and not row["supersededBy"]]
        identities = {row["body"]["alignment"]["canonicalIri"] for row in eligible if row["body"]["alignment"]["matchKind"] == "equivalent_entity"}
        status = "ambiguous" if len(identities) > 1 else "resolved" if identities else "unresolved"
        reason = "competing_eligible_identities" if len(identities) > 1 else "reviewed_snapshot_alignment" if identities else "no_selected_identity_alignment"
        if mode == "recorded_account_authority_reconciliation" and request["entityKind"] == "Type":
            reason = "recorded_type_declaration_unsupported"
        results.append({**request, "status": status, "reasonCode": reason,
            "candidateAssertions": sorted(row["assertion"]["id"] for row in scoped), "candidateIdentities": sorted(identities)})
        if status != "resolved": continue
        matches = [row for row in eligible if row["body"]["alignment"]["matchKind"] == "equivalent_entity"]
        identity = next(iter(identities)); kind = request["entityKind"]
        resource = resources.setdefault(request["entityId"], {"@context": CONTEXT, "id": request["entityId"], "type": kind,
            "_label": request["entityId"], "equivalent": []})
        # Local labels never become silently replaced with authority prose.
        target = {"id": identity, "type": kind, "_label": identity}
        if target not in resource["equivalent"]: resource["equivalent"].append(target)
        provenance.append({"entity": request["entityId"], "property": "https://linked.art/ns/terms/equivalent", "value": identity,
            "mappingRule": RULE, "sources": [{"assertionId": r["assertion"]["id"], "assertionHash": r["assertionHash"],
                "selector": r["source"], "reviewEvidence": r["reviewEvidence"], "snapshotRef": r["body"]["alignment"]["snapshotRef"],
                "snapshotPointers": r["snapshotPointers"],
                **({"entityDeclaration": r["entityDeclaration"]} if "entityDeclaration" in r else {})}
                for r in sorted(matches, key=lambda r: r["assertion"]["id"])],
            "qualification": "Scoped reviewed alignment; external identity recognition grants no Stream signing authority."})
    files, index = {}, []
    for identifier, resource in sorted(resources.items()):
        resource["equivalent"].sort(key=lambda r: r["id"])
        name = keccak256(identifier.encode("utf-8"))[2:]; raw = dumps(resource)
        path = "authority/resources/" + name + ".json"; files[path] = raw
        if model is not None: files["authority/expanded/" + name + ".json"] = model.validate_and_expand(raw).expanded_bytes
        index.append({"id": identifier, "type": resource["type"], "path": path})
    report = {"mode": mode, "version": "1", "profileHash": PROFILE_HASH, "requestHash": request_hash,
        "results": results, "claims": CLAIMS, "sourceAuthentication": "historical_independent_account" if mode == "recorded_account_authority_reconciliation" else "not_established",
        "linkedArtValidation": "validated_emitted_resources" if model else "not_evaluated",
        "qualification": "Deterministic scoped reconciliation. Snapshot integrity is checked; publisher identity, real-world equivalence and qualified human independence remain separate evidence."}
    coverage = [{"source": row["source"], "assertionId": row["assertion"]["id"], "assertionHash": row["assertionHash"],
        "sourcePath": path, "value": value, "disposition": "retained_original_assertion"}
        for row in sorted(rows, key=lambda r: r["assertion"]["id"]) for path, value in fields(row["assertion"])]
    files.update({"authority/report.json": dumps(report), "authority/index.json": dumps({"resources": index}),
        "authority/sidecar.json": dumps(sorted(rows, key=lambda r: r["assertion"]["id"])), "authority/provenance.json": dumps(provenance),
        "authority/snapshot-index.json": dumps(snapshots), "authority/coverage.json": dumps(coverage)})
    return files


def reconcile_draft(request_bytes, assertions_bytes, snapshots, *, request_hash, assertions_hash, profile_hash):
    need(keccak256(assertions_bytes) == assertions_hash, "external draft assertion pin differs")
    assertions = loads(assertions_bytes, maximum=MAX_INPUT, canonical=True)
    need(isinstance(assertions, list) and len(assertions) <= 128, "draft assertion list bound")
    candidates = [{"assertion": a, "eligible": False, "eligibilityReason": "unreviewed_draft_suggestion", "source": None,
        "reviews": [], "basis": "draft_unverified", "position": ["0", "0", str(i)]} for i, a in enumerate(assertions)]
    return _reconcile(request_bytes, candidates, snapshots, request_hash=request_hash, profile_hash=profile_hash, mode="draft_preview")


def main():
    import argparse
    from pathlib import Path
    p = argparse.ArgumentParser(description="Generate/check prospective authority definitions; no registration or lookup.")
    p.add_argument("--check", action="store_true"); args = p.parse_args()
    root = Path(__file__).resolve().parents[2] / "schemas/museum/authority"
    for name, raw in ((NAME, BODY_SCHEMA_BYTES), ("profile", PROFILE_BYTES)):
        path = root / (name + ".json")
        if args.check: need(path.is_file() and path.read_bytes() == raw, "generated definition differs")
        else: root.mkdir(parents=True, exist_ok=True); path.write_bytes(raw)
    print(PROFILE_HASH)


if __name__ == "__main__": main()
