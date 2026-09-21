"""Source-bound Linked Art projection for a verified conservation dossier.

This adapter consumes the four exact outputs of
``conservation_dossier_projection_v1``.  It does not replay the native source;
the enclosing package remains responsible for that replay.  The adapter
reconstructs the dossier's complete leaf and Reference inventories before it
emits any resource.
"""

from copy import deepcopy
from pathlib import Path

from tools.metadata import conservation_profile as conservation

from . import conservation_dossier_projection_v1 as dossier_projection
from .canonical import MuseumError, dumps, keccak256, loads
from .independent_wire import require
from .owner_notice_dossier import DEFAULT_MODEL_ROOT
from .preservation_graph import CONTEXT, VALIDATION_HASH, validator


PROFILE = "STREAM_MUSEUM_CONSERVATION_SEMANTIC_GRAPH_V1"
RULE = "urn:6529stream:museum:conservation-graph:v1:"
MAX_BYTES = 64 * 1024 * 1024
MAX_RESOURCES = 8192
MAX_RESOURCE_BYTES = 262144

OUTPUT_PREFIX = "conservation-semantic/"
INDEX_PATH = OUTPUT_PREFIX + "index.json"
PROVENANCE_PATH = OUTPUT_PREFIX + "provenance.json"
SIDECAR_PATH = OUTPUT_PREFIX + "sidecar.json"
COVERAGE_PATH = OUTPUT_PREFIX + "coverage.json"
REPORT_PATH = OUTPUT_PREFIX + "report.json"
PROFILE_PATH = OUTPUT_PREFIX + "profile.json"
CROSSWALK_PATH = OUTPUT_PREFIX + "crosswalk.json"

QUALIFICATION = (
    "Source-bound semantic projection of exact public conservation dossier bytes. "
    "Linked Art resources describe declared statements and digital resources only. "
    "References are not retrieved; participant identity, interview performance, "
    "consent, file receipt, format detection, archival verification, current "
    "authority and legal effect are not established."
)
CLAIMS = {
    "inputDossierProfileChecked": True,
    "inputLeafAndReferenceInventoriesReconstructed": True,
    "linkedArtResourcesShapeValidatedOffline": True,
    "completeInputFieldsAccounted": True,
    "arrayOrderAndDuplicateOccurrencesPreserved": True,
    "artistAndEstateAttributionKeptSeparate": True,
    "historicalSelectionAndCurrentEligibilityKeptSeparate": True,
    "referenceContentRetrieved": False,
    "participantIdentityProven": False,
    "personOrGroupInferred": False,
    "interviewPerformanceProven": False,
    "consentProven": False,
    "mediaReceiptProven": False,
    "mediaFormatDetected": False,
    "archiveDeliveryProven": False,
    "currentAuthorityProven": False,
    "linkedArtApiConformanceClaimed": False,
    "profileRegistered": False,
}


def _row(rule, selector, subject, target, path, cardinality, transformation,
         authority, uncertainty, reverse, positive, negative, terms=()):
    return {
        "rule": RULE + rule,
        "sourceSchema": "STREAM_MUSEUM_CONSERVATION_DOSSIER_PROJECTION_V1",
        "sourceSchemaVersion": "1",
        "sourceSelector": selector,
        "sourceSubjectKind": subject,
        "targetClass": target,
        "targetPropertyPath": path,
        "cardinality": cardinality,
        "transformation": transformation,
        "authority": authority,
        "controlledTerms": list(terms),
        "uncertainty": uncertainty,
        "reverseCorrespondence": reverse,
        "positiveTest": positive,
        "negativeTest": negative,
    }


