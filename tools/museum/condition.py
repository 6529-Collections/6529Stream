"""Exact prospective condition/treatment payloads and attributed pure projections.

These helpers do not authenticate source receipts or execute conservation checks.
An authenticated owner/independent adapter must establish those facts separately.
"""
from copy import deepcopy
from decimal import Decimal

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, subject_id, uint
from .citations import parse_citation
from .exhibitions import _date, _instant, _iri, _reference, fields, nullable
from .preservation_graph import CONTEXT, VALIDATION_HASH
from .review import _validate
from .schemas import ADDRESS, HEX32, IRI, TEXT, UINT, arr, definitions, enum, obj

NAME = "STREAM_CONDITION_REPORT_V1"
TREATMENT_NAME = "STREAM_MUSEUM_CONSERVATION_TREATMENT_V1"
MODE = "draft_submitted_condition_conservation_projection"
ZERO = "0x" + "00" * 32
QUALIFICATION = "Attributed condition/conservation statement; receipt authority, protocol checks, examination, named identity and treatment performance require separate evidence."
CLAIMS = {key: False for key in (
    "actualSourceAuthenticated", "protocolStateProven", "finalityProven", "routeMatchProven",
    "latestFixityCycleProven", "payloadCoverageProven", "renderAcceptanceProven",
    "examinerIdentityProven", "examinerIndependenceProven", "recoveryExecutionProven",
    "ownerResponseAuthorityProven", "captureFormatRegistryProven", "referenceBytesRetrieved",
    "captureFixityProven", "historicalExaminationProven", "treatmentPerformanceProven",
    "treatmentAuthorized", "artistIntentComplianceProven", "institutionalConformance",
    "registeredExport")}
JOIN_REASONS = {
    "protocolState": "actual_examination_state_not_joined",
    "finality": "actual_verify_finality_and_route_calls_not_joined",
    "fixity": "actual_latest_cycle_and_complete_token_payload_population_not_joined",
    "render": "actual_pinned_mode_execution_and_acceptance_authority_not_joined",
    "recovery": "actual_executed_manifests_and_owner_response_lanes_not_joined",
    "captures": "capture_bytes_and_registered_format_documents_not_joined",
    "examiner": "named_examiner_identity_and_independence_not_established",
    "treatment": "actual_treatment_execution_and_authorization_not_joined",
}
NONEMPTY = dict(TEXT, minLength=1)
DECIMAL = {"type": "string", "pattern": "^-?(0|[1-9][0-9]*)(\\.[0-9]+)?$", "maxLength": 256}


