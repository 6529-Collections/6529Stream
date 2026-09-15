"""Typed, recorded FIXITY_CHECK projection; no event is inferred from a digest."""
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from hashlib import sha256

from lxml import etree

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .premis import NS, _element, _xml
from .recorded_premis import project_recorded_premis
from .recorded_semantic import JCS_ID, RecordedSemanticSource
from .review import _validate
from .schemas import ADDRESS, HEX32, IRI, TEXT, UINT, definitions, enum, obj

MODE = "recorded_account_premis_fixity_projection"
PREFIX = "STREAM_MUSEUM_PREMIS_FIXITY_"
EVENT_NAME, REPORT_NAME, AGENT_NAME = (PREFIX + suffix + "_V1" for suffix in ("EVENT", "REPORT", "AGENT"))
FAMILIES = {EVENT_NAME: schema_id("INDEPENDENT_PRESERVATION_EVENT"),
    REPORT_NAME: schema_id("INDEPENDENT_FIXITY"), AGENT_NAME: schema_id("INDEPENDENT_SEMANTIC_ASSERTION")}
FIXITY_CHECK, SHA256 = schema_id("FIXITY_CHECK"), schema_id("SHA256")
SUCCESS, FAILED = schema_id("SUCCESS"), schema_id("FAILED")
ZERO = "0x" + "00" * 32
MAX_EVENTS, MAX_OBSERVATION_BYTES = 128, 32 * 1024 * 1024
U64 = dict(UINT, maxLength=20, **{"x-stream-unsigned-bits": 64})
OPTIONAL_IRI = {"anyOf": [IRI, enum("")]}


def schema_documents():
    event = obj({"eventId": HEX32, "eventType": HEX32, "outcome": HEX32, "eventURI": IRI,
        "eventHash": HEX32, "eventTime": U64, "schemaId": HEX32})
    agent = obj({"agentId": HEX32, "agentRole": HEX32, "account": ADDRESS, "did": OPTIONAL_IRI,
        "uri": IRI, "agentHash": HEX32})
    check = obj({"objectId": HEX32, "algorithm": HEX32, "digest": HEX32, "byteSize": UINT,
        "checkedAt": U64, "outcome": HEX32, "agentId": HEX32, "reportURI": IRI, "reportHash": HEX32})
    schemas = {
        EVENT_NAME: obj({"version": enum("1"), "event": event, "agent": agent, "check": check,
            "object": IRI, "report": definitions()["selector"], "agentDocument": definitions()["selector"]}),
        REPORT_NAME: obj({"version": enum("1"), "eventId": HEX32, "objectId": HEX32,
            "agentId": HEX32, "checkedAt": U64, "algorithm": HEX32, "expectedDigest": HEX32,
            "observedDigest": HEX32, "expectedByteSize": UINT, "observedByteSize": UINT,
            "outcome": HEX32, "performed": enum(True), "detail": TEXT}),
        AGENT_NAME: obj({"version": enum("1"), "agentId": HEX32, "name": dict(TEXT, minLength=1),
            "type": enum("person", "organization", "software"), "agentVersion": TEXT})}
    return {name: dumps(value | {"$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "urn:6529stream:schema:" + name,
        "x-stream-document-status": "prospective_schema_requires_actual_registration"}) for name, value in schemas.items()}


SCHEMAS = schema_documents()
PROFILE_BYTES = dumps({"id": PREFIX + "RECORDED_EXPORT_V1", "version": "1",
    "status": "prospective_unregistered_export_profile", "mode": MODE,
    "source": "Exact public RecordedSemanticSource with explicitly selected whole typed event records; registered JCS schemas and original independent-account publication evidence.",
    "sourceSchemas": {name: keccak256(raw) for name, raw in SCHEMAS.items()},
    "recordTypes": FAMILIES,
    "eventKinds": {FIXITY_CHECK: "fixity check"}, "outcomes": {SUCCESS: "success", FAILED: "fail"},
    "algorithm": {SHA256: "SHA-256"},
    "evidence": "Event and performed report share original reporter and subject; report and agent document precede event. Exact hashes and selectors are mandatory. Agent identity is the recorded claim, never the reporter by inference.",
    "fileJoin": "Event object IRI joins an unchanged selected PREMIS file. Expected size/digest equal its declared file facts; supplied observation bytes match the report's observed size/digest.",
    "identifiers": "Event/agent bytes32 become urn:6529stream:preservation:{event,agent}:0x...; original objectId remains in complete evidence and correspondence. Linking agent role is its original bytes32 URN; no role vocabulary is guessed.",
    "timestamp": "Original uint64 Unix seconds rendered in UTC where XML date range permits. Not publication time, export time, or an independently established historical time.",
    "claims": "Account-reported performed checks plus a current offline byte comparison; not proof of historical execution, named-agent identity, independent review, detected format, consensus finality or institutional conformance.",
    "limits": {"events": str(MAX_EVENTS), "observationBytes": str(MAX_OBSERVATION_BYTES)},
    "remaining": ["other event kinds and outcomes", "rights", "canonical PreservationObjectRef", "institutional conformance"]})
