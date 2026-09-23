"""Versioned recorded IIIF admission, with explicit unsupported selected-evidence results."""
from dataclasses import dataclass, replace

from .canonical import MuseumError, dumps, keccak256, loads
from .iiif import FIELDS, IIIFProjection, _project_selected_presentation
from .iiif_model import PROFILE_HASH as VALIDATOR_HASH, http_id
from .recorded_premis import RecordedPremisResult, project_recorded_premis, PROFILE_HASH as PREMIS_HASH
from .recorded_selection import project_recorded, select_recorded
from .recorded_semantic import RecordedSemanticSource

MODE = "recorded_account_iiif_presentation_projection"
PROFILE_BYTES = dumps({"id": "STREAM_MUSEUM_RECORDED_ACCOUNT_IIIF_V1", "version": "1",
    "status": "prospective_unregistered_export_profile",
    "source": "Verified RecordedSemanticSource, original account selection, and recorded PREMIS file admission.",
    "sourceAuthority": "Historical account attestation and explicitly opted-in SELF review; no independent human review inferred.",
    "layout": "Plan supplies target identifiers and Canvas order only. Work/file names, association, URI, type, MIME, dimensions, attribution, rights and summary require selected source assertions.",
    "sourcePremisProfileHash": PREMIS_HASH, "fixtureValidatorProfileHash": VALIDATOR_HASH,
    "validatorReuse": "Original pinned IIIF contexts, finite schemas, URI/digest rules and exact numeric renderer; synthetic source admission is not reused.",
    "missingEvidence": "Explicit unsupported result, no Manifest. Incomplete availability reports are not validation of every present value; all complete inputs pass the original strict renderer.",
    "sourceRetention": "Original recorded bytes, selectors, account issuers and source-evidence report remain intact.",
    "limits": {"canvases": "128", "planBytes": "524288", "language": "explicit unspecified-language names only"},
    "claims": "No media retrieval, fixity verification, format detection, viewer interoperability, finality or institutional conformance."})
PROFILE_HASH = keccak256(PROFILE_BYTES)


@dataclass(frozen=True)
class RecordedIIIFResult:
    projection: IIIFProjection | None
    premis: RecordedPremisResult
    report: bytes


def _availability(linked, selection, policy, plan):
    resources = {r.identifier: loads(r.content) for r in linked.resources}
    work, files = plan["work"], [c["file"] for c in plan["canvases"]]
    claims = {}
    for claim in selection.selected:
        value = loads(claim.assertion)
        claims.setdefault((value["subject"], value["relation"]), []).append(value["object"])
    work_fields = {FIELDS[k] for k in ("attribution", "summary", "manifest-rights")}
    file_fields = set(FIELDS.values()) - {FIELDS["summary"], FIELDS["manifest-rights"]}
    for claim in selection.withheld:
        value = loads(claim.assertion)
        if ((value["subject"] == work and value["relation"] in work_fields)
                or (value["subject"] in files and value["relation"] in file_fields)):
            raise MuseumError("recorded IIIF conflicting selected facts")
    issues = []
    for identifier, kind in [(work, "PropositionalObject")] + [(f, "DigitalObject") for f in files]:
        resource = resources.get(identifier)
        if resource is None or resource.get("type") != kind:
            issues.append({"reasonCode": "selected_resource_missing", "entity": identifier, "requiredType": kind})
            continue
        names = resource.get("identified_by", [])
        if not names or any(set(n) != {"type", "content"} or n["type"] != "Name" or not n["content"] for n in names):
            issues.append({"reasonCode": "explicit_unspecified_language_name_required", "entity": identifier})
    required = [(work, name) for name in ("summary", "attribution", "manifest-rights")]
    for identifier in files:
        required += [(identifier, name) for name in ("presentation-type", "mime", "content-uri", "attribution", "rights", "presentation-of")]
        kinds = claims.get((identifier, FIELDS["presentation-type"]), [])
        if kinds and len({dumps(v) for v in kinds}) == 1:
            kind = kinds[0].get("literal", {}).get("lexicalValue")
            required += [(identifier, name) for name in {"Image": ("width", "height"),
                "Text": ("text-canvas-width", "text-canvas-height"), "Sound": ("duration",),
                "Video": ("width", "height", "duration")}.get(kind, ())]
    for entity, name in required:
        if (entity, FIELDS[name]) not in claims:
            issues.append({"reasonCode": "missing_selected_presentation_fact", "entity": entity,
                           "field": name, "relation": FIELDS[name]})
    for relation in FIELDS.values():
        if relation not in policy["singleValuedRelations"]:
            issues.append({"reasonCode": "missing_single_valued_policy", "relation": relation})
    return issues


