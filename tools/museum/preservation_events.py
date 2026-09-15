"""Recorded preservation event vocabulary and multi-agent/object PREMIS export.

Complete historical events remain account claims. Non-completed intentions stay
explicit source records; they never become performed PREMIS events.
"""
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from lxml import etree

from .canonical import MuseumError, dumps, keccak256, loads, schema_id, uint
from .premis import NS, _element, _xml
from .recorded_fixity import (AGENT_NAME, EVENT_NAME as FIXITY_NAME, FAMILIES as FIXITY_FAMILIES,
    SCHEMAS as FIXITY_SCHEMAS, MAX_EVENTS, MAX_OBSERVATION_BYTES, _admit as admit_fixity,
    _render as render_fixity, _xml_text)
from .recorded_premis import project_recorded_premis
from .recorded_semantic import JCS_ID, RecordedSemanticSource
from .review import _validate
from .schemas import HEX32, IRI, TEXT, UINT, arr, definitions, enum, obj

MODE = "recorded_account_preservation_events_projection"
EVENT_NAME = "STREAM_MUSEUM_PRESERVATION_EVENT_V1"
REPORT_NAME = "STREAM_MUSEUM_PRESERVATION_REPORT_V1"
ZERO = "0x" + "00" * 32
TYPE_LABELS = {"INGEST": "ingestion", "FIXITY_CHECK": "fixity check", "REPLICATION": "replication",
    "MIGRATION": "migration", "NORMALIZATION": "normalization", "VALIDATION": "validation",
    "MEDIA_DERIVATION": "creation", "C2PA_VALIDATION": "digital signature validation",
    "SCHEMA_MIGRATION": "metadata modification", "RIGHTS_REVIEW": "policy assignment",
    "REDACTION": "redaction", "DEACCESSION_REFERENCE": "deaccession", "CONSERVATION_NOTE": "conservation note"}
OUTCOME_LABELS = {"SUCCESS": "success", "WARNING": "warning", "FAILED": "fail", "INCONCLUSIVE": "inconclusive",
    "SUPERSEDED": "superseded", "REDACTED": "redacted"}
TYPES = {schema_id(key): value for key, value in TYPE_LABELS.items()}
OUTCOMES = {schema_id(key): value for key, value in OUTCOME_LABELS.items()}
LOCAL_OUTCOMES = {schema_id(key) for key in ("INCONCLUSIVE", "SUPERSEDED", "REDACTED")}
FAMILIES = {EVENT_NAME: schema_id("INDEPENDENT_PRESERVATION_EVENT"),
    REPORT_NAME: schema_id("INDEPENDENT_PRESERVATION_EVENT"), AGENT_NAME: FIXITY_FAMILIES[AGENT_NAME]}


def documents():
    original = loads(FIXITY_SCHEMAS[FIXITY_NAME], maximum=524288)
    schemas = {
        EVENT_NAME: obj({"version": enum("1"), "event": original["properties"]["event"],
            "objects": arr(obj({"objectId": HEX32, "identifier": IRI, "role": HEX32}), 1, 32),
            "agents": arr(obj({"agent": original["properties"]["agent"], "document": definitions()["selector"]}), 1, 32),
            "report": definitions()["selector"]}),
        REPORT_NAME: obj({"version": enum("1"), "eventId": HEX32, "eventType": HEX32, "outcome": HEX32,
            "eventTime": dict(UINT, maxLength=20, **{"x-stream-unsigned-bits": 64}),
            "status": enum("planned", "completed", "cancelled", "unknown"), "objectIds": arr(HEX32, 1, 32),
            "agentIds": arr(HEX32, 1, 32), "detail": TEXT, "outcomeDetail": TEXT,
            "results": arr(obj({"purpose": TEXT, "uri": IRI, "contentHash": HEX32,
                "record": definitions()["selector"]}), 0, 32)})}
    return {name: dumps(value | {"$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "urn:6529stream:schema:" + name,
        "x-stream-document-status": "prospective_schema_requires_actual_registration"}) for name, value in schemas.items()}


