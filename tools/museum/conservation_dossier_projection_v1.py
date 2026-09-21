"""Deterministic semantic dossier projection of a verified conservation snapshot.

The projection preserves the exact closed conservation JSON values and their
ordered reference occurrences.  It does not retrieve a reference, turn an
identity URI into a person, or infer consent, interview performance, archival
delivery, current eligibility, or legal authority.
"""

from copy import deepcopy

from tools.metadata import conservation_profile as conservation

from . import public_conservation_source as source
from .canonical import MuseumError, dumps, hex_bytes, keccak256, uint
from .independent_wire import ZERO, require


PROFILE = "STREAM_MUSEUM_CONSERVATION_DOSSIER_PROJECTION_V1"
CLAIMS = {
    "sourceSnapshotProfileChecked": True,
    "semanticPayloadsRevalidated": True,
    "exactSemanticFieldsPreserved": True,
    "arrayOrderAndDuplicatesPreserved": True,
    "nullAndEmptyContainersPreserved": True,
    "artistEstateLineagesKeptSeparate": True,
    "historicalSelectionAndCurrentEligibilityKeptSeparate": True,
    "parentInterviewRecordsJoined": True,
    "completeReferenceOccurrenceInventory": True,
    "completeSemanticLeafLedger": True,
    "referenceContentRetrieved": False,
    "identityPersonInferred": False,
    "interviewPerformanceInferred": False,
    "consentInferred": False,
    "mediaFormatDetected": False,
    "archiveDeliveryProven": False,
    "currentAuthorityProven": False,
    "linkedArtConformanceClaimed": False,
}
QUALIFICATION = (
    "Deterministic plain-JSON projection of an independently replay-validated "
    "STREAM_MUSEUM_PUBLIC_CONSERVATION_SOURCE_V1 snapshot. Exact declared "
    "semantics, history, current-eligibility observations, reference occurrences "
    "and selected catalog witnesses are retained. References remain declarations: "
    "no URI is retrieved, no identity reference becomes a Person, and no consent, "
    "performed interview, file-format detection, archival delivery, current "
    "authority, tier, sale-floor or Linked Art conformance is inferred."
)
OUTPUTS = (
    "conservation/dossier.json",
    "conservation/reference-occurrences.json",
    "conservation/semantic-leaves.json",
    "conservation/projection-profile.json",
)
PROFILE_BYTES = dumps({
    "name": PROFILE,
    "version": "1",
    "status": "prospective_unregistered_projection_profile",
    "inputProfile": source.PROFILE,
    "inputProfileHash": source.PROFILE_HASH,
    "nativeSourceRevision": source.SOURCE_REVISION,
    "outputs": list(OUTPUTS),
    "rules": [
        "Input must be the closed decoded snapshot produced by the frozen public conservation source profile.",
        "Every original payload is revalidated against its exact conservation family and retained catalog bytes before projection.",
        "Record payload objects are copied without key omission or scalar coercion; arrays retain occurrence order and duplicates.",
        "Artist and estate lineages remain separate. Historical selected rows and source-block current eligibility remain separate observations.",
        "Every closed Reference occurrence receives an ordered source-record selector and RFC 6901 JSON Pointer. Reference bytes are not retrieved.",
        "Every semantic scalar, null, and empty object or array in records and selected catalog documents appears in the leaf ledger.",
    ],
    "claims": CLAIMS,
    "qualification": QUALIFICATION,
})
PROFILE_HASH = keccak256(PROFILE_BYTES)

FAMILY_BY_KIND = {
    0: ("intent", conservation.INTENT),
    1: ("intent_waiver", conservation.WAIVER),
    2: ("interview", conservation.INTERVIEW),
}
EXPECTED_KEYS = {
    "anchorHash", "binding", "claims", "currentAssociation", "documents",
    "historyCoverage", "identity", "mode", "preparations", "profile",
    "profileHash", "qualification", "records", "remaining", "scopes",
    "source", "sourceReviewCommit", "transcriptHash", "version",
}


def _pointer(parts):
    return "" if not parts else "/" + "/".join(
        str(part).replace("~", "~0").replace("/", "~1") for part in parts
    )