def documents():
    reference = obj({"uri": IRI, "hash": definitions()["hashRef"]})
    record = obj({"recordHash": HEX32, "uri": IRI, "hash": definitions()["hashRef"]})
    name = obj({"value": NONEMPTY, "language": {"type": ["string", "null"], "maxLength": 128}})
    person = obj({"entityId": IRI, "kind": enum("Person", "Group"), "name": nullable(name),
        "reference": reference, "institution": nullable(reference), "credentials": arr(reference, maximum=16)})
    route = obj({"renderer": ADDRESS, "routeHash": HEX32})
    state = obj({"blockNumber": UINT, "blockHash": HEX32, "stateRoot": HEX32, "observation": reference})
    capture = obj({"captureId": IRI, "captureClass": enum("still", "frame_sequence", "av_container", "scripted_session"),
        "uri": IRI, "hash": definitions()["hashRef"],
        "format": obj({"formatId": HEX32, "registryEntry": reference}), "displayHardwareInstallationNote": TEXT})
    evaluation = obj({"propertyId": IRI, "sourcePointer": NONEMPTY,
        "outcome": enum("equivalent", "different", "inconclusive"), "note": TEXT, "evidence": arr(reference, 1, 16)})
    acceptance = {"oneOf": [
        obj({"mode": enum("BYTE_EXACT"), "referenceRender": record,
            "rendererClass": enum("STATIC", "DYNAMIC"),
            "softwareRasterization": {"type": "boolean"}, "environment": reference}),
        obj({"mode": enum("PERCEPTUAL_TOLERANCE"), "referenceRender": record,
            "metricId": HEX32, "metricDefinition": reference, "threshold": DECIMAL,
            "comparison": enum("greater_than_or_equal", "less_than_or_equal"), "observedValue": nullable(DECIMAL)}),
        obj({"mode": enum("CURATED_EQUIVALENCE"), "referenceRender": record,
            "artistIntent": record, "attestation": nullable(record),
            "attestationLane": nullable(enum("INSTITUTIONAL_VERIFICATION", "INDEPENDENT_CONDITION")),
            "evidenceClass": nullable(enum("SIGNER_VERIFIED")), "evaluations": arr(evaluation, maximum=64)})]}
    recovery_entry = obj({"recoveryId": IRI, "manifest": record, "executedAt": definitions()["date"],
        "beforeContent": definitions()["hashRef"], "afterContent": definitions()["hashRef"],
        "ownerResponses": arr(record, maximum=16)})
    condition = obj({"version": enum("1"), "reportId": IRI, "tokenId": UINT,
        "examinationDate": definitions()["date"], "examiner": person, "workCitation": NONEMPTY,
        "protocolState": state,
        "finality": obj({"verifyFinality": enum("pass", "fail", "not_verified"),
            "finalityHash": nullable(HEX32), "routeMatch": enum("match", "mismatch", "not_verified"),
            "expectedRoute": nullable(route), "observedRoute": nullable(route),
            "reason": nullable(NONEMPTY), "evidence": arr(reference, maximum=16)}),
        "fixity": obj({"status": enum("covered", "uncovered_overdue", "in_window", "onchain_bound",
                "service_backed_mutable", "failed", "not_checked"),
            "cycle": nullable(record), "latestCycleClaimed": {"type": "boolean"},
            "coverage": enum("complete", "partial", "unknown"), "reason": nullable(NONEMPTY),
            "payloads": arr(obj({"objectId": IRI, "reference": reference,
                "result": enum("pass", "fail", "not_checked")}), maximum=64)}),
        "render": obj({"outcome": enum("pass", "fail", "not_verified"), "method": nullable(reference),
            "reason": nullable(NONEMPTY), "acceptance": acceptance, "evidence": arr(reference, maximum=16)}),
        "recoveryLineage": obj({"status": enum("none", "recorded"),
            "statement": NONEMPTY, "entries": arr(recovery_entry, maximum=32)}),
        "captures": arr(capture, maximum=32), "narrative": NONEMPTY})
    artifact = obj({"objectId": IRI, "role": enum("source", "outcome", "subject", "supporting"),
        "reference": reference, "formatId": nullable(HEX32)})
    treatment = obj({"version": enum("1"), "treatmentId": IRI, "tokenId": UINT,
        "workCitation": NONEMPTY, "kind": enum("conservation_note", "treatment", "environment_migration"),
        "eventType": enum("CONSERVATION_NOTE", "MIGRATION", "NORMALIZATION", "MEDIA_DERIVATION"),
        "status": enum("planned", "completed", "cancelled", "unknown"), "eventDate": definitions()["date"],
        "agents": arr(obj({"agent": person, "role": enum("conservator", "examiner", "operator", "author", "reviewer")}), 1, 32),
        "artifacts": arr(artifact, 1, 32), "treatmentClass": nullable(IRI), "method": nullable(reference),
        "description": NONEMPTY, "outcome": enum("SUCCESS", "WARNING", "FAILED", "INCONCLUSIVE", "NOT_PERFORMED"),
        "outcomeDetail": TEXT, "evidence": arr(reference, maximum=32),
        "artistIntent": nullable(record), "authorization": nullable(record),
        "beforeCondition": nullable(record), "afterCondition": nullable(record),
        "migration": nullable(obj({"sourceObjectId": IRI, "outcomeObjectId": IRI,
            "bootOutcome": enum("pass", "fail", "not_checked"), "acceptanceOutcome": enum("pass", "fail", "not_checked"),
            "evidence": arr(reference, maximum=16)}))})
    return {name: {"$schema": "https://json-schema.org/draft/2020-12/schema", "title": name,
        "$id": "urn:6529stream:schema:" + name,
        "x-stream-document-status": "candidate_unregistered",
        "x-stream-semantic-checks": "Pure shape and consistency checks do not establish actual state, signer authority, performance or conformance.",
        **body} for name, body in ((NAME, condition), (TREATMENT_NAME, treatment))}