CROSSWALK = {
    "name": "STREAM_MUSEUM_CONSERVATION_SEMANTIC_CROSSWALK_V1",
    "version": "1",
    "inputProfileHash": dossier_projection.PROFILE_HASH,
    "sourceFamilyProfiles": [{"schemaName": name,
        "schemaHash": conservation.digest(conservation.canonical(conservation.schema(name))),
        "profileName": conservation.PROFILES[name],
        "profileHash": conservation.digest(conservation.canonical(conservation.profile(name)))}
        for name in conservation.FAMILIES],
    "rules": [
        _row("statement-reference", "/records/*/semantic/**/{hash,uri}",
            "explicit intent, waiver, interview-waiver or preservation statement Reference",
            "LinguisticObject", "/type,/classified_as",
            "one resource per ordered Reference occurrence",
            "Create a described-only LinguisticObject with no symbolic content.",
            "original Artist/estate publication class as an attributed declaration",
            "Referenced bytes, authorship beyond the original publication class and assent are unproven.",
            "occurrence identity retains record selector, JSON Pointer, exact hash and URI",
            "test_statement_instrument_capture_payload_and_format_resources_are_distinct_and_described_only",
            "test_participant_roles_order_duplicates_and_identity_references_remain_exact"),
        _row("transcript", "/records/*/semantic/transcript", "explicit interview transcript payload",
            "DigitalObject + LinguisticObject", "/digitally_carries/*",
            "one carrier and one linguistic content identity per transcript occurrence",
            "The transcript payload is the digital carrier; its exact content Reference identifies declared linguistic content. No content literal is emitted.",
            "original interview publication class",
            "Transcript bytes, language content and actual recording/performance are unproven.",
            "both identities retain the transcript content occurrence and payload pointer",
            "test_transcript_has_distinct_validated_carrier_and_linguistic_content",
            "test_statement_instrument_capture_payload_and_format_resources_are_distinct_and_described_only",
            ("transcript", "described_only")),
        _row("instrument", "/records/*/semantic/instrument/document", "explicit interview instrument document Reference",
            "DigitalObject", "/type,/classified_as", "one per ordered occurrence",
            "Create a described-only digital document; retain VMQ/named-derivative semantics in the sidecar.",
            "original interview publication class", "Document bytes and questionnaire completion are unproven.",
            "resource retains occurrence, instrument variant and exact Reference",
            "test_statement_instrument_capture_payload_and_format_resources_are_distinct_and_described_only",
            "test_participant_roles_order_duplicates_and_identity_references_remain_exact", ("interview_instrument", "described_only")),
        _row("capture", "/records/*/semantic/captures/*/payload/content", "explicit audio/video capture content Reference",
            "DigitalObject", "/type,/classified_as", "one per ordered capture, including equal References",
            "Create a described-only digital resource; retain audio/video and exact declared format in the sidecar.",
            "original interview publication class",
            "No receipt, duration, speech, visual content, codec detection or archival verification is inferred.",
            "resource retains capture index, exact content/format and occurrence selector",
            "test_statement_instrument_capture_payload_and_format_resources_are_distinct_and_described_only",
            "test_participant_roles_order_duplicates_and_identity_references_remain_exact", ("audio", "video", "described_only")),
        _row("interview-payload", "/records/*/semantic/interview/payload", "exact parent-declared interview payload Reference",
            "DigitalObject", "/type,/classified_as", "one per ordered parent Reference occurrence",
            "Create a described-only digital payload resource distinct from the original interview record.",
            "original parent publication class", "Payload bytes are not retrieved and the Reference does not prove performance.",
            "resource retains the parent source selector, JSON Pointer and exact Reference",
            "test_statement_instrument_capture_payload_and_format_resources_are_distinct_and_described_only",
            "test_exact_source_selectors_provenance_and_relationship_sidecars_are_retained", ("interview_payload", "described_only")),
        _row("format-document", "/records/*/semantic/**/format/mapping/specification or /catalogDocuments/*/value/**/specification",
            "explicit format specification Reference", "DigitalObject", "/type,/classified_as",
            "one per ordered specification Reference occurrence",
            "Create a described-only specification document; do not treat it as detected media format.",
            "original record or selected catalog declaration", "Specification bytes and applicability beyond the exact declaration are unproven.",
            "resource retains source record/catalog selector, JSON Pointer and exact Reference",
            "test_statement_instrument_capture_payload_and_format_resources_are_distinct_and_described_only",
            "test_interview_is_attributed_declaration_not_activity_or_performance", ("format_specification", "described_only")),
        _row("participant-role", "/records/*/semantic/participants/*", "declared participant role and identity Reference",
            None, None, "one exact sidecar relation per ordered participant occurrence",
            "Retain role, optional roleLabel and identity Reference without emitting an agent.",
            "original interview publication class", "Identity, participation, consent and role performance are unproven.",
            "sidecar retains participant index, exact fields and Reference occurrence",
            "test_participant_roles_order_duplicates_and_identity_references_remain_exact",
            "test_participant_roles_order_duplicates_and_identity_references_remain_exact", ("artist", "interviewer", "other")),
        _row("interview-declaration", "/records/*[family=interview]/semantic", "structured interview declaration",
            None, None, "one exact sidecar declaration per original interview record",
            "Retain date, languages, participant roles, instrument, transcript and captures as an attributed declaration.",
            "original Artist/estate publication class",
            "A present record is not a performed Activity and its date is not an observed event TimeSpan.",
            "sidecar retains the complete semantic object plus source selector",
            "test_interview_is_attributed_declaration_not_activity_or_performance",
            "test_interview_is_attributed_declaration_not_activity_or_performance"),
        _row("parent-interview", "/parentInterviewRelationships/*", "selected parent record to original interview record",
            None, None, "one typed sidecar relation per exact joined parent/interview row",
            "Retain exact record hashes, payload Reference and locator without replacing either original.",
            "verified dossier join", "Selection is historical and current eligibility is separate.",
            "sidecar copies the exact joined relation and selectors",
            "test_parent_interview_and_lineages_keep_history_current_and_attribution_separate",
            "test_changed_missing_unknown_or_rehashed_input_derivatives_reject"),
        _row("complete-coverage", "/records/*/semantic/** and /catalogDocuments/*/value/**",
            "every semantic leaf and Reference occurrence", None, None,
            "every scalar, null, empty container and Reference occurrence exactly once",
            "Map supported Reference occurrences as semantic units; retain every raw leaf exact as retained_stream_only.",
            "exact dossier projection", "Sidecar retention does not strengthen source meaning.",
            "coverage rows retain source IDs, JSON Pointers, values and input ledger hashes",
            "test_complete_leaf_and_reference_coverage_matches_frozen_projection",
            "test_changed_missing_unknown_or_rehashed_input_derivatives_reject"),
    ],
    "completeness": "complete_with_stream_extensions",
}
CROSSWALK_BYTES = dumps(CROSSWALK)
CROSSWALK_HASH = keccak256(CROSSWALK_BYTES)
PROFILE_BYTES = dumps({
    "name": PROFILE,
    "version": "1",
    "status": "prospective_unregistered_projection_profile",
    "inputProfile": dossier_projection.PROFILE,
    "inputProfileHash": dossier_projection.PROFILE_HASH,
    "crosswalkHash": CROSSWALK_HASH,
    "validationPolicyHash": VALIDATION_HASH,
    "context": CONTEXT,
    "completeness": "complete_with_stream_extensions",
    "rules": {
        "source": "Accept exactly the four frozen conservation dossier outputs and reconstruct both complete inventories before graph emission.",
        "resources": "Only source-semantic statements, transcript payloads, instrument documents and audio/video captures receive graph identities.",
        "activity": "A present interview record remains an attributed declaration and never becomes Activity without separate completed-event evidence.",
        "identity": "Participant identity References remain typed references and never become Person or Group.",
        "availability": "All referenced resources remain described_only; no retrieval, receipt, fixity or archival state is inferred.",
        "coverage": "Every input leaf and Reference occurrence is mapped or retained_stream_only with exact selectors and order.",
    },
    "claims": CLAIMS,
    "qualification": QUALIFICATION,
})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _model(root):
    return validator(Path(root))