PROFILE_HASH = keccak256(PROFILE_BYTES)


@dataclass(frozen=True)
class FixityProjection:
    xml: bytes | None
    report: bytes
    correspondence: bytes
    provenance: bytes


def _need(condition, message):
    if not condition:
        raise MuseumError("recorded fixity " + message)


def _xml_text(value):
    _need(all(ord(c) in (9, 10, 13) or 32 <= ord(c) <= 0xD7FF
        or 0xE000 <= ord(c) <= 0xFFFD or 0x10000 <= ord(c) <= 0x10FFFF for c in value),
        "text cannot be represented in XML 1.0 without changing source bytes")


def _read(source, selector, name):
    record = source.record(selector)
    _need(selector["pointer"] == "", "requires whole typed records")
    _need(record.disclosure == "public" and record.schema == SCHEMAS[name]
        and record.selector.schema_id == schema_id(name) and record.selector.record_type == FAMILIES[name]
        and source.canonicalizations[record.selector.record_hash] == JCS_ID,
        "original registered schema/family/canonicalization mismatch")
    return record, _validate(record.schema, record.payload)


def _admit(source, selectors):
    """Internal source-join core. Public entry point admits the concrete recorded adapter first."""
    rows = []
    for selector in selectors:
        record, value = _read(source, selector, EVENT_NAME)
        report_record, report = _read(source, value["report"], REPORT_NAME)
        agent_record, description = _read(source, value["agentDocument"], AGENT_NAME)
        event, agent, check = (value[key] for key in ("event", "agent", "check"))
        for original in (report_record, agent_record):
            _need(source.positions[original.selector.record_hash] < source.positions[record.selector.record_hash],
                "evidence must precede event publication")
            _need(original.selector.subject_id == record.selector.subject_id, "evidence subject differs")
        _need(report_record.selector.recorder == record.selector.recorder, "performed report has a different reporter")
        _need(event["schemaId"] == schema_id(REPORT_NAME), "event report schema differs")
        _need(event["eventHash"] == check["reportHash"] == report_record.payload_hash, "report hash differs")
        _need(agent["agentHash"] == agent_record.payload_hash, "agent document hash differs")
        _need(event["eventURI"] == check["reportURI"], "report URI differs")
        _need(event["eventId"] == report["eventId"] != ZERO and check["objectId"] == report["objectId"] != ZERO,
            "event/object identifiers differ or are zero")
        _need(agent["agentId"] == check["agentId"] == report["agentId"] == description["agentId"] != ZERO,
            "agent identifiers differ or are zero")
        _need(event["eventTime"] == check["checkedAt"] == report["checkedAt"], "recorded check times differ")
        _need(event["outcome"] == check["outcome"] == report["outcome"], "outcomes differ")
        _need(check["algorithm"] == report["algorithm"], "algorithms differ")
        # FixityCheckRef.digest/byteSize are the recorded observation. The report
        # explicitly retains the separate expected values, including failed checks.
        _need(check["digest"] == report["observedDigest"] and check["byteSize"] == report["observedByteSize"],
            "check observation differs from report")
        uint(event["eventTime"], 64)
        for key in ("expectedByteSize", "observedByteSize"): uint(report[key])
        if description["type"] != "software":
            _need(description["agentVersion"] == "", "nonsoftware agent version is not admitted")
        _need(not agent["did"] or agent["did"].startswith("did:"), "agent DID must be explicit")
        rows.append({"selector": selector, "value": value, "report": report, "description": description,
            "records": (record, report_record, agent_record)})
    _need(len({r["value"]["event"]["eventId"] for r in rows}) == len(rows), "duplicate event identifier")
    return rows