SCHEMAS = {name: dumps(value) for name, value in documents().items()}
SCHEMA_BYTES = SCHEMAS[NAME]
SCHEMA_HASH = keccak256(SCHEMA_BYTES)
TREATMENT_SCHEMA_BYTES = SCHEMAS[TREATMENT_NAME]
PROFILE_BYTES = dumps({"id": "STREAM_MUSEUM_CONDITION_CONSERVATION_PROFILE_V1", "version": "1",
    "status": "prospective_unregistered_export_profile", "mode": MODE, "context": CONTEXT,
    "sourceSchemas": {name: {"id": schema_id(name), "hash": keccak256(raw)} for name, raw in SCHEMAS.items()},
    "validationPolicyHash": VALIDATION_HASH, "qualification": QUALIFICATION, "claims": CLAIMS,
    "bounds": {"payloadBytes": "24576", "reports": "64", "captures": "32", "recoveryEntries": "32"},
    "rules": {
        "schema": "Exact complete candidate bytes only. Older same-name opaque fixture documents retain their original meaning; unsupported bytes are retained without typed interpretation.",
        "source": "Pure submitted payloads are draft/synthetic. Authenticated wrappers must preserve original owner or independent selectors and authority; examiner names never establish signer identity or independence.",
        "state": "Required canonical state-qualified original-token citation, explicit examination state, finality/route, latest-cycle claim, render acceptance and ordered executed-recovery assertions. Actual state joins remain separately unproven.",
        "render": "BYTE_EXACT requires declared deterministic software rasterization; DYNAMIC is rejected. Metric/threshold bytes remain exact declarations. CURATED_EQUIVALENCE requires named examiner/institution/credentials, signer-class attestation reference and field evaluation for checked outcomes; no authority is inferred.",
        "capture": "Ordered hash-bound class/format/installation entries; references do not establish retrieved bytes, registered format or actual observations.",
        "treatment": "Prospective PREMIS-aligned event specialization with artifacts, agents/roles, outcome, method and evidence. Completed intervention is an attributed Activity; conservation note and unperformed plans never become performed interventions. No rights or intent compliance inferred.",
        "comparison": "Same original-token identity required; exact field differences and ordered recovery-prefix correspondence retained. Comparison does not prove equivalence, executed lawful recovery or damage.",
        "coverage": "All source values, nulls, empty collections and order retained with JSON pointers. Stable explicit IDs have typed collision checks; repeated named agents require identical complete declarations."},
    "crosswalk": [
        {"source": "/reportId,/narrative", "target": "LinguisticObject/id,content", "authority": "source statement",
            "cardinality": "one document per condition report", "uncertainty": "examination unproven", "reverse": "whole exact payload and source pointers",
            "positive": "test_condition_projection_preserves_every_field", "negative": "test_opaque_original_schema_is_not_reinterpreted"},
        {"source": "/examiner,/agents", "target": "Person or Group and attributed role sidecar", "authority": "named-party claim",
            "cardinality": "each explicitly named declaration", "uncertainty": "identity and independence unproven", "reverse": "whole party declaration",
            "positive": "test_curated_acceptance_remains_unproven", "negative": "test_identity_collision_rejected"},
        {"source": "/protocolState,/finality,/fixity,/render,/recoveryLineage,/captures", "target": "typed Stream dossier",
            "authority": "source assertion", "cardinality": "complete field set", "uncertainty": "actual joins unproven", "reverse": "exact source payload",
            "positive": "test_comparison_retains_changed_state_and_recovery", "negative": "test_comparison_rejects_other_work_and_reverse_time"},
        {"source": "/treatmentId,/kind,/status,/artifacts,/agents,/migration", "target": "completed attributed Activity and PREMIS-aligned Stream dossier",
            "authority": "source statement", "cardinality": "at most one performed intervention", "uncertainty": "performance and authority unproven",
            "reverse": "exact event/artifact/agent roles and references", "positive": "test_completed_treatment_and_migration",
            "negative": "test_notes_and_plans_never_emit_interventions"}]})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def need(ok, message):
    if not ok:
        raise MuseumError("condition " + message)


def _hash(value):
    need(any(hex_bytes(value, 32)), "zero commitment")


def _ref(value):
    _reference(value)
    if "recordHash" in value:
        _hash(value["recordHash"])


def _party(value):
    _iri(value["entityId"])
    need(not value["entityId"].casefold().startswith(("urn:6529stream:account:", "eip155:")), "named account equivalence")
    _ref(value["reference"])
    if value["institution"] is not None:
        _ref(value["institution"])
    for item in value["credentials"]:
        _ref(item)


def _references(value):
    """Visit complete reference objects without rewriting source order or values."""
    if isinstance(value, dict):
        if "uri" in value and "hash" in value:
            _ref(value)
        for item in value.values():
            _references(item)
    elif isinstance(value, list):
        for item in value:
            _references(item)


def _unique(values, label):
    need(len(values) == len(set(values)), "duplicate " + label)