def _pointer(parts):
    return "" if not parts else "/" + "/".join(
        str(part).replace("~", "~0").replace("/", "~1") for part in parts)


def _walk(value, parts=()):
    references, leaves = [], []
    if isinstance(value, dict):
        if set(value) == {"hash", "uri"} and isinstance(value["hash"], dict):
            references.append((parts, value))
        if not value:
            leaves.append((parts, "empty_object", {}))
        else:
            for key, child in value.items():
                child_refs, child_leaves = _walk(child, parts + (key,))
                references.extend(child_refs); leaves.extend(child_leaves)
    elif isinstance(value, list):
        if not value:
            leaves.append((parts, "empty_array", []))
        else:
            for index, child in enumerate(value):
                child_refs, child_leaves = _walk(child, parts + (index,))
                references.extend(child_refs); leaves.extend(child_leaves)
    else:
        kind = "null" if value is None else "boolean" if type(value) is bool else (
            "integer" if type(value) is int else "string")
        require(value is None or type(value) in (bool, int, str), "conservation semantic graph scalar type")
        leaves.append((parts, kind, value))
    return references, leaves


def _relation(parts):
    names = tuple(str(part) for part in parts)
    if "display" in names: return "display_statement"
    if "waiverStatement" in names: return "intent_waiver_statement"
    if names[-2:] == ("interview", "statement"): return "interview_waiver_statement"
    if names[-2:] == ("interview", "payload"): return "interview_payload"
    if "instrument" in names and names[-1] == "document": return "interview_instrument_document"
    if "participants" in names and names[-1] == "identity": return "participant_identity"
    if "captures" in names and names[-1] == "content": return "capture_content"
    if "transcript" in names and names[-1] == "content": return "transcript_content"
    if names[-1] == "specification": return "format_specification"
    if names[-1] == "variabilityTolerances": return "variability_tolerances"
    if names[-1] == "dependencyAging": return "dependency_aging"
    if names[-1] == "significantProperties": return "significant_properties"
    return "declared_reference"