def project_recorded_iiif(source, selection_bytes, plan_bytes, premis_plan_bytes, iiif_plan_bytes, *,
                          selection_hash, plan_hash, premis_plan_hash, premis_profile_hash, premis_schema,
                          iiif_plan_hash, iiif_profile_hash, iiif_schema):
    if type(source) is not RecordedSemanticSource or source.state.mode != "recorded_state":
        raise MuseumError("recorded IIIF requires the verified recorded account source")
    if any(record.disclosure != "public" for record in source.state.records):
        raise MuseumError("recorded IIIF restricted source unsupported")
    if iiif_profile_hash != PROFILE_HASH or keccak256(iiif_plan_bytes) != iiif_plan_hash:
        raise MuseumError("recorded IIIF plan/profile hash mismatch")
    plan = loads(iiif_plan_bytes, maximum=524288, canonical=True)
    if (not isinstance(plan, dict) or set(plan) != {"mode", "version", "sourceStateHash", "profileHash", "linkedArtPlanHash",
            "premisPlanHash", "iiifProfileHash", "work", "manifestId", "canvases"}
            or plan["mode"] != MODE or plan["version"] != "1"
            or plan["sourceStateHash"] != source.state.commitment or plan["profileHash"] != source.profile_hash
            or plan["linkedArtPlanHash"] != plan_hash or plan["premisPlanHash"] != premis_plan_hash
            or plan["iiifProfileHash"] != PROFILE_HASH or not isinstance(plan["work"], str)):
        raise MuseumError("recorded IIIF plan scope mismatch")
    canvases = plan["canvases"]
    if (not isinstance(canvases, list) or not 1 <= len(canvases) <= 128
            or any(not isinstance(c, dict) or set(c) != {"file", "canvasId", "pageId", "annotationId"}
                   or any(not isinstance(v, str) for v in c.values()) for c in canvases)):
        raise MuseumError("recorded IIIF finite Canvas plan required")
    files = [c["file"] for c in canvases]
    premis = project_recorded_premis(source, selection_bytes, plan_bytes, premis_plan_bytes,
        selection_hash=selection_hash, plan_hash=plan_hash, premis_plan_hash=premis_plan_hash,
        premis_profile_hash=premis_profile_hash, premis_schema=premis_schema)
    premis_plan = loads(premis_plan_bytes, maximum=524288, canonical=True)
    if len(set(files)) != len(files) or set(files) != set(premis_plan.get("objects", [])):
        raise MuseumError("recorded IIIF and PREMIS must select the same distinct files")
    linked = premis.projection.linked_art if premis.projection else project_recorded(source, selection_bytes, plan_bytes,
        selection_hash=selection_hash, plan_hash=plan_hash)
    ids = [http_id(plan["manifestId"])] + [http_id(c[k]) for c in canvases for k in ("canvasId", "pageId", "annotationId")]
    sidecar = loads(linked.sidecar, maximum=67108864)
    admitted = {r.identifier for r in linked.resources} | {e["id"] for e in sidecar["extensionEntities"] + sidecar["externalEntities"]}
    if len(ids) != len(set(ids)) or set(ids) & admitted:
        raise MuseumError("recorded IIIF target identities must remain distinct from source entities")
    selected = select_recorded(source, selection_bytes, policy_hash=selection_hash)
    issues = _availability(linked, selected, loads(selection_bytes, maximum=524288), plan)
    if premis.projection is None:
        issues.insert(0, {"reasonCode": "recorded_premis_unavailable", "reportHash": keccak256(premis.report),
                          "issues": loads(premis.report, maximum=67108864)["issues"]})
    evidence = loads(linked.report, maximum=67108864)["sourceEvidence"]
    if issues:
        return RecordedIIIFResult(None, premis, dumps({"mode": MODE, "version": "1", "status": "unsupported",
            "reasonCode": "incomplete_selected_presentation_evidence", "issues": issues,
            "sourceStateHash": source.state.commitment, "profileHash": source.profile_hash,
            "iiifProfileHash": PROFILE_HASH, "iiifPlanHash": iiif_plan_hash,
            "premisReportHash": keccak256(premis.report), "sourceEvidence": evidence,
            "claims": {"registered": False, "mediaRetrieved": False, "fixityVerified": False,
                       "viewerInteroperability": False, "fullIiifProfile": False, "fullMuseumScope": False}}))
    projection = _project_selected_presentation(source.state, premis.projection, selected, selection_bytes,
        premis_plan_bytes, iiif_plan_bytes, iiif_plan_hash=iiif_plan_hash, iiif_profile=iiif_schema,
        mode=MODE, source_mode="recorded_state", export_profile_hash=PROFILE_HASH,
        selection_hash=selection_hash, profile_hash=source.profile_hash, plan_hash=plan_hash,
        premis_plan_hash=premis_plan_hash, premis_profile=premis_schema)
    report = dumps(loads(projection.report, maximum=67108864) | {"status": "supported", "sourceEvidence": evidence})
    return RecordedIIIFResult(replace(projection, report=report), premis, report)