def _reference_relation(parts):
    names = tuple(str(part) for part in parts)
    if "display" in names:
        return "display_statement"
    if "waiverStatement" in names:
        return "intent_waiver_statement"
    if names[-2:] == ("interview", "statement"):
        return "interview_waiver_statement"
    if names[-2:] == ("interview", "payload"):
        return "interview_payload"
    if "instrument" in names and names[-1] == "document":
        return "interview_instrument_document"
    if "participants" in names and names[-1] == "identity":
        return "participant_identity"
    if "captures" in names and names[-1] == "content":
        return "capture_content"
    if "transcript" in names and names[-1] == "content":
        return "transcript_content"
    if names[-1] == "specification":
        return "format_specification"
    if names[-1] == "variabilityTolerances":
        return "variability_tolerances"
    if names[-1] == "dependencyAging":
        return "dependency_aging"
    if names[-1] == "significantProperties":
        return "significant_properties"
    return "declared_reference"


def _walk(value, parts=()):
    """Yield every semantic leaf and every exact closed Reference occurrence."""
    references = []
    leaves = []
    if isinstance(value, dict):
        if set(value) == {"hash", "uri"} and isinstance(value["hash"], dict):
            references.append((parts, value))
        if not value:
            leaves.append((parts, "empty_object", {}))
        else:
            for key, child in value.items():
                child_references, child_leaves = _walk(child, parts + (key,))
                references.extend(child_references)
                leaves.extend(child_leaves)
    elif isinstance(value, list):
        if not value:
            leaves.append((parts, "empty_array", []))
        else:
            for index, child in enumerate(value):
                child_references, child_leaves = _walk(child, parts + (index,))
                references.extend(child_references)
                leaves.extend(child_leaves)
    else:
        kind = "null" if value is None else "boolean" if type(value) is bool else (
            "integer" if type(value) is int else "string"
        )
        require(value is None or type(value) in (bool, int, str), "conservation semantic scalar type")
        leaves.append((parts, kind, value))
    return references, leaves


def _selector(snapshot, row):
    record, receipt = row["record"], row["receipt"]
    return {
        "chainId": snapshot["source"]["chainId"],
        "core": snapshot["source"]["core"],
        "host": snapshot["source"]["host"],
        "collectionId": snapshot["source"]["collectionId"],
        "recordHash": row["recordHash"],
        "recordType": record[0],
        "subjectId": record[1],
        "schemaId": record[4],
        "canonicalizationId": record[2][2],
        "originalURI": record[3],
        "recordIndex": receipt[4],
        "recordedAt": receipt[3],
    }


def _catalog_uses(value):
    if "transcript" not in value:
        return []
    rows = [("transcript", None, value["transcript"])]
    rows.extend(("capture", index, row["payload"]) for index, row in enumerate(value["captures"]))
    result = []
    for kind, index, payload in rows:
        form = payload["format"]
        if form["kind"] != "catalog":
            continue
        parts = ("transcript", "format") if kind == "transcript" else (
            "captures", index, "payload", "format"
        )
        result.append((parts, form["catalog"]))
    return result