def _render(base_xml, rows, observations, schema):
    """Pure projection after source admission; tests of this function are synthetic controls."""
    root = _xml(base_xml) if base_xml is not None else None
    objects = {} if root is None else {node.findtext("{" + NS + "}objectIdentifier/{" + NS + "}objectIdentifierValue"): node
        for node in root.findall("{" + NS + "}object")}
    issues, correspondence, provenance, agents = [], [], [], {}
    if not rows: issues.append({"reasonCode": "no_selected_performed_check_events"})
    needed = {r["value"]["event"]["eventId"] for r in rows}
    _need(set(observations).issubset(needed), "unselected observation supplied")
    for row in sorted(rows, key=lambda r: r["value"]["event"]["eventId"]):
        value, report, description = row["value"], row["report"], row["description"]
        event, agent, check = (value[k] for k in ("event", "agent", "check"))
        event_id, agent_id = event["eventId"], agent["agentId"]
        event_iri, agent_iri = ("urn:6529stream:preservation:" + kind + ":" + key
            for kind, key in (("event", event_id), ("agent", agent_id)))
        for text in (agent["did"], agent["uri"], description["name"], description["agentVersion"]): _xml_text(text)
        prior = agents.setdefault(agent_id, (agent, description))
        _need(prior == (agent, description), "conflicting selected agent descriptions")
        reason = lambda code: issues.append({"eventId": event_id, "reasonCode": code})
        if event["eventType"] != FIXITY_CHECK: reason("unsupported_event_type")
        if event["outcome"] not in (SUCCESS, FAILED): reason("unsupported_check_outcome")
        if check["algorithm"] != SHA256: reason("unsupported_check_algorithm")
        if uint(event["eventTime"], 64) > 253402300799: reason("timestamp_outside_xml_profile")
        node = objects.get(value["object"])
        if node is None:
            reason("selected_file_projection_unavailable")
        else:
            chars = node.find("{" + NS + "}objectCharacteristics")
            digest = chars.findtext("{" + NS + "}fixity/{" + NS + "}messageDigest")
            size = chars.findtext("{" + NS + "}size")
            _need(report["expectedDigest"] == "0x" + digest and report["expectedByteSize"] == size,
                "report expectation differs from selected file facts")
        observed = observations.get(event_id)
        if observed is None:
            reason("observation_bytes_missing")
        elif check["algorithm"] == SHA256:
            _need(sha256(observed).digest() == hex_bytes(report["observedDigest"], 32)
                and len(observed) == uint(report["observedByteSize"]), "supplied observation differs from performed report")
        equal = (report["expectedDigest"] == report["observedDigest"]
            and report["expectedByteSize"] == report["observedByteSize"])
        if event["outcome"] in (SUCCESS, FAILED):
            _need((event["outcome"] == SUCCESS) == equal, "outcome contradicts recorded comparison")
        correspondence.append({"eventId": event_id, "eventIdentifier": event_iri, "objectId": check["objectId"],
            "objectIdentifier": value["object"], "agentId": agent_id, "agentIdentifier": agent_iri,
            "eventTime": event["eventTime"], "source": row["selector"]})
        provenance.append({"eventId": event_id, "typedEvent": value, "performedReport": report,
            "agentDescription": description, "sourceRecords": [{"recordHash": r.selector.record_hash,
                "payloadHash": r.payload_hash, "authority": loads(r.authority_evidence)} for r in row["records"]]})
    if issues:
        return None, issues, correspondence, provenance
    for row, mapping in zip(sorted(rows, key=lambda r: r["value"]["event"]["eventId"]), correspondence):
        value, report = row["value"], row["report"]
        event, agent = value["event"], value["agent"]
        node = _element(root, "event")
        identifier = _element(node, "eventIdentifier")
        _element(identifier, "eventIdentifierType", "URI")
        _element(identifier, "eventIdentifierValue", mapping["eventIdentifier"])
        _element(node, "eventType", "fixity check")
        instant = datetime(1970, 1, 1, tzinfo=timezone.utc) + timedelta(seconds=uint(event["eventTime"], 64))
        _element(node, "eventDateTime", instant.isoformat().replace("+00:00", "Z"))
        detail = _element(node, "eventDetailInformation")
        _element(detail, "eventDetail", dumps({"reportURI": event["eventURI"], "reportHash": event["eventHash"],
            "algorithm": "SHA-256", "recordedReport": report,
            "qualification": "Account-reported historical check; supplied observation compared offline during export."}).decode())
        outcome = _element(node, "eventOutcomeInformation")
        _element(outcome, "eventOutcome", "success" if event["outcome"] == SUCCESS else "fail")
        link = _element(node, "linkingAgentIdentifier")
        _element(link, "linkingAgentIdentifierType", "URI")
        _element(link, "linkingAgentIdentifierValue", mapping["agentIdentifier"])
        _element(link, "linkingAgentRole", "urn:6529stream:preservation:role:" + agent["agentRole"])
        link = _element(node, "linkingObjectIdentifier")
        _element(link, "linkingObjectIdentifierType", "URI")
        _element(link, "linkingObjectIdentifierValue", value["object"])
    for agent_id, (agent, description) in sorted(agents.items()):
        node = _element(root, "agent")
        identifiers = [("URI", "urn:6529stream:preservation:agent:" + agent_id)]
        if agent["account"] != "0x" + "00" * 20: identifiers.append(("Ethereum address", agent["account"]))
        if agent["did"]: identifiers.append(("DID", agent["did"]))
        identifiers.append(("URI", agent["uri"]))
        for kind, value in identifiers:
            identifier = _element(node, "agentIdentifier")
            _element(identifier, "agentIdentifierType", kind)
            _element(identifier, "agentIdentifierValue", value)
        _element(node, "agentName", description["name"])
        _element(node, "agentType", description["type"])
        if description["agentVersion"]: _element(node, "agentVersion", description["agentVersion"])
        _element(node, "agentNote", "Recorded description; named identity and historical execution are not independently established.")
    raw = etree.tostring(root, encoding="UTF-8", xml_declaration=True)
    schema.validate(raw)
    return raw, [], correspondence, provenance