def _expected_inventories(dossier):
    references, leaves, roots = [], [], []
    for index, row in enumerate(dossier["records"]):
        found, covered = _walk(row["semantic"])
        start = len(leaves)
        for parts, kind, value in covered:
            leaves.append({"sourceKind": "record", "sourceId": row["selector"]["recordHash"],
                "jsonPointer": _pointer(("records", index, "semantic") + parts),
                "valueType": kind, "value": deepcopy(value)})
        for parts, reference in found:
            references.append({"occurrence": len(references), "sourceKind": "record",
                "sourceRecord": deepcopy(row["selector"]), "dossierPath": "conservation/dossier.json",
                "jsonPointer": _pointer(("records", index, "semantic") + parts),
                "relation": _relation(parts), "hash": deepcopy(reference["hash"]), "uri": reference["uri"]})
        roots.append({"sourceKind": "record", "sourceId": row["selector"]["recordHash"],
            "semanticHash": keccak256(dumps(row["semantic"])), "leafCount": len(leaves) - start})
    for index, row in enumerate(dossier["catalogDocuments"]):
        found, covered = _walk(row["value"])
        start = len(leaves)
        for parts, kind, value in covered:
            leaves.append({"sourceKind": "catalog_document", "sourceId": row["documentId"],
                "jsonPointer": _pointer(("catalogDocuments", index, "value") + parts),
                "valueType": kind, "value": deepcopy(value)})
        for parts, reference in found:
            references.append({"occurrence": len(references), "sourceKind": "catalog_document",
                "sourceRecord": None, "catalogSelector": {"documentId": row["documentId"],
                    "documentHash": row["documentHash"]}, "dossierPath": "conservation/dossier.json",
                "jsonPointer": _pointer(("catalogDocuments", index, "value") + parts),
                "relation": "catalog_format_specification", "hash": deepcopy(reference["hash"]),
                "uri": reference["uri"]})
        roots.append({"sourceKind": "catalog_document", "sourceId": row["documentId"],
            "semanticHash": keccak256(dumps(row["value"])), "leafCount": len(leaves) - start})
    return references, leaves, roots


