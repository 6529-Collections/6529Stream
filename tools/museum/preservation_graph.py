"""Versioned museum activities derived from a verified recorded PREMIS package.

The renderer is pure and accepts synthetic controls; only the package entrypoint
admits recorded evidence. It never interprets opaque roles as participation.
"""
from pathlib import Path

from .canonical import MuseumError, dumps, keccak256, loads
from .dependencies import OfflineDocuments
from .linked_art import PinnedLinkedArt
from .premis import NS, _xml
from .preservation_events import PROFILE_HASH as SOURCE_PROFILE_HASH, TYPES

MODE = "recorded_preservation_activity_graph"
CONTEXT = "https://linked.art/ns/v1/linked-art.json"
VALIDATION_HASH = "0xc5dfe8227e65a2012b707b3d669ec9c4712e1a4e8b3441556b9f8c67da38e19d"
RULE = "urn:6529stream:museum:preservation-graph:v1:"
QUALIFICATION = "Recorded account assertion; historical execution, event time and named-agent identity are not independently established."
CLAIMS = {"historicalPerformanceProven": False, "historicalTimeProven": False,
    "namedAgentIdentityProven": False, "rightsGranted": False, "institutionalConformance": False,
    "linkedArtApiConformance": False, "registeredExport": False}
PROFILE_BYTES = dumps({"id": "STREAM_MUSEUM_PRESERVATION_ACTIVITY_GRAPH_V1", "version": "1",
    "status": "prospective_unregistered_export_profile", "sourceProfileHash": SOURCE_PROFILE_HASH,
    "validationPolicyHash": VALIDATION_HASH, "context": CONTEXT,
    "rules": {
        "activity": "Explicitly completed supported PREMIS event -> Activity; original event IRI retained. Other dispositions remain sidecars.",
        "time": "Exact recorded eventDateTime -> point TimeSpan with equal outer bounds. Never publication, file or export time.",
        "type": "Original PREMIS event type retained as a profile-local Type; no inferred Creation, Acquisition or TransferOfCustody.",
        "agent": "Explicit person -> Person; organization -> Group; exact name -> Name. Software stays typed PREMIS/Stream-only.",
        "premis": "The correspondence index links every emitted event/agent to the exact complete packaged PREMIS DigitalObject and unique XML identifier with original source selectors. Structured PREMIS data is not forced into a linguistic carrier relationship.",
        "roles": "Opaque original agent/object role identifiers remain exact sidecar relationships. No carried_out_by, used_specific_object, rights or custodial role is inferred.",
        "identity": "Original PREMIS event and agent IRIs remain stable. The derived PREMIS document identity uses its immutable complete-byte hash.",
        "provenance": "Every emitted JSON leaf retains its mapping rule, exact PREMIS path and source-selector set; source-authority evidence remains in the literal nested package."},
    "crosswalk": [
        {"rule": RULE + "activity", "source": "typedEvent.event + completed eventDispositions + exact PREMIS event", "target": "Activity /id,/type,/_label,/classified_as,/timespan", "cardinality": "one per explicitly completed supported event", "authority": "original recorded account assertion", "uncertainty": "source qualification retained; only exact recorded seconds converted", "reverse": "index retains event ID, original seconds, outcome and source selector", "positive": "test_completed_activity_expands_with_exact_time_type_and_premis_document", "negative": "test_changed_missing_duplicate_and_noncompleted_event_correspondence_reject"},
        {"rule": RULE + "agent", "source": "original PREMIS agentType/agentName + exact source agent-document selector", "target": "Person or Group /id,/type,/_label,/identified_by", "cardinality": "one per selected named person/organization", "authority": "original recorded named-agent description", "uncertainty": "identity unproven; no account equivalence", "reverse": "original name and class plus unique PREMIS identity", "positive": "test_person_and_organization_names_remain_separate_from_software_and_roles", "negative": "test_noncompleted_reports_never_create_activity_or_promote_their_agents"},
        {"rule": RULE + "premis", "source": "complete retained PREMIS bytes", "target": "DigitalObject + explicit correspondence index", "cardinality": "one document and every referenced event/agent/object", "authority": "derived byte identity only", "uncertainty": "XML validity is not historical fact", "reverse": "exact retained byte hash and XML identity path", "positive": "test_versioned_package_retains_actual_source_and_rebuilds_offline", "negative": "test_source_unsupported_stays_exact_without_placeholder_graph"}],
    "claims": CLAIMS})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def validator(root):
    root = Path(root)
    raw = (root / "linked-art-v2/validation-policy.json").read_bytes()
    index = loads((root / "linked-art-v2/validation-index.json").read_bytes(), maximum=65536)
    return PinnedLinkedArt(OfflineDocuments(root, index), raw, VALIDATION_HASH)