def project_recorded_fixity(source, selection_bytes, plan_bytes, premis_plan_bytes, fixity_plan_bytes, *,
        selection_hash, plan_hash, premis_plan_hash, premis_profile_hash, fixity_plan_hash,
        fixity_profile_hash, premis_schema, observations):
    _need(type(source) is RecordedSemanticSource and source.state.mode == "recorded_state",
        "requires the verified recorded account source")
    _need(all(r.disclosure == "public" for r in source.state.records), "restricted source unsupported")
    _need(fixity_profile_hash == PROFILE_HASH and keccak256(fixity_plan_bytes) == fixity_plan_hash, "plan/profile hash mismatch")
    plan = loads(fixity_plan_bytes, maximum=524288, canonical=True)
    _need(isinstance(plan, dict) and set(plan) == {"mode", "version", "sourceStateHash", "profileHash",
        "premisPlanHash", "fixityProfileHash", "events"} and plan["mode"] == MODE and plan["version"] == "1"
        and plan["sourceStateHash"] == source.state.commitment and plan["profileHash"] == source.profile_hash
        and plan["premisPlanHash"] == premis_plan_hash and plan["fixityProfileHash"] == PROFILE_HASH, "plan scope mismatch")
    _need(isinstance(plan["events"], list) and len(plan["events"]) <= MAX_EVENTS
        and len({dumps(v) for v in plan["events"]}) == len(plan["events"]), "event selection invalid")
    _need(isinstance(observations, dict) and len(observations) <= MAX_EVENTS
        and all(type(v) is bytes for v in observations.values())
        and sum(map(len, observations.values())) <= MAX_OBSERVATION_BYTES, "observation bound/type")
    rows = _admit(source, plan["events"])
    base = project_recorded_premis(source, selection_bytes, plan_bytes, premis_plan_bytes,
        selection_hash=selection_hash, plan_hash=plan_hash, premis_plan_hash=premis_plan_hash,
        premis_profile_hash=premis_profile_hash, premis_schema=premis_schema)
    xml, issues, correspondence, provenance = _render(None if base.projection is None else base.projection.xml,
        rows, observations, premis_schema)
    base_report = loads(base.report, maximum=67108864)
    if base.projection is None:
        issues.insert(0, {"reasonCode": "file_profile_unsupported", "fileReport": base_report})
        xml = None
    report = dumps({"mode": MODE, "version": "1", "status": "supported" if xml else "unsupported",
        "reasonCode": None if xml else "incomplete_or_unsupported_performed_check_evidence", "issues": issues,
        "sourceStateHash": source.state.commitment, "sourceEvidence": base_report["sourceEvidence"],
        "fixityPlanHash": fixity_plan_hash, "fixityProfileHash": PROFILE_HASH, "fileReportHash": keccak256(base.report),
        "xmlHash": None if xml is None else keccak256(xml), "events": str(len(rows)),
        "claims": {"suppliedBytesMatchRecordedObservations": xml is not None, "historicalPerformanceProven": False,
            "historicalTimestampProven": False, "namedAgentIdentityProven": False, "independentReviewProven": False,
            "fullPremisCrosswalk": False, "institutionalConformance": False}})
    return FixityProjection(xml, report, dumps(correspondence), dumps(provenance))