def _inputs(files):
    require(type(files) is dict and set(files) == set(dossier_projection.OUTPUTS)
        and all(type(path) is str and type(raw) is bytes for path, raw in files.items())
        and sum(map(len, files.values())) <= MAX_BYTES, "conservation semantic graph exact input files")
    require(files[dossier_projection.OUTPUTS[3]] == dossier_projection.PROFILE_BYTES,
        "conservation semantic graph input profile differs")
    dossier = loads(files[dossier_projection.OUTPUTS[0]], maximum=MAX_BYTES, canonical=True)
    references = loads(files[dossier_projection.OUTPUTS[1]], maximum=MAX_BYTES, canonical=True)
    leaves = loads(files[dossier_projection.OUTPUTS[2]], maximum=MAX_BYTES, canonical=True)
    require(type(dossier) is dict and dossier.get("profile") == dossier_projection.PROFILE
        and dossier.get("profileHash") == dossier_projection.PROFILE_HASH
        and dossier.get("version") == "1" and dossier.get("claims") == dossier_projection.CLAIMS
        and dossier.get("qualification") == dossier_projection.QUALIFICATION,
        "conservation semantic graph dossier profile differs")
    expected_refs, expected_leaves, expected_roots = _expected_inventories(dossier)
    require(references == {"profileHash": dossier_projection.PROFILE_HASH,
        "scope": "all_closed_reference_occurrences_in_projected_semantics", "occurrences": expected_refs},
        "conservation semantic graph Reference inventory differs")
    require(leaves == {"profileHash": dossier_projection.PROFILE_HASH,
        "scope": "all_record_semantics_and_selected_catalog_documents", "roots": expected_roots,
        "leaves": expected_leaves}, "conservation semantic graph leaf ledger differs")
    coverage = {"recordSemanticRoots": len(dossier["records"]),
        "catalogSemanticRoots": len(dossier["catalogDocuments"]),
        "semanticLeafCount": len(expected_leaves),
        "nullLeafCount": sum(row["valueType"] == "null" for row in expected_leaves),
        "emptyArrayCount": sum(row["valueType"] == "empty_array" for row in expected_leaves),
        "emptyObjectCount": sum(row["valueType"] == "empty_object" for row in expected_leaves),
        "referenceOccurrenceCount": len(expected_refs),
        "semanticLeafLedgerHash": keccak256(files[dossier_projection.OUTPUTS[2]]),
        "referenceOccurrenceInventoryHash": keccak256(files[dossier_projection.OUTPUTS[1]]),
        "complete": True}
    require(dossier.get("leafCoverage") == coverage, "conservation semantic graph dossier coverage differs")
    return dossier, expected_refs, expected_leaves


def _source_key(row):
    selector = row.get("sourceRecord") or row.get("catalogSelector")
    return {"sourceKind": row["sourceKind"], "selector": deepcopy(selector),
        "dossierPath": row["dossierPath"], "jsonPointer": row["jsonPointer"],
        "occurrence": row["occurrence"], "relation": row["relation"],
        "hash": deepcopy(row["hash"]), "uri": row["uri"]}


def _identity(row, suffix="reference"):
    return RULE + suffix + ":" + keccak256(dumps(_source_key(row)))[2:]


def _role(relation):
    return {"id": RULE + "role:" + relation.replace("_", "-"), "type": "Type",
        "_label": relation.replace("_", " ")}