def _condition(value, citation):
    _date(value["examinationDate"])
    _party(value["examiner"])
    state = value["protocolState"]
    uint(state["blockNumber"])
    for key in ("blockHash", "stateRoot"):
        _hash(state[key])
    finality = value["finality"]
    if finality["finalityHash"] is not None:
        _hash(finality["finalityHash"])
        if citation["qualifier"]["kind"] == "fin":
            need(finality["finalityHash"] == citation["qualifier"]["hash"], "citation/finality hash differs")
    if finality["verifyFinality"] == "pass":
        need(finality["finalityHash"] is not None and bool(finality["evidence"]), "passing finality needs referenced hash/evidence")
    if finality["verifyFinality"] != "pass" or finality["routeMatch"] == "not_verified":
        need(finality["reason"] is not None, "finality failure/nonverification reason required")
    for route in (finality["expectedRoute"], finality["observedRoute"]):
        if route is not None:
            need(any(hex_bytes(route["renderer"], 20)), "empty renderer")
            _hash(route["routeHash"])
    if finality["routeMatch"] != "not_verified":
        need(finality["expectedRoute"] is not None and finality["observedRoute"] is not None, "route evidence missing")
        need((finality["expectedRoute"] == finality["observedRoute"]) == (finality["routeMatch"] == "match"), "route outcome contradicts routes")
    fixity = value["fixity"]
    _unique([p["objectId"] for p in fixity["payloads"]], "fixity object")
    for payload in fixity["payloads"]:
        _iri(payload["objectId"])
    if fixity["latestCycleClaimed"]:
        need(fixity["cycle"] is not None, "latest fixity cycle reference missing")
    if fixity["status"] == "covered":
        need(fixity["cycle"] is not None and fixity["latestCycleClaimed"] and fixity["coverage"] == "complete"
            and bool(fixity["payloads"]) and all(p["result"] == "pass" for p in fixity["payloads"]), "covered fixity contradicts declared coverage")
    if fixity["status"] == "not_checked":
        need(fixity["reason"] is not None and fixity["coverage"] != "complete"
            and all(p["result"] == "not_checked" for p in fixity["payloads"]), "unchecked fixity contradicts observations")
    render = value["render"]
    checked = render["outcome"] != "not_verified"
    need((render["reason"] is not None) if not checked else (render["method"] is not None and bool(render["evidence"])), "render method/evidence or nonverification reason required")
    acceptance = render["acceptance"]
    if acceptance["mode"] == "BYTE_EXACT":
        need(acceptance["rendererClass"] != "DYNAMIC" and acceptance["softwareRasterization"], "BYTE_EXACT needs deterministic software rasterization")
    elif acceptance["mode"] == "PERCEPTUAL_TOLERANCE":
        _hash(acceptance["metricId"])
        need((acceptance["observedValue"] is not None) == checked, "metric observation/verification differs")
        if checked:
            observed, threshold = Decimal(acceptance["observedValue"]), Decimal(acceptance["threshold"])
            passes = observed >= threshold if acceptance["comparison"] == "greater_than_or_equal" else observed <= threshold
            need(passes == (render["outcome"] == "pass"), "metric result contradicts threshold")
    else:
        evaluations = acceptance["evaluations"]
        _unique([p["propertyId"] for p in evaluations], "significant property")
        for evaluation in evaluations:
            _iri(evaluation["propertyId"])
            import re
            need(re.fullmatch(r"(?:/(?:[^~]|~[01])*)+", evaluation["sourcePointer"]) is not None, "significant property pointer invalid")
        if checked:
            examiner = value["examiner"]
            need(examiner["name"] is not None and examiner["institution"] is not None and bool(examiner["credentials"])
                and acceptance["attestation"] is not None and acceptance["attestationLane"] is not None
                and acceptance["evidenceClass"] == "SIGNER_VERIFIED" and bool(evaluations), "curated examiner/attestation/evaluations missing")
            if render["outcome"] == "pass":
                need(all(e["outcome"] == "equivalent" for e in evaluations), "curated pass contradicts property evaluations")
        else:
            need(not evaluations and acceptance["attestation"] is None and acceptance["attestationLane"] is None
                and acceptance["evidenceClass"] is None, "unverified curated outcome contains verification claims")
    lineage = value["recoveryLineage"]
    entries = lineage["entries"]
    need((lineage["status"] == "none") == (not entries), "explicit recovery-none contradicts entries")
    _unique([r["recoveryId"] for r in entries], "recovery identity")
    _unique([r["manifest"]["recordHash"] for r in entries], "recovery manifest")
    previous = None
    for entry in entries:
        _iri(entry["recoveryId"])
        _date(entry["executedAt"])
        for key in ("beforeContent", "afterContent"):
            _ref({"uri": entry["manifest"]["uri"], "hash": entry[key]})
        if previous is not None:
            need(previous["afterContent"] == entry["beforeContent"], "recovery content lineage disconnected")
            _ordered_dates(previous["executedAt"], entry["executedAt"])
        _ordered_dates(entry["executedAt"], value["examinationDate"])
        _unique([r["recordHash"] for r in entry["ownerResponses"]], "owner recovery response")
        previous = entry
    _unique([c["captureId"] for c in value["captures"]], "capture identity")
    for capture in value["captures"]:
        _iri(capture["captureId"])
        _hash(capture["format"]["formatId"])


def _ordered_dates(before, after):
    if all(d["calendar"] == "gregorian" and d["timezone"] == "UTC" for d in (before, after)):
        if before["earliest"] is not None and after["latest"] is not None:
            need(_instant(before["earliest"]) <= _instant(after["latest"]), "chronology reversed")


def _treatment(value):
    _date(value["eventDate"])
    ids = []
    for agent in value["agents"]:
        _party(agent["agent"])
        ids.append((agent["agent"]["entityId"], agent["role"]))
    _unique(ids, "agent-role")
    _unique([a["objectId"] for a in value["artifacts"]], "artifact identity")
    for artifact in value["artifacts"]:
        _iri(artifact["objectId"])
        if artifact["formatId"] is not None:
            _hash(artifact["formatId"])
    completed = value["status"] == "completed"
    need((value["outcome"] != "NOT_PERFORMED") == completed, "treatment status/outcome differs")
    if value["kind"] == "conservation_note":
        need(value["eventType"] == "CONSERVATION_NOTE" and value["treatmentClass"] is None
            and value["migration"] is None, "conservation note cannot assert an intervention")
    else:
        need(value["eventType"] != "CONSERVATION_NOTE", "conservation note cannot assert an intervention")
        need(value["treatmentClass"] is not None and value["method"] is not None, "treatment class/method missing")
        _iri(value["treatmentClass"])
        if completed:
            need(bool(value["evidence"]) and any(a["role"] in ("subject", "source") for a in value["artifacts"]), "performed treatment evidence/subject missing")
    migration = value["migration"]
    need((value["kind"] == "environment_migration") == (migration is not None), "migration linkage/kind differs")
    if migration is not None:
        need(value["eventType"] == "MIGRATION", "environment migration needs MIGRATION event")
        by_id = {a["objectId"]: a for a in value["artifacts"]}
        source = by_id.get(migration["sourceObjectId"])
        outcome = by_id.get(migration["outcomeObjectId"])
        need(source is not None and outcome is not None and source["objectId"] != outcome["objectId"]
            and source["role"] == "source" and outcome["role"] == "outcome", "migration source/outcome linkage differs")
        if completed:
            need(bool(migration["evidence"]), "migration boot/acceptance evidence missing")
            if value["outcome"] == "SUCCESS":
                need(migration["bootOutcome"] == "pass" and migration["acceptanceOutcome"] == "pass", "successful migration has failed/unchecked boot or acceptance")
        else:
            need(migration["bootOutcome"] == "not_checked" and migration["acceptanceOutcome"] == "not_checked", "unperformed migration claims observed outcome")