def _semantic_record(snapshot, row, index, documents, catalog_documents, catalog_order):
    require(type(row) is dict and row.get("recordHash") not in (None, ZERO), "conservation dossier original record")
    require(type(row.get("nativeEvidence")) is list and len(row["nativeEvidence"]) == 10,
        "conservation dossier native record evidence")
    kind = uint(row["nativeEvidence"][1])
    require(kind in FAMILY_BY_KIND, "conservation dossier record family")
    family_label, family = FAMILY_BY_KIND[kind]
    raw = hex_bytes(row["payloadHex"])
    require(0 < len(raw) <= 8192 and keccak256(raw) == row["nativeEvidence"][2],
        "conservation dossier payload bytes/hash")
    uses = _catalog_uses(row["value"]) if kind == 2 else []
    require(len(uses) == len(row["catalogs"]), "conservation dossier catalog occurrence denominator")
    witnesses = {}
    catalog_occurrences = []
    for occurrence, ((parts, info), pin) in enumerate(zip(uses, row["catalogs"])):
        require(type(pin) is list and len(pin) == 3 and info["documentId"] == pin[0]
            and info["documentHash"] == pin[1], "conservation dossier catalog occurrence selector")
        document = documents.get(pin[0])
        require(document is not None, "conservation dossier selected catalog document missing")
        document_raw = hex_bytes(document["payloadHex"])
        require(len(document_raw) == int(pin[2]) and keccak256(document_raw) == pin[1],
            "conservation dossier selected catalog bytes")
        witnesses[info["name"]] = document_raw
        key = (pin[0], pin[1])
        if key not in catalog_documents:
            catalog_value = conservation.validate(document_raw, conservation.CATALOG)
            catalog_documents[key] = {
                "documentId": pin[0],
                "documentHash": pin[1],
                "byteLength": pin[2],
                "value": deepcopy(catalog_value),
                "evidence": deepcopy(document),
            }
            catalog_order.append(key)
        catalog_occurrences.append({
            "occurrence": occurrence,
            "jsonPointer": _pointer(("records", index, "semantic") + parts),
            "documentId": pin[0],
            "documentHash": pin[1],
            "byteLength": pin[2],
            "name": info["name"],
        })
    parsed = conservation.validate(raw, family, witnesses)
    require(parsed == row["value"], "conservation dossier decoded semantic payload differs")
    publication_class = uint(row["nativeEvidence"][8][5])
    require(publication_class in (1, 3), "conservation dossier original publication class")
    selector = _selector(snapshot, row)
    provenance = {key: deepcopy(value) for key, value in row.items() if key != "value"}
    return {
        "index": index,
        "family": family_label,
        "schemaName": family,
        "originalPublicationClass": str(publication_class),
        "originalPublicationOrigin": "artist" if publication_class == 1 else "estate",
        "selector": selector,
        "semantic": deepcopy(parsed),
        "catalogOccurrences": catalog_occurrences,
        "provenance": provenance,
    }


def _lineage(scope_name, origin_name, lane, records):
    require(type(lane) is dict and set(lane) == {
        "status", "current", "history", "catalogs", "events", "currentEligibility"
    }, "conservation dossier lineage shape")
    expected_origin = 0 if origin_name == "artist" else 1
    history, catalogs, events = lane["history"], lane["catalogs"], lane["events"]
    require(type(history) is list and len(history) == len(catalogs) == len(events),
        "conservation dossier lineage occurrence denominator")
    revisions = []
    for offset, (selection, pins, event) in enumerate(zip(history, catalogs, events)):
        require(type(selection) is list and len(selection) == 13 and uint(selection[2]) == expected_origin
            and selection[0][0] in records and selection[9] == str(offset + 1),
            "conservation dossier selected revision")
        status = uint(selection[3])
        parent = records[selection[0][0]]
        require(status in (0, 1) and parent["family"] in ("intent", "intent_waiver"),
            "conservation dossier selected parent/interview status")
        entry = parent["semantic"]["interview"]
        require((status == 0 and entry["kind"] == "present"
            and selection[4][0] == entry["record"]["recordHash"])
            or (status == 1 and entry["kind"] == "interview_waived" and selection[4][0] == ZERO),
            "conservation dossier selected parent/interview relation")
        interview_hash = selection[4][0]
        revisions.append({
            "revision": selection[9],
            "origin": origin_name,
            "recordHash": selection[0][0],
            "recordFamily": records[selection[0][0]]["family"],
            "predecessorRecordHash": None if selection[7] == ZERO else selection[7],
            "interviewRecordHash": None if interview_hash == ZERO else interview_hash,
            "interviewMode": "waived" if status == 1 else "present",
            "selectedAt": selection[10],
            "selectionHash": selection[12],
            "catalogPins": deepcopy(pins),
            "selection": deepcopy(selection),
            "event": deepcopy(event),
        })
    require((lane["status"] == "selected") == bool(history), "conservation dossier lineage status/history")
    if history:
        require(lane["current"] == history[-1], "conservation dossier lineage current head")
    return {
        "origin": origin_name,
        "status": lane["status"],
        "current": deepcopy(lane["current"]),
        "currentEligibility": deepcopy(lane["currentEligibility"]),
        "revisions": revisions,
    }