def _resource(identifier, kind, label, relation):
    return {"@context": CONTEXT, "id": identifier, "type": kind, "_label": label,
        "classified_as": [_role(relation)],
        "referred_to_by": [{"type": "LinguisticObject", "content": QUALIFICATION}]}


STATEMENT_RELATIONS = {
    "display_statement", "intent_waiver_statement", "interview_waiver_statement",
    "variability_tolerances", "dependency_aging", "significant_properties",
}
DIGITAL_RELATIONS = {"interview_instrument_document", "capture_content", "interview_payload",
    "format_specification", "catalog_format_specification"}


def _record_for_pointer(dossier, pointer):
    parts = pointer.split("/")
    require(len(parts) > 4 and parts[1] == "records" and parts[2].isdigit(),
        "conservation semantic graph record pointer")
    index = int(parts[2])
    require(index < len(dossier["records"]), "conservation semantic graph record pointer bound")
    return dossier["records"][index], parts[4:]


def _participant_rows(dossier, reference_rows):
    result = []
    by_pointer = {row["jsonPointer"]: row for row in reference_rows}
    for record_index, record in enumerate(dossier["records"]):
        if record["family"] != "interview":
            continue
        for index, participant in enumerate(record["semantic"]["participants"]):
            pointer = f"/records/{record_index}/semantic/participants/{index}/identity"
            row = by_pointer[pointer]
            result.append({"interviewRecordHash": record["selector"]["recordHash"],
                "participantIndex": index, "role": participant["role"],
                "roleLabel": participant.get("roleLabel"), "identityReference": deepcopy(participant["identity"]),
                "sourceOccurrence": _source_key(row), "disposition": "retained_stream_only",
                "personOrGroupInferred": False, "participationProven": False})
    return result


def _interview_rows(dossier, reference_rows, graph_ids):
    by_pointer = {row["jsonPointer"]: row for row in reference_rows}
    result = []
    for record_index, record in enumerate(dossier["records"]):
        if record["family"] != "interview":
            continue
        value = record["semantic"]
        prefix = f"/records/{record_index}/semantic"
        instrument = by_pointer[prefix + "/instrument/document"]
        transcript = by_pointer[prefix + "/transcript/content"]
        captures = []
        for index, capture in enumerate(value["captures"]):
            occurrence = by_pointer[prefix + f"/captures/{index}/payload/content"]
            captures.append({"index": index, "kind": capture["kind"],
                "resourceId": graph_ids[occurrence["occurrence"]][0], "payload": deepcopy(capture["payload"]),
                "sourceOccurrence": _source_key(occurrence), "status": "described_only"})
        result.append({"recordHash": record["selector"]["recordHash"], "sourceRecord": deepcopy(record["selector"]),
            "publicationClass": record["originalPublicationClass"],
            "publicationOrigin": record["originalPublicationOrigin"], "status": "attributed_declaration_only",
            "interviewPerformanceProven": False, "consentProven": False,
            "interviewDate": value["interviewDate"], "languages": deepcopy(value["languages"]),
            "instrument": {"kind": value["instrument"]["kind"], "name": value["instrument"].get("name"),
                "resourceId": graph_ids[instrument["occurrence"]][0], "sourceOccurrence": _source_key(instrument)},
            "transcript": {"carrierId": graph_ids[transcript["occurrence"]][0],
                "linguisticContentId": graph_ids[transcript["occurrence"]][1],
                "payload": deepcopy(value["transcript"]), "sourceOccurrence": _source_key(transcript),
                "status": "described_only"}, "captures": captures})
    return result