def admit_payload(payload_bytes, *, schema_bytes=None, kind="condition"):
    """Validate exact candidate bytes; return a draft row, never actual authority."""
    need(kind in ("condition", "treatment"), "unsupported payload kind")
    name = NAME if kind == "condition" else TREATMENT_NAME
    expected = SCHEMAS[name]
    need(schema_bytes is None or schema_bytes == expected, "exact complete candidate schema required")
    value = _validate(expected, payload_bytes)
    identifier = value["reportId" if kind == "condition" else "treatmentId"]
    _iri(identifier)
    need(not identifier.casefold().startswith(("urn:6529stream:account:", "eip155:")), "document account equivalence")
    citation = parse_citation(value["workCitation"], require_state=True)
    need(uint(value["tokenId"]) > 0 and value["tokenId"] == citation["tokenId"], "citation/token differs")
    _references(value)
    if kind == "condition":
        _condition(value, citation)
    else:
        _treatment(value)
    row = {"kind": kind, "value": value, "citation": citation, "payloadHash": keccak256(payload_bytes),
        "source": {"kind": "submitted_payload", "schemaId": schema_id(name), "schemaHash": keccak256(expected),
            "payloadHash": keccak256(payload_bytes), "pointer": ""},
        "authority": {"kind": "draft_unverified_submission", "authenticated": False},
        "originalPayloadHex": "0x" + payload_bytes.hex(), "registeredSchemaHex": "0x" + expected.hex(),
        "reasonCode": None}
    _identities([row])
    return row


def admit_document(payload_bytes, schema_bytes, *, kind="condition"):
    """Preserve unsupported original meanings, including same-name opaque schemas."""
    need(kind in ("condition", "treatment"), "unsupported payload kind")
    expected = SCHEMA_BYTES if kind == "condition" else TREATMENT_SCHEMA_BYTES
    if schema_bytes == expected:
        return admit_payload(payload_bytes, schema_bytes=schema_bytes, kind=kind)
    need(type(payload_bytes) is bytes and 0 < len(payload_bytes) <= 24576
        and type(schema_bytes) is bytes and 0 < len(schema_bytes) <= 524288, "unsupported document byte bound")
    return {"kind": kind, "value": None, "citation": None, "payloadHash": keccak256(payload_bytes),
        "source": {"kind": "submitted_payload", "schemaHash": keccak256(schema_bytes), "payloadHash": keccak256(payload_bytes), "pointer": ""},
        "authority": {"kind": "draft_unverified_submission", "authenticated": False},
        "originalPayloadHex": "0x" + payload_bytes.hex(), "registeredSchemaHex": "0x" + schema_bytes.hex(),
        "reasonCode": "original_registered_definition_unsupported"}


def _identities(rows):
    identities = {}
    for row in rows:
        value = row["value"]
        if value is None:
            continue
        condition = row["kind"] == "condition"
        identifier = value["reportId" if condition else "treatmentId"]
        entries = [(identifier, "LinguisticObject" if condition or value["kind"] == "conservation_note" else "Activity", value, False)]
        parties = [value["examiner"]] if condition else [a["agent"] for a in value["agents"]]
        entries.extend((p["entityId"], p["kind"], p, True) for p in parties)
        if condition:
            entries.extend((c["captureId"], "capture", c, True) for c in value["captures"])
            entries.extend((r["recoveryId"], "recovery", r, True) for r in value["recoveryLineage"]["entries"])
        else:
            entries.extend((a["objectId"], "artifact", {k: v for k, v in a.items() if k != "role"}, True) for a in value["artifacts"])
        for identifier, kind, declaration, repeat in entries:
            exact = (kind, dumps(declaration))
            need(identifier not in identities or (repeat and identities[identifier] == exact), "conflicting or reused typed identity")
            identities[identifier] = exact