SCHEMAS = documents() | {AGENT_NAME: FIXITY_SCHEMAS[AGENT_NAME]}
PROFILE_BYTES = dumps({"id": "STREAM_MUSEUM_RECORDED_PRESERVATION_EVENTS_V1", "version": "1", "mode": MODE,
    "status": "prospective_unregistered_export_profile", "sourceSchemas": {k: keccak256(v) for k, v in SCHEMAS.items()},
    "sourceFamilies": FAMILIES, "eventTypes": TYPES, "outcomes": OUTCOMES,
    "localTerms": {schema_id("CONSERVATION_NOTE"): {"label": "conservation note", "scope": "A recorded conservation note, not an inferred treatment."},
        **{key: {"label": OUTCOMES[key], "requiresOutcomeDetail": True} for key in sorted(LOCAL_OUTCOMES)}},
    "vocabularyAuthority": "Exact CMC-PREMIS-PROFILE labels. Local terms remain distinct; no unverified external term URI or equivalence is asserted.",
    "fixity": "FIXITY_CHECK uses only the unchanged typed recorded-fixity schema/validator with exact local observation bytes, never a generic report.",
    "statusSemantics": "Only explicitly completed source reports become PREMIS events. Planned/cancelled/unknown remain complete non-completed source records with a per-event disposition; they are not performed activities.",
    "source": "Exact public RecordedSemanticSource selectors and registered schemas/JCS; prior same-reporter report and result bytes, separate named-agent evidence; explicit source-state-bound selection.",
    "objects": "Original selected supplemental PREMIS file IRIs with explicit recorded object IDs/roles. No canonical PreservationObjectRef or ownership inference.",
    "results": "Every completed generic report needs prior hash-bound result evidence. Result content is retained; C2PA/validation/policy outcomes remain reporter claims, not tool reexecution or rights grants.",
    "agents": "Complete original AgentRef and prior exact description; roles belong to event links, identity descriptions cannot conflict under one ID.",
    "claims": "No historical execution/time/identity/independent-review/rights/finality/institutional claim. Export schema validity is separate.",
    "limits": {"events": str(MAX_EVENTS), "objectsPerEvent": "32", "agentsPerEvent": "32", "resultsPerEvent": "32"}})
PROFILE_HASH = keccak256(PROFILE_BYTES)


@dataclass(frozen=True)
class PreservationProjection:
    xml: bytes | None
    report: bytes
    correspondence: bytes
    provenance: bytes


def need(condition, message):
    if not condition: raise MuseumError("recorded preservation " + message)


def read(source, selector, name):
    record = source.record(selector)
    need(selector["pointer"] == "" and record.disclosure == "public", "public whole record required")
    need(record.schema == SCHEMAS[name] and record.selector.schema_id == schema_id(name)
        and record.selector.record_type == FAMILIES[name]
        and source.canonicalizations[record.selector.record_hash] == JCS_ID, "registered schema/family/canonicalization differs")
    return record, _validate(record.schema, record.payload)