def _relationship_rows(dossier):
    records = {row["selector"]["recordHash"]: row for row in dossier["records"]}
    result = []
    for row in dossier["parentInterviewRelationships"]:
        parent = records.get(row["parentRecordHash"])
        interview = records.get(row["interviewRecordHash"])
        require(parent is not None and interview is not None, "conservation semantic graph parent/interview source")
        result.append({"kind": "parent_interview", "relationship": deepcopy(row),
            "parentSourceRecord": deepcopy(parent["selector"]),
            "interviewSourceRecord": deepcopy(interview["selector"]),
            "disposition": "retained_stream_only",
            "reason": "Exact conservation relationship has no supported generic Linked Art replacement."})
    return result


def _lineage_rows(dossier):
    records = {row["selector"]["recordHash"]: row for row in dossier["records"]}
    result = []
    for scope in dossier["scopes"]:
        for lane in scope["lineages"]:
            for revision in lane["revisions"]:
                parent = records.get(revision["recordHash"])
                require(parent is not None, "conservation semantic graph lineage parent source")
                interview = (None if revision["interviewRecordHash"] is None
                    else records.get(revision["interviewRecordHash"]))
                require(revision["interviewRecordHash"] is None or interview is not None,
                    "conservation semantic graph lineage interview source")
                result.append({"scope": scope["scope"], "subjectId": scope["subjectId"],
                    "origin": lane["origin"], "revision": revision["revision"],
                    "parentSourceRecord": deepcopy(parent["selector"]),
                    "interviewSourceRecord": None if interview is None else deepcopy(interview["selector"]),
                    "selection": deepcopy(revision), "currentEligibility": deepcopy(lane["currentEligibility"]),
                    "disposition": "retained_stream_only"})
    return result


def _emit(files, model, resource, row, rule, provenance, index):
    raw = dumps(resource)
    expanded = model.validate_and_expand(raw, maximum=MAX_RESOURCE_BYTES).expanded_bytes
    stem = keccak256(resource["id"].encode())[2:]
    path = OUTPUT_PREFIX + "resources/" + stem + ".json"
    expanded_path = OUTPUT_PREFIX + "expanded/" + stem + ".json"
    require(path not in files and expanded_path not in files, "conservation semantic graph resource collision")
    files[path], files[expanded_path] = raw, expanded
    source = _source_key(row)
    index.append({"id": resource["id"], "type": resource["type"], "path": path,
        "expandedPath": expanded_path, "status": "described_only", "sourceOccurrence": source})
    for pointer, _, value in _walk(resource)[1]:
        provenance.append({"entity": resource["id"], "targetPointer": _pointer(pointer),
            "value": deepcopy(value), "rule": RULE + rule, "sourceOccurrence": source,
            "authority": "original attributed declaration", "qualification": QUALIFICATION})