def compare_conditions(outbound, returned):
    """Compare admitted statements without turning matching assertions into proof."""
    need(outbound["kind"] == returned["kind"] == "condition" and outbound["value"] is not None and returned["value"] is not None,
        "comparison needs two typed condition reports")
    left, right = outbound["value"], returned["value"]
    a, b = parse_citation(left["workCitation"], require_state=True), parse_citation(right["workCitation"], require_state=True)
    need(all(a[k] == b[k] for k in ("chainId", "core", "tokenId")), "comparison original work differs")
    _ordered_dates(left["examinationDate"], right["examinationDate"])
    differences = [{"field": key, "outbound": left[key], "returned": right[key]}
        for key in ("examinationDate", "examiner", "workCitation", "protocolState", "finality", "fixity", "render", "recoveryLineage", "captures", "narrative")
        if left[key] != right[key]]
    before, after = left["recoveryLineage"]["entries"], right["recoveryLineage"]["entries"]
    prefix = len(after) >= len(before) and before == after[:len(before)]
    lineage = "same_declared_lineage" if before == after else "declared_extension" if prefix else "inconsistent_declared_lineage"
    dates = [left["examinationDate"], right["examinationDate"]]
    exact_order = all(d["calendar"] == "gregorian" and d["timezone"] == "UTC" and d["precision"] == "exact" for d in dates)
    acceptance_same = left["render"]["acceptance"] == right["render"]["acceptance"]
    # Capture IDs identify observations, not assumed positional correspondences.
    captures = []
    right_ids = {c["captureId"]: c for c in right["captures"]}
    for c in left["captures"]:
        other = right_ids.get(c["captureId"])
        captures.append({"outbound": c, "returned": other,
            "status": "no_same_identity_return_capture" if other is None else "same_declared_capture" if c == other else "conflicting_capture_identity"})
    left_ids = {c["captureId"] for c in left["captures"]}
    captures.extend({"outbound": None, "returned": c, "status": "new_return_capture"}
        for c in right["captures"] if c["captureId"] not in left_ids)
    return {"status": "compared_attributed_statements", "outbound": outbound["source"], "returned": returned["source"],
        "originalWork": {k: a[k] for k in ("chainId", "core", "tokenId")}, "differences": differences,
        "declaredChronology": "ordered_exact_dates" if exact_order else "not_fully_ordered",
        "recoveryContinuity": lineage, "additionalRecoveryEntries": after[len(before):] if prefix else [],
        "acceptanceDeclarationUnchanged": acceptance_same, "captureCorrespondence": captures,
        "claims": {"actualSourceAuthenticated": False, "historicalTimeProven": False,
            "renderEquivalent": False, "noDamageProven": False, "lawfulRecoveryProven": False,
            "loanReferenceJoinProven": False, "completeRecoveryLineageProven": False},
        "qualification": QUALIFICATION}


def _selected(values):
    need(isinstance(values, list) and len(values) <= 64, "selection bound")
    keys = [v if isinstance(v, str) else dumps(v) for v in values]
    _unique(keys, "selected record")


def _source_subject(row, anchor, subject, token):
    if row["value"] is None:
        return
    c = row["citation"]
    need(c["chainId"] == anchor["chainId"] and c["core"] == anchor["core"]
        and c["tokenId"] == token, "original citation chain/Core/token differs")
    need(subject_id("token", c["chainId"], c["core"], "0", token_id=token) == subject,
        "original token subject differs")


def admit_owner(source, selected, *, source_hash):
    """Reconstruct original owner evidence from replay; ignore mutable cached rows.

    source_hash is the externally supplied OwnerRecordSource snapshot hash.
    The endpoint model authenticates historical recorded accounts, not consensus.
    """
    from .account_profile import JCS_BYTES
    from .chain_rpc import ReplayTransport
    from .institutional_source import InstitutionalOwnerSource
    from .owner_record_source import OwnerRecordSource
    from .independent_wire import RAW_BYTES
    _selected(selected)
    need(type(source) in (OwnerRecordSource, InstitutionalOwnerSource) and source.provenance == "trusted_rpc",
        "concrete trusted owner source required")
    source.snapshot()
    transcript = source.reader.transcript()
    frozen = type(source)(source.anchor_bytes, ReplayTransport(transcript, keccak256(transcript)), provenance="trusted_rpc")
    need(keccak256(frozen.snapshot()) == source_hash, "external original owner snapshot differs")
    jcs = schema_id("RFC8785_JCS")
    rows = []
    for h in selected:
        _hash(h)
        need(h in frozen.records, "original owner condition missing")
        saved = frozen.records[h]
        r, t = saved["record"], saved["receipt"]
        need(r[0] == schema_id("CONDITION_REPORT"), "original owner condition family differs")
        registered = frozen.documents[r[2]][1]
        row = admit_document(hex_bytes(saved["payloadHex"]), registered)
        if row["value"] is not None:
            need(r[2] == schema_id(NAME) and r[3][2] == jcs and frozen.documents[r[2]][2][3][3] == jcs
                and frozen.documents[jcs][1] == JCS_BYTES and frozen.documents[jcs][2][3][3] == RAW_BYTES,
                "original condition schema/JCS differs")
        _source_subject(row, frozen.a, r[1], t[0])
        row["source"] = {"host": frozen.a["host"], "recordHash": h, "subjectId": r[1], "schemaId": r[2],
            "schemaHash": t[9], "recordType": r[0], "owner": t[1], "recordIndex": t[3], "recordChainHash": t[4], "pointer": ""}
        row["authority"] = deepcopy(saved["authority"])
        row["sourceEvidence"] = {"snapshotHash": source_hash, "basis": "reconstructed_original_owner_receipt",
            "nativeEffectiveAt": r[6], "cryptographicStateProof": False}
        rows.append(row)
    _identities(rows)
    return rows