def _one(node, path):
    result = node.findall(path, {"p": NS})
    if len(result) != 1 or result[0].text is None:
        raise MuseumError("preservation graph unique PREMIS field required: " + path)
    return result[0].text


def _leaves(value, path=""):
    if isinstance(value, dict):
        for key, item in value.items():
            yield from _leaves(item, path + "/" + key.replace("~", "~0").replace("/", "~1"))
    elif isinstance(value, list):
        for index, item in enumerate(value): yield from _leaves(item, path + "/" + str(index))
    else: yield path, value


def render(xml, source_report, source_provenance, linked_art):
    """Pure crosswalk. Callers must retain its explicit source trust qualification."""
    report = loads(source_report, maximum=67108864)
    evidence = loads(source_provenance, maximum=67108864)
    dispositions = report["eventDispositions"]
    if report["status"] != "supported" or xml is None:
        return {"graph/report.json": dumps({"mode": MODE, "version": "1", "status": "unsupported",
            "reasonCode": "source_premis_projection_unavailable", "sourceReportHash": keccak256(source_report),
            "eventDispositions": dispositions, "claims": CLAIMS}),
            "graph/index.json": dumps({"resources": [], "premisReferences": []}),
            "graph/sidecar.json": dumps({"eventDispositions": dispositions, "sourceEvidence": evidence}),
            "graph/provenance.json": dumps([])}
    if keccak256(xml) != report["xmlHash"]: raise MuseumError("preservation graph PREMIS hash differs")
    root = _xml(xml)
    by_event = {row["eventId"]: row for row in evidence}
    if len(by_event) != len(evidence): raise MuseumError("preservation graph duplicate event evidence")
    selected = {row["eventId"]: row for row in dispositions if row["disposition"] == "premis_event"}
    if len({r["eventId"] for r in dispositions}) != len(dispositions):
        raise MuseumError("preservation graph duplicate disposition")
    document = "urn:6529stream:premis-document:" + keccak256(xml)
    files, index, provenance, references, roles = {}, [], [], [], []
    seen = set()

    def emit(resource, rule, xpath, selectors):
        identifier = resource["id"]
        if identifier in seen: raise MuseumError("preservation graph duplicate resource identity")
        seen.add(identifier)
        raw = dumps(resource); expanded = linked_art.validate_and_expand(raw)
        name = keccak256(identifier.encode())[2:]
        path = "graph/resources/" + name + ".json"
        files[path] = raw; files["graph/expanded/" + name + ".json"] = expanded.expanded_bytes
        index.append({"id": identifier, "type": resource["type"], "path": path})
        for pointer, value in _leaves(resource):
            provenance.append({"entity": identifier, "path": pointer, "value": value,
                "rule": RULE + rule, "premisPath": xpath, "sourceSelectors": selectors,
                "qualification": QUALIFICATION})

    def resource(identifier, kind, label):
        return {"@context": CONTEXT, "id": identifier, "type": kind, "_label": label,
            "referred_to_by": [{"type": "LinguisticObject", "content": QUALIFICATION}]}

    agent_sources, type_sources = {}, {}
    event_ids = set()
    for node in root.findall("p:event", {"p": NS}):
        iri = _one(node, "p:eventIdentifier/p:eventIdentifierValue")
        prefix = "urn:6529stream:preservation:event:"
        if not iri.startswith(prefix): raise MuseumError("preservation graph unsupported event identity")
        event_id = iri[len(prefix):]
        if event_id in event_ids or event_id not in selected or event_id not in by_event:
            raise MuseumError("preservation graph event/disposition correspondence differs")
        event_ids.add(event_id)
        source = selected[event_id]
        if source["sourceStatus"] != "completed": raise MuseumError("preservation graph noncompleted Activity refused")
        typed = by_event[event_id]["typedEvent"]
        kind = typed["event"]["eventType"]
        label = _one(node, "p:eventType")
        if TYPES.get(kind) != label: raise MuseumError("preservation graph event vocabulary differs")
        date = _one(node, "p:eventDateTime")
        path = "premis:event[premis:eventIdentifier/premis:eventIdentifierValue='" + iri + "']"
        item = resource(iri, "Activity", "Reported " + label)
        item["classified_as"] = [{"id": "urn:6529stream:preservation:event-type:" + kind,
            "type": "Type", "_label": label}]
        item["timespan"] = {"type": "TimeSpan", "begin_of_the_begin": date, "end_of_the_end": date}
        emit(item, "activity", path, [source["source"]])
        type_sources.setdefault(kind, []).append(source["source"])
        references.append({"id": iri, "premisDocument": document, "premisPath": path,
            "source": source["source"], "sourceEventTime": typed["event"]["eventTime"], "sourceOutcome": typed["event"]["outcome"]})
        for link in node.findall("p:linkingAgentIdentifier", {"p": NS}):
            aid = _one(link, "p:linkingAgentIdentifierValue")
            original = ([{"agent": typed["agent"], "document": typed["agentDocument"]}]
                if "agent" in typed else typed["agents"])
            matches = [row["document"] for row in original if aid == "urn:6529stream:preservation:agent:" + row["agent"]["agentId"]]
            if len(matches) != 1: raise MuseumError("preservation graph agent source correspondence differs")
            agent_sources.setdefault(aid, []).append(matches[0])
        roles.append({"event": iri, "disposition": "retained_stream_only",
            "reason": "Opaque role codes do not establish a supported Linked Art participation or object-use relation.",
            "agents": [{"id": _one(v, "p:linkingAgentIdentifierValue"), "role": _one(v, "p:linkingAgentRole")}
                for v in node.findall("p:linkingAgentIdentifier", {"p": NS})],
            "objects": [{"id": _one(v, "p:linkingObjectIdentifierValue"), "role": v.findtext("p:linkingObjectRole", namespaces={"p": NS})}
                for v in node.findall("p:linkingObjectIdentifier", {"p": NS})]})
    if event_ids != set(selected): raise MuseumError("preservation graph missing PREMIS event")
    for node in root.findall("p:object", {"p": NS}):
        iri = _one(node, "p:objectIdentifier/p:objectIdentifierValue")
        references.append({"id": iri, "representation": "premis_object", "premisDocument": document,
            "premisPath": "premis:object[premis:objectIdentifier/premis:objectIdentifierValue=" + dumps(iri).decode() + "]"})
    software = []
    for node in root.findall("p:agent", {"p": NS}):
        ids = [n.text for n in node.findall("p:agentIdentifier/p:agentIdentifierValue", {"p": NS})
            if n.text and n.text.startswith("urn:6529stream:preservation:agent:")]
        if len(ids) != 1: raise MuseumError("preservation graph unique agent identity required")
        iri = ids[0]
        if iri not in agent_sources: continue  # A noncompleted report's agent is retained in the source only.
        kind, name = _one(node, "p:agentType"), _one(node, "p:agentName")
        path = "premis:agent[premis:agentIdentifier/premis:agentIdentifierValue='" + iri + "']"
        selectors = sorted({dumps(v): v for v in agent_sources[iri]}.values(), key=dumps)
        references.append({"id": iri, "premisDocument": document, "premisPath": path, "sources": selectors})
        if kind in ("person", "organization"):
            item = resource(iri, "Person" if kind == "person" else "Group", name)
            item["identified_by"] = [{"type": "Name", "content": name}]
            emit(item, "agent", path, selectors)
        else:
            software.append({"id": iri, "type": kind, "name": name,
                "disposition": "retained_stream_only", "premisPath": path, "sourceSelectors": selectors})
    for kind, selectors in sorted(type_sources.items()):
        emit({"@context": CONTEXT, "id": "urn:6529stream:preservation:event-type:" + kind,
            "type": "Type", "_label": TYPES[kind]}, "type", "premis:event/premis:eventType", selectors)
    emit({"@context": CONTEXT, "id": document, "type": "DigitalObject",
        "_label": "Complete recorded preservation PREMIS document", "format": "application/xml"},
        "premis", "/premis:premis", [r["source"] for r in dispositions])
    # All graph references to the PREMIS document resolve to this packaged byte object.
    references.append({"id": document, "path": "source/premis-preservation/premis.xml", "contentHash": keccak256(xml)})
    files["graph/index.json"] = dumps({"resources": sorted(index, key=lambda r: r["id"]),
        "premisReferences": references})
    files["graph/provenance.json"] = dumps(provenance)
    files["graph/sidecar.json"] = dumps({"eventDispositions": dispositions, "unmappedRelations": roles,
        "streamOnlyAgents": software, "sourceEvidence": evidence})
    files["graph/report.json"] = dumps({"mode": MODE, "version": "1", "status": "supported",
        "sourceReportHash": keccak256(source_report), "premisHash": keccak256(xml),
        "events": str(len(event_ids)), "resources": str(len(index)), "profileHash": PROFILE_HASH,
        "validationPolicyHash": VALIDATION_HASH, "qualification": QUALIFICATION, "claims": CLAIMS})
    return files