def _project(input_files, model):
    dossier, reference_rows, leaf_rows = _inputs(input_files)
    require(len(reference_rows) <= MAX_RESOURCES, "conservation semantic graph Reference resource bound")
    files, index, provenance, dispositions, graph_ids = {}, [], [], [], {}
    for row in reference_rows:
        relation = row["relation"]
        resources = []
        if relation == "transcript_content":
            carrier = _resource(_identity(row, "transcript-carrier"), "DigitalObject",
                "Declared transcript digital carrier", relation)
            content_id = _identity(row, "transcript-content")
            carrier["digitally_carries"] = [{"id": content_id, "type": "LinguisticObject"}]
            content = _resource(content_id, "LinguisticObject", "Declared interview transcript", relation)
            resources = [(carrier, "transcript"), (content, "transcript")]
        elif relation in STATEMENT_RELATIONS:
            resources = [(_resource(_identity(row), "LinguisticObject", "Declared conservation statement", relation),
                "statement-reference")]
        elif relation in DIGITAL_RELATIONS:
            label = "Declared interview digital resource" if relation.startswith(("interview", "capture")) else "Declared format document"
            rule = ("instrument" if relation == "interview_instrument_document" else
                "capture" if relation == "capture_content" else
                "interview-payload" if relation == "interview_payload" else "format-document")
            resources = [(_resource(_identity(row), "DigitalObject", label, relation), rule)]
        graph_ids[row["occurrence"]] = tuple(resource["id"] for resource, _ in resources)
        if resources:
            for resource, rule in resources:
                _emit(files, model, resource, row, rule, provenance, index)
            disposition = "mapped"
        else:
            disposition = "retained_stream_only"
        dispositions.append({"sourceOccurrence": _source_key(row), "semanticRole": relation,
            "disposition": disposition, "resourceIds": list(graph_ids[row["occurrence"]]),
            "reason": None if resources else "No faithful supported Linked Art resource or relationship is inferred."})

    participants = _participant_rows(dossier, reference_rows)
    interviews = _interview_rows(dossier, reference_rows, graph_ids)
    relationships = _relationship_rows(dossier)
    lineages = _lineage_rows(dossier)
    leaf_coverage = []
    for row in leaf_rows:
        leaf_coverage.append(deepcopy(row) | {"disposition": "retained_stream_only",
            "reason": "retained exact in conservation dossier and typed sidecar"})
    files[INDEX_PATH] = dumps({"profile": PROFILE, "profileHash": PROFILE_HASH,
        "validationPolicyHash": VALIDATION_HASH, "resources": index})
    files[PROVENANCE_PATH] = dumps(provenance)
    files[SIDECAR_PATH] = dumps({"profile": PROFILE, "referenceDispositions": dispositions,
        "interviewDeclarations": interviews, "participantRoleDeclarations": participants,
        "parentInterviewRelationships": relationships, "selectionLineages": lineages,
        "scopes": deepcopy(dossier["scopes"]), "currentAssociation": deepcopy(dossier["currentAssociation"]),
        "sourceQualification": dossier["sourceQualification"], "qualification": QUALIFICATION})
    files[COVERAGE_PATH] = dumps({"profile": PROFILE, "completeness": "complete_with_stream_extensions",
        "inputSemanticLeafLedgerHash": dossier["leafCoverage"]["semanticLeafLedgerHash"],
        "inputReferenceOccurrenceInventoryHash": dossier["leafCoverage"]["referenceOccurrenceInventoryHash"],
        "semanticLeaves": leaf_coverage, "referenceOccurrences": dispositions,
        "semanticLeafCount": len(leaf_coverage), "referenceOccurrenceCount": len(dispositions),
        "allInputFieldsAccounted": True})
    files[REPORT_PATH] = dumps({"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1",
        "status": "supported", "completeness": "complete_with_stream_extensions",
        "inputProfileHash": dossier_projection.PROFILE_HASH,
        "inputFiles": [{"path": path, "hash": keccak256(raw), "bytes": str(len(raw))}
            for path, raw in sorted(input_files.items())],
        "resourceCount": str(len(index)), "interviewDeclarationCount": str(len(interviews)),
        "participantRoleDeclarationCount": str(len(participants)), "crosswalkHash": CROSSWALK_HASH,
        "validationPolicyHash": VALIDATION_HASH, "claims": CLAIMS, "qualification": QUALIFICATION})
    files[PROFILE_PATH], files[CROSSWALK_PATH] = PROFILE_BYTES, CROSSWALK_BYTES
    require(len(index) <= MAX_RESOURCES and sum(map(len, files.values())) <= MAX_BYTES,
        "conservation semantic graph output bound")
    return files


def render(files, *, model_root=DEFAULT_MODEL_ROOT):
    """Project the exact four dossier outputs into deterministic graph files."""
    try:
        return _project(files, _model(str(Path(model_root).resolve())))
    except MuseumError:
        raise
    except (KeyError, IndexError, TypeError, ValueError, OverflowError, UnicodeError, RecursionError) as exc:
        raise MuseumError("malformed conservation semantic graph input") from exc


def project(files, *, model_root=DEFAULT_MODEL_ROOT):
    """Compatibility spelling for callers that treat this as a pure projection."""
    return render(files, model_root=model_root)