def _project(snapshot):
    require(type(snapshot) is dict and set(snapshot) == EXPECTED_KEYS,
        "conservation dossier closed source snapshot")
    require(snapshot["profile"] == source.PROFILE and snapshot["profileHash"] == source.PROFILE_HASH
        and snapshot["version"] == "1" and snapshot["sourceReviewCommit"] == source.SOURCE_REVISION
        and snapshot["claims"] == source.CLAIMS and snapshot["qualification"] == source.QUALIFICATION,
        "conservation dossier source profile/revision")
    require(snapshot["mode"] in ("synthetic_fixture", "caller_admitted_rpc")
        and type(snapshot["records"]) is list and type(snapshot["documents"]) is list
        and type(snapshot["preparations"]) is list, "conservation dossier source collections")

    documents = {}
    for row in snapshot["documents"]:
        require(type(row) is dict and row.get("documentId") not in documents,
            "conservation dossier document identity")
        documents[row["documentId"]] = row
    catalog_documents, catalog_order = {}, []
    records = []
    by_hash = {}
    for index, row in enumerate(snapshot["records"]):
        projected = _semantic_record(snapshot, row, index, documents, catalog_documents, catalog_order)
        digest = projected["selector"]["recordHash"]
        require(digest not in by_hash, "conservation dossier duplicate original record")
        records.append(projected)
        by_hash[digest] = projected

    relationships = []
    for row in records:
        entry = row["semantic"].get("interview")
        if entry is None or entry["kind"] != "present":
            continue
        child_hash = entry["record"]["recordHash"]
        child = by_hash.get(child_hash)
        require(child is not None and child["family"] == "interview"
            and child["selector"]["subjectId"] == row["selector"]["subjectId"]
            and entry["record"] == {
                "chainId": snapshot["source"]["chainId"],
                "core": snapshot["source"]["core"],
                "host": snapshot["source"]["host"],
                "recordHash": child_hash,
                "schemaId": child["selector"]["schemaId"],
                "profileHash": child["semantic"]["profileHash"],
            },
            "conservation dossier parent/interview original join")
        relationships.append({
            "kind": "parent_interview",
            "parentRecordHash": row["selector"]["recordHash"],
            "interviewRecordHash": child_hash,
            "payloadReference": deepcopy(entry["payload"]),
            "locator": deepcopy(entry["record"]),
        })

    scopes = []
    require(type(snapshot["scopes"]) is dict and set(snapshot["scopes"]) == {"collection", "token"},
        "conservation dossier exact scopes")
    for scope_name in ("collection", "token"):
        row = snapshot["scopes"][scope_name]
        require(type(row) is dict and set(row) == {"subjectId", "origins", "lock", "lockEvent"}
            and set(row["origins"]) == {"artist", "estate"}, "conservation dossier scope shape")
        scopes.append({
            "scope": scope_name,
            "subjectId": row["subjectId"],
            "lock": deepcopy(row["lock"]),
            "lockEvent": deepcopy(row["lockEvent"]),
            "lineages": [_lineage(scope_name, name, row["origins"][name], by_hash)
                for name in ("artist", "estate")],
        })

    catalog_rows = [catalog_documents[key] for key in catalog_order]
    dossier = {
        "profile": PROFILE,
        "profileHash": PROFILE_HASH,
        "version": "1",
        "source": {
            "profile": snapshot["profile"],
            "profileHash": snapshot["profileHash"],
            "sourceReviewCommit": snapshot["sourceReviewCommit"],
            "anchorHash": snapshot["anchorHash"],
            "transcriptHash": snapshot["transcriptHash"],
            "mode": snapshot["mode"],
            "sourceState": deepcopy(snapshot["source"]),
            "identity": deepcopy(snapshot["identity"]),
            "binding": deepcopy(snapshot["binding"]),
            "historyCoverage": deepcopy(snapshot["historyCoverage"]),
        },
        "currentAssociation": deepcopy(snapshot["currentAssociation"]),
        "scopes": scopes,
        "records": records,
        "parentInterviewRelationships": relationships,
        "preparations": deepcopy(snapshot["preparations"]),
        "catalogDocuments": catalog_rows,
        "sourceClaims": deepcopy(snapshot["claims"]),
        "sourceQualification": snapshot["qualification"],
        "sourceRemaining": deepcopy(snapshot["remaining"]),
        "claims": CLAIMS,
        "qualification": QUALIFICATION,
    }

    references = []
    leaves = []
    per_root = []
    for index, row in enumerate(records):
        selector = row["selector"]
        found, covered = _walk(row["semantic"])
        start = len(leaves)
        for parts, kind, value in covered:
            leaves.append({
                "sourceKind": "record",
                "sourceId": selector["recordHash"],
                "jsonPointer": _pointer(("records", index, "semantic") + parts),
                "valueType": kind,
                "value": deepcopy(value),
            })
        for parts, reference in found:
            references.append({
                "occurrence": len(references),
                "sourceKind": "record",
                "sourceRecord": deepcopy(selector),
                "dossierPath": "conservation/dossier.json",
                "jsonPointer": _pointer(("records", index, "semantic") + parts),
                "relation": _reference_relation(parts),
                "hash": deepcopy(reference["hash"]),
                "uri": reference["uri"],
            })
        per_root.append({
            "sourceKind": "record",
            "sourceId": selector["recordHash"],
            "semanticHash": keccak256(dumps(row["semantic"])),
            "leafCount": len(leaves) - start,
        })
    for index, row in enumerate(catalog_rows):
        found, covered = _walk(row["value"])
        start = len(leaves)
        for parts, kind, value in covered:
            leaves.append({
                "sourceKind": "catalog_document",
                "sourceId": row["documentId"],
                "jsonPointer": _pointer(("catalogDocuments", index, "value") + parts),
                "valueType": kind,
                "value": deepcopy(value),
            })
        for parts, reference in found:
            references.append({
                "occurrence": len(references),
                "sourceKind": "catalog_document",
                "sourceRecord": None,
                "catalogSelector": {"documentId": row["documentId"], "documentHash": row["documentHash"]},
                "dossierPath": "conservation/dossier.json",
                "jsonPointer": _pointer(("catalogDocuments", index, "value") + parts),
                "relation": "catalog_format_specification",
                "hash": deepcopy(reference["hash"]),
                "uri": reference["uri"],
            })
        per_root.append({
            "sourceKind": "catalog_document",
            "sourceId": row["documentId"],
            "semanticHash": keccak256(dumps(row["value"])),
            "leafCount": len(leaves) - start,
        })

    leaf_body = {
        "profileHash": PROFILE_HASH,
        "scope": "all_record_semantics_and_selected_catalog_documents",
        "roots": per_root,
        "leaves": leaves,
    }
    leaf_hash = keccak256(dumps(leaf_body))
    reference_body = {
        "profileHash": PROFILE_HASH,
        "scope": "all_closed_reference_occurrences_in_projected_semantics",
        "occurrences": references,
    }
    reference_hash = keccak256(dumps(reference_body))
    coverage = {
        "recordSemanticRoots": len(records),
        "catalogSemanticRoots": len(catalog_rows),
        "semanticLeafCount": len(leaves),
        "nullLeafCount": sum(row["valueType"] == "null" for row in leaves),
        "emptyArrayCount": sum(row["valueType"] == "empty_array" for row in leaves),
        "emptyObjectCount": sum(row["valueType"] == "empty_object" for row in leaves),
        "referenceOccurrenceCount": len(references),
        "semanticLeafLedgerHash": leaf_hash,
        "referenceOccurrenceInventoryHash": reference_hash,
        "complete": True,
    }
    dossier["leafCoverage"] = coverage
    return {
        OUTPUTS[0]: dumps(dossier),
        OUTPUTS[1]: dumps(reference_body),
        OUTPUTS[2]: dumps(leaf_body),
        OUTPUTS[3]: PROFILE_BYTES,
    }


def project(snapshot_dict):
    """Project one decoded, independently replay-validated conservation snapshot."""
    try:
        return _project(snapshot_dict)
    except MuseumError:
        raise
    except (KeyError, IndexError, TypeError, ValueError, OverflowError, UnicodeError, RecursionError) as exc:
        raise MuseumError("malformed conservation dossier projection input") from exc