def admit(source, selectors):
    """Private pure-source core; concrete recorded authority is checked at the public boundary."""
    rows = []
    for selector in selectors:
        event_record, body = read(source, selector, EVENT_NAME)
        report_record, report = read(source, body["report"], REPORT_NAME)
        event = body["event"]
        need(event["eventId"] != ZERO and event["eventType"] != schema_id("FIXITY_CHECK"),
            "fixity needs its original performed-check schema; event ID must be nonzero")
        need(event["eventHash"] == report_record.payload_hash and event["schemaId"] == schema_id(REPORT_NAME), "report reference differs")
        for key in ("eventId", "eventType", "eventTime", "outcome"):
            need(event[key] == report[key], "report " + key + " differs")
        need(report_record.selector.recorder == event_record.selector.recorder
            and report_record.selector.subject_id == event_record.selector.subject_id
            and source.positions[report_record.selector.record_hash] < source.positions[event_record.selector.record_hash],
            "report reporter/subject/prior publication differs")
        object_ids = [v["objectId"] for v in body["objects"]]
        agent_ids = [v["agent"]["agentId"] for v in body["agents"]]
        need(object_ids == report["objectIds"] and len(set(object_ids)) == len(object_ids) and ZERO not in object_ids,
            "object identities differ, repeat or are zero")
        need(agent_ids == report["agentIds"] and len(set(agent_ids)) == len(agent_ids) and ZERO not in agent_ids,
            "agent identities differ, repeat or are zero")
        need(len({v["identifier"] for v in body["objects"]}) == len(body["objects"]), "duplicate object IRI")
        uint(event["eventTime"], 64)
        records, agents = [event_record, report_record], []
        for value in body["agents"]:
            agent_record, description = read(source, value["document"], AGENT_NAME)
            agent = value["agent"]
            need(agent["agentHash"] == agent_record.payload_hash and agent["agentId"] == description["agentId"], "agent reference differs")
            need(source.positions[agent_record.selector.record_hash] < source.positions[event_record.selector.record_hash]
                and agent_record.selector.subject_id == event_record.selector.subject_id, "agent subject/prior publication differs")
            need(not agent["did"] or agent["did"].startswith("did:"), "agent DID differs")
            need(description["type"] == "software" or description["agentVersion"] == "", "nonsoftware version unsupported")
            for text in (agent["did"], agent["uri"], description["name"], description["agentVersion"]): _xml_text(text)
            agents.append((agent, description)); records.append(agent_record)
        result_hashes = set()
        for result in report["results"]:
            retained = source.record(result["record"])
            need(result["record"]["pointer"] == "" and retained.disclosure == "public"
                and result["contentHash"] == retained.payload_hash, "result whole payload differs")
            need(retained.selector.recorder == report_record.selector.recorder
                and retained.selector.subject_id == event_record.selector.subject_id
                and source.positions[retained.selector.record_hash] < source.positions[report_record.selector.record_hash],
                "result reporter/subject/prior publication differs")
            need(retained.selector.record_hash not in result_hashes, "duplicate result record")
            result_hashes.add(retained.selector.record_hash); records.append(retained)
        rows.append({"selector": selector, "body": body, "report": report, "agents": agents, "records": records})
    return rows


def _identifier(node, prefix, value):
    ident = _element(node, prefix)
    _element(ident, prefix + "Type", "URI")
    _element(ident, prefix + "Value", value)
    return ident


def _agent_key(agent, description):
    return ({k: v for k, v in agent.items() if k != "agentRole"}, description)