def admit_independent(source, selectors, *, source_hash):
    """Use hash-bound frozen records; source_hash is source.state.commitment.

    Mutable convenience maps (records, canonicalizations, positions, publication)
    are never read. Every consumed frozen record is rebound to the retained
    identity and original capture bytes before interpretation.
    """
    from .account_profile import JCS_BYTES
    from .chain_rpc import MAX_TRANSCRIPT
    from .independent_wire import RAW_BYTES
    from .recorded_semantic import RecordedSemanticSource
    from .review import _selector
    from .source import BoundSourceState, RetainedSourceRecord
    _selected(selectors)
    need(type(source) is RecordedSemanticSource, "concrete recorded independent source required")
    state = source.state
    need(type(state) is BoundSourceState and state.mode == "recorded_state" and state.commitment == source_hash,
        "external independent state commitment differs")
    identity = loads(state.identity, maximum=MAX_TRANSCRIPT, canonical=True)
    need(identity["mode"] == "recorded_state", "original independent state mode differs")
    for key, raw in (("sourceCaptureHash", source.capture_bytes), ("publicationHash", source.publication_bytes),
            ("interpretationHash", source.interpretation_bytes)):
        need(keccak256(raw) == identity[key], "original independent evidence bytes differ")
    anchor = dict(source.anchor)
    need(keccak256(dumps(anchor)) == identity["anchorHash"], "original independent anchor differs")
    capture = loads(source.capture_bytes, maximum=MAX_TRANSCRIPT, canonical=True)
    originals = {r["recordHash"]: r for r in capture["records"]}
    documents = {d["documentId"]: d for d in capture["documents"]}
    summaries = [{"selector": r.selector.__dict__, "payloadHash": r.payload_hash,
        "authorityEvidenceHash": keccak256(r.authority_evidence), "disclosure": r.disclosure} for r in state.records]
    need(summaries == identity["records"] and all(type(r) is RetainedSourceRecord for r in state.records),
        "frozen independent records differ from identity")
    frozen = {r.selector.record_hash: r for r in state.records}
    jcs = schema_id("RFC8785_JCS")
    rows = []
    for selector in selectors:
        need(isinstance(selector, dict) and selector.get("pointer") == "", "whole original independent record required")
        record = frozen.get(selector.get("recordHash"))
        need(record is not None and selector == _selector(record, "") and record.disclosure == "public"
            and record.selector.authorization_class == "INDEPENDENT_ATTESTOR", "original independent selector differs")
        h = record.selector.record_hash
        original = originals[h]
        generic = original["record"]
        kind = {schema_id("INDEPENDENT_CONDITION"): "condition", schema_id("INDEPENDENT_CONSERVATION_TREATMENT"): "treatment"}.get(generic[0])
        need(kind is not None and record.selector.record_type == generic[0], "independent condition/treatment family differs")
        document = documents[generic[4]]
        raw_schema = hex_bytes(document["payloadHex"])
        need(record.payload == hex_bytes(original["payloadHex"]) and keccak256(record.payload) == record.payload_hash == generic[2][1]
            and record.schema == raw_schema and record.selector.schema_id == generic[4]
            and record.selector.schema_hash == keccak256(raw_schema), "original independent payload/schema differs")
        row = admit_document(record.payload, raw_schema, kind=kind)
        if row["value"] is not None:
            name = NAME if kind == "condition" else TREATMENT_NAME
            need(generic[4] == schema_id(name) and generic[2][2] == jcs and document["view"][3][3] == jcs
                and hex_bytes(documents[jcs]["payloadHex"]) == JCS_BYTES and documents[jcs]["view"][3][3] == RAW_BYTES,
                "original independent condition schema/JCS differs")
            need(original["subject"][0] == "1", "condition original token subject required")
            _source_subject(row, anchor, generic[1], row["value"]["tokenId"])
        row["source"] = deepcopy(selector)
        row["authority"] = loads(record.authority_evidence, canonical=True)
        row["sourceEvidence"] = {"stateCommitment": source_hash, "basis": "hash_bound_original_independent_capture",
            "nativeEffectiveAt": generic[7], "cryptographicStateProof": False}
        rows.append(row)
    _identities(rows)
    return rows


def project_owner_conditions(source, selected, *, source_hash, profile_hash, model=None):
    need(profile_hash == PROFILE_HASH, "external condition profile differs")
    rows = admit_owner(source, selected, source_hash=source_hash)
    return _recorded_render(rows, model, source_hash, "recorded_owner_condition_projection")


def project_independent_conditions(source, selectors, *, source_hash, profile_hash, model=None):
    need(profile_hash == PROFILE_HASH, "external condition profile differs")
    rows = admit_independent(source, selectors, source_hash=source_hash)
    return _recorded_render(rows, model, source_hash, "recorded_independent_condition_conservation_projection")