def render(base_xml, generic, fixity, observations, schema):
    issues, dispositions, correspondence, provenance = [], [], [], []
    root = _xml(base_xml) if base_xml else None
    selected = {node.findtext("{" + NS + "}objectIdentifier/{" + NS + "}objectIdentifierValue")
        for node in root.findall("{" + NS + "}object")} if root is not None else set()
    identities, agents, generic_events, fixed_events, fixed_agents = {}, {}, [], [], {}
    all_ids = [r["body"]["event"]["eventId"] for r in generic] + [r["value"]["event"]["eventId"] for r in fixity]
    need(len(all_ids) == len(set(all_ids)), "duplicate event identifier")
    if not all_ids: issues.append({"reasonCode": "no_selected_preservation_events"})
    if fixity:
        fixed_xml, fixed_issues, fixed_map, fixed_provenance = render_fixity(base_xml, fixity, observations, schema)
        issues.extend(fixed_issues); correspondence.extend(fixed_map); provenance.extend(fixed_provenance)
        if fixed_xml:
            fixed_root = _xml(fixed_xml)
            fixed_events = fixed_root.findall("{" + NS + "}event")
            for node in fixed_root.findall("{" + NS + "}agent"):
                key = node.findtext("{" + NS + "}agentIdentifier/{" + NS + "}agentIdentifierValue")
                fixed_agents[key] = node
        for row in fixity:
            agent, description = row["value"]["agent"], row["description"]
            agents[agent["agentId"]] = _agent_key(agent, description)
            need(identities.setdefault(row["value"]["check"]["objectId"], row["value"]["object"]) == row["value"]["object"], "object ID collision")
            dispositions.append({"eventId": row["value"]["event"]["eventId"], "sourceStatus": "completed",
                "disposition": "premis_event" if fixed_xml else "unsupported", "source": row["selector"]})
    else:
        need(not observations, "unselected observation supplied")
    for row in sorted(generic, key=lambda r: r["body"]["event"]["eventId"]):
        body, report = row["body"], row["report"]
        event, event_id = body["event"], body["event"]["eventId"]
        event_iri = "urn:6529stream:preservation:event:" + event_id
        before = len(issues)
        reason = lambda code: issues.append({"eventId": event_id, "reasonCode": code})
        for obj_ in body["objects"]:
            need(identities.setdefault(obj_["objectId"], obj_["identifier"]) == obj_["identifier"], "object ID collision")
            if obj_["identifier"] not in selected: reason("selected_file_projection_unavailable")
        for agent, description in row["agents"]:
            identity = _agent_key(agent, description)
            need(agents.setdefault(agent["agentId"], identity) == identity, "conflicting named-agent description")
        mapping = {"eventId": event_id, "eventIdentifier": event_iri, "sourceStatus": report["status"],
            "eventTime": event["eventTime"], "objects": body["objects"],
            "agents": [{"agentId": a["agentId"], "agentIdentifier": "urn:6529stream:preservation:agent:" + a["agentId"],
                "role": a["agentRole"]} for a, _ in row["agents"]], "source": row["selector"]}
        correspondence.append(mapping)
        provenance.append({"eventId": event_id, "typedEvent": body, "sourceReport": report,
            "agentDescriptions": [d for _, d in row["agents"]],
            "sourceRecords": [{"recordHash": r.selector.record_hash, "payloadHash": r.payload_hash,
                "authority": loads(r.authority_evidence)} for r in row["records"]]})
        disposition = {"eventId": event_id, "sourceStatus": report["status"], "source": row["selector"]}
        if report["status"] != "completed":
            dispositions.append(disposition | {"disposition": "retained_noncompleted_source"})
            continue
        if event["eventType"] not in TYPES: reason("unsupported_event_type")
        if event["outcome"] not in OUTCOMES: reason("unsupported_event_outcome")
        if not report["results"]: reason("completed_report_result_evidence_missing")
        if event["outcome"] in LOCAL_OUTCOMES and not report["outcomeDetail"]: reason("local_outcome_detail_missing")
        if not 0 < uint(event["eventTime"], 64) <= 253402300799: reason("completed_timestamp_unavailable_for_xml")
        if len(issues) != before:
            dispositions.append(disposition | {"disposition": "unsupported"}); continue
        dispositions.append(disposition | {"disposition": "premis_event"})
        node = etree.Element("{" + NS + "}event")
        _identifier(node, "eventIdentifier", event_iri)
        _element(node, "eventType", TYPES[event["eventType"]])
        instant = datetime(1970, 1, 1, tzinfo=timezone.utc) + timedelta(seconds=uint(event["eventTime"], 64))
        _element(node, "eventDateTime", instant.isoformat().replace("+00:00", "Z"))
        detail = _element(node, "eventDetailInformation")
        _element(detail, "eventDetail", dumps({"sourceStatus": report["status"], "originalEvent": event,
            "report": report, "qualification": "Recorded account report; historical execution and outcome not independently verified."}).decode())
        outcome = _element(node, "eventOutcomeInformation")
        _element(outcome, "eventOutcome", OUTCOMES[event["outcome"]])
        if report["outcomeDetail"]:
            detail = _element(outcome, "eventOutcomeDetail")
            _element(detail, "eventOutcomeDetailNote", dumps({"originalOutcome": event["outcome"], "detail": report["outcomeDetail"]}).decode())
        for agent, _ in row["agents"]:
            link = _identifier(node, "linkingAgentIdentifier", "urn:6529stream:preservation:agent:" + agent["agentId"])
            _element(link, "linkingAgentRole", "urn:6529stream:preservation:role:" + agent["agentRole"])
        for obj_ in body["objects"]:
            link = _identifier(node, "linkingObjectIdentifier", obj_["identifier"])
            _element(link, "linkingObjectRole", "urn:6529stream:preservation:role:" + obj_["role"])
        generic_events.append(node)
    if issues or root is None: return None, issues, dispositions, correspondence, provenance
    for node in sorted(fixed_events + generic_events, key=lambda n: n.findtext("{" + NS + "}eventIdentifier/{" + NS + "}eventIdentifierValue")):
        root.append(node)
    for agent_id, (agent, description) in sorted(agents.items()):
        iri = "urn:6529stream:preservation:agent:" + agent_id
        if iri in fixed_agents:
            root.append(fixed_agents[iri]); continue
        node = _element(root, "agent")
        _identifier(node, "agentIdentifier", iri)
        for kind, value in (("Ethereum address", agent["account"]), ("DID", agent["did"]), ("URI", agent["uri"])):
            if not value or value == "0x" + "00" * 20: continue
            ident = _element(node, "agentIdentifier")
            _element(ident, "agentIdentifierType", kind); _element(ident, "agentIdentifierValue", value)
        _element(node, "agentName", description["name"]); _element(node, "agentType", description["type"])
        if description["agentVersion"]: _element(node, "agentVersion", description["agentVersion"])
        _element(node, "agentNote", "Recorded named-agent description; no identity or historical execution proof.")
    raw = etree.tostring(root, encoding="UTF-8", xml_declaration=True); schema.validate(raw)
    return raw, [], dispositions, correspondence, provenance


def project_recorded_preservation(source, selection_bytes, plan_bytes, premis_plan_bytes, preservation_plan_bytes, *,
        selection_hash, plan_hash, premis_plan_hash, premis_profile_hash, preservation_plan_hash,
        preservation_profile_hash, premis_schema, observations):
    need(type(source) is RecordedSemanticSource and source.state.mode == "recorded_state", "verified recorded source required")
    need(all(r.disclosure == "public" for r in source.state.records), "restricted source unsupported")
    need(preservation_profile_hash == PROFILE_HASH and keccak256(preservation_plan_bytes) == preservation_plan_hash, "plan/profile hash mismatch")
    plan = loads(preservation_plan_bytes, maximum=524288, canonical=True)
    need(isinstance(plan, dict) and set(plan) == {"mode", "version", "sourceStateHash", "profileHash", "premisPlanHash", "preservationProfileHash", "events"}
        and plan["mode"] == MODE and plan["version"] == "1" and plan["sourceStateHash"] == source.state.commitment
        and plan["profileHash"] == source.profile_hash and plan["premisPlanHash"] == premis_plan_hash
        and plan["preservationProfileHash"] == PROFILE_HASH, "plan scope mismatch")
    need(isinstance(plan["events"], list) and len(plan["events"]) <= MAX_EVENTS
        and len({dumps(v) for v in plan["events"]}) == len(plan["events"]), "event selection invalid")
    need(isinstance(observations, dict) and len(observations) <= MAX_EVENTS and all(type(v) is bytes for v in observations.values())
        and sum(map(len, observations.values())) <= MAX_OBSERVATION_BYTES, "observation bound/type")
    fixed, generic = [], []
    for selector in plan["events"]:
        record = source.record(selector)
        (fixed if record.selector.schema_id == schema_id(FIXITY_NAME) else generic).append(selector)
    rows, fixes = admit(source, generic), admit_fixity(source, fixed)
    base = project_recorded_premis(source, selection_bytes, plan_bytes, premis_plan_bytes,
        selection_hash=selection_hash, plan_hash=plan_hash, premis_plan_hash=premis_plan_hash,
        premis_profile_hash=premis_profile_hash, premis_schema=premis_schema)
    xml, issues, dispositions, correspondence, provenance = render(None if base.projection is None else base.projection.xml,
        rows, fixes, observations, premis_schema)
    base_report = loads(base.report, maximum=67108864)
    if base.projection is None: issues.insert(0, {"reasonCode": "file_profile_unsupported", "fileReport": base_report})
    report = dumps({"mode": MODE, "version": "1", "status": "supported" if xml else "unsupported", "issues": issues,
        "sourceStateHash": source.state.commitment, "sourceEvidence": base_report["sourceEvidence"],
        "preservationPlanHash": preservation_plan_hash, "preservationProfileHash": PROFILE_HASH,
        "fileReportHash": keccak256(base.report), "xmlHash": None if xml is None else keccak256(xml),
        "eventDispositions": dispositions,
        "claims": {"historicalPerformanceProven": False, "historicalTimeProven": False, "namedAgentIdentityProven": False,
            "rightsGranted": False, "consensusFinality": False, "fullPremisCrosswalk": False, "institutionalConformance": False}})
    return PreservationProjection(xml, report, dumps(correspondence), dumps(provenance))