def _recorded_render(rows, model, source_hash, mode):
    files = render(rows, model)
    report = loads(files["condition/report.json"], maximum=524288)
    report.update(mode=mode, sourceHash=source_hash, sourceReceiptEvidenceChecked=True)
    report["claims"]["actualSourceAuthenticated"] = True
    # Only original account publication is established; every condition/treatment
    # factual and examiner-identity claim remains false.
    files["condition/report.json"] = dumps(report)
    return files


def render(rows, model=None, *, comparisons=None):
    """Pure serialization; caller-supplied source/authority are retained, not vouched."""
    need(isinstance(rows, list) and len(rows) <= 64, "row bound")
    _identities(rows)
    files, index, dossiers, coverage, provenance, roles, dispositions = {}, [], [], [], [], [], []

    def emit(resource, row, source_paths):
        raw = dumps(resource)
        key = keccak256(resource["id"].encode())[2:]
        path = "condition/resources/" + key + ".json"
        if path in files:
            need(files[path] == raw, "conflicting resource output")
        else:
            files[path] = raw
            index.append({"id": resource["id"], "type": resource["type"], "path": path})
            if model is not None:
                files["condition/expanded/" + key + ".json"] = model.validate_and_expand(raw).expanded_bytes
        provenance.extend({"entity": resource["id"], "path": p, "value": v, "source": row["source"],
            "sourcePaths": source_paths, "authority": row["authority"], "qualification": QUALIFICATION}
            for p, v in fields(resource))

    for row in rows:
        v = row["value"]
        dossiers.append(deepcopy(row) | {"qualification": QUALIFICATION})
        if v is None:
            dispositions.append({"source": row["source"], "status": "unsupported", "reasonCode": row["reasonCode"]})
            continue
        coverage.extend({"source": row["source"], "sourcePath": p, "value": x,
            "disposition": "retained_with_source"} for p, x in fields(v))
        is_condition = row["kind"] == "condition"
        identifier = v["reportId" if is_condition else "treatmentId"]
        kind = "LinguisticObject" if is_condition or v["kind"] == "conservation_note" else "Activity"
        performed = is_condition or v["kind"] == "conservation_note" or v["status"] == "completed"
        if performed:
            resource = {"@context": CONTEXT, "id": identifier, "type": kind, "_label": identifier,
                "referred_to_by": [{"type": "LinguisticObject", "content": QUALIFICATION}]}
            if kind == "LinguisticObject":
                resource["content"] = v["narrative" if is_condition else "description"]
            else:
                resource["referred_to_by"].append({"type": "LinguisticObject", "content": v["description"]})
            emit(resource, row, ["/reportId", "/narrative"] if is_condition else ["/treatmentId", "/kind", "/status", "/description"])
        parties = [("examiner", v["examiner"])] if is_condition else [(a["role"], a["agent"]) for a in v["agents"]]
        for role, party in parties:
            roles.append({"document": identifier, "role": role, "party": party, "source": row["source"],
                "authority": row["authority"], "namedIdentityProven": False, "independenceProven": False})
            if party["name"] is not None:
                emit({"@context": CONTEXT, "id": party["entityId"], "type": party["kind"], "_label": party["name"]["value"],
                    "identified_by": [{"type": "Name", "content": party["name"]["value"]}]}, row,
                    ["/examiner"] if is_condition else ["/agents"])
        selected_joins = ("protocolState", "finality", "fixity", "render", "recovery", "captures", "examiner") if is_condition else ("treatment", "examiner")
        dispositions.append({"source": row["source"], "status": "typed_attributed_dossier", "reasonCode": None,
            "performedInterventionProjected": not is_condition and v["kind"] != "conservation_note" and performed,
            "joins": [{"field": key, "status": "unproven", "reasonCode": JOIN_REASONS[key]} for key in selected_joins]})
    result = {"index": {"resources": sorted(index, key=lambda item: item["id"])}, "dossiers": dossiers,
        "coverage": coverage, "provenance": provenance, "named-roles": roles,
        "comparisons": [] if comparisons is None else comparisons,
        "report": {"mode": MODE, "version": "1", "profileHash": PROFILE_HASH,
            "status": "unsupported" if not rows or all(r["value"] is None for r in rows) else "typed_dossiers_with_unproven_joins",
            "reasonCode": "no_selected_condition_or_treatment" if not rows else None,
            "dispositions": dispositions, "claims": CLAIMS, "qualification": QUALIFICATION,
            "linkedArtValidation": "not_evaluated" if model is None else "validated_emitted_resources"}}
    files.update({"condition/" + name + ".json": dumps(value) for name, value in result.items()})
    return files


def main():
    import argparse
    from pathlib import Path
    parser = argparse.ArgumentParser(description="Generate/check prospective condition definitions; no registration.")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2] / "schemas/museum/condition"
    for name, raw in list(SCHEMAS.items()) + [("profile", PROFILE_BYTES)]:
        path = root / (name + ".json")
        if args.check:
            need(path.is_file() and path.read_bytes() == raw, "generated definition differs")
        else:
            root.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
    print(PROFILE_HASH)


if __name__ == "__main__":
    main()
