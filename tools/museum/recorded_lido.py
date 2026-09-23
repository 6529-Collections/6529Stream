"""Recorded LIDO admission with explicit publisher facts distinct from account issuers."""
from dataclasses import dataclass, replace

from .canonical import MuseumError, dumps, keccak256, loads
from .lido import LIDOProjection, _Evidence, _project_selected_work, source_record_id
from .lido_model import FIELDS, PREFIX, PROFILE_HASH as VALIDATOR_HASH
from .linked_art import format_checker
from .recorded_iiif import RecordedIIIFResult, project_recorded_iiif, PROFILE_HASH as IIIF_HASH
from .recorded_selection import project_recorded, select_recorded
from .recorded_semantic import RecordedSemanticSource

MODE = "recorded_account_lido_work_projection"
PUBLISHER = PREFIX + "record-publisher"
PROFILE_BYTES = dumps({"id": "STREAM_MUSEUM_RECORDED_ACCOUNT_LIDO_V1", "version": "1",
    "status": "prospective_unregistered_export_profile", "sourceIiifProfileHash": IIIF_HASH,
    "fixtureValidatorProfileHash": VALIDATOR_HASH,
    "source": "Verified RecordedSemanticSource and exact account selection, recorded PREMIS and IIIF.",
    "sourceAuthority": "Historical account attestation; selected Person/Group and publisher statements remain claims, not verified legal identity or independent human review.",
    "publisherRelation": PUBLISHER,
    "publisherRule": "Each account issuing any selected assertion/entity record must itself supply a selected work-to-publisher entity assertion. The single-valued relation selects one common locally declared Person/Group, with explicit names. Never turn account IRIs into legal bodies or infer publisher from creator.",
    "workRule": "Original explicit work type, medium, edition, credit line, creation event, creator, creation display and und document-language. Exact selected entity declarations/names and original IIIF attribution must agree.",
    "sourceProvenance": "Record IDs still bind original selectors/payload/authority. Account issuer and declared publisher remain distinct in correspondence and XML source-field provenance.",
    "missingEvidence": "Precise unsupported report; no XML. Missing IIIF/file evidence remains nested with its original report hash. No synthetic promotion or omitted requested media.",
    "limits": {"planBytes": "524288", "media": "128", "language": "explicit und with null/und source names"},
    "claims": "No creator, legal-body or rights truth verification, media retrieval, fixity, finality or institutional conformance."})
PROFILE_HASH = keccak256(PROFILE_BYTES)


@dataclass(frozen=True)
class RecordedLIDOResult:
    projection: LIDOProjection | None
    iiif: RecordedIIIFResult
    report: bytes


def _availability(state, selection, policy, entity_rows, work):
    """Authenticate consumed present facts and collect exact missing declarations/relations."""
    evidence = _Evidence(state, selection, entity_rows, [])
    issues = []

    def entity(identifier, kinds, names=False):
        row = evidence.entities.get(identifier)
        value = evidence.value(row, row["pointer"]) if row else None
        if value is None or value["kind"] not in kinds:
            issues.append({"reasonCode": "selected_entity_missing", "entity": identifier, "requiredKinds": sorted(kinds)})
            return
        if names:
            declared = [n for n in value["names"] if n["kind"] != "identifier"]
            if not declared or any(not n["value"] or n["language"] not in (None,"und") for n in declared):
                issues.append({"reasonCode": "explicit_und_compatible_names_required", "entity": identifier})

    def fact(identifier, field, is_entity=False):
        if (identifier,FIELDS[field]) not in evidence.claims:
            issues.append({"reasonCode": "missing_selected_work_fact", "entity": identifier,
                           "field": field, "relation": FIELDS[field]})
            return None
        return evidence.fact(identifier,field,entity=is_entity)[0]

    entity(work,{"abstract_work"},True)
    work_fields = {"work-type","medium","edition","credit-line","creation-event","document-language"}
    evidence.conflict(work,work_fields)
    for field in sorted(work_fields-{"creation-event","document-language"}): fact(work,field)
    language = fact(work,"document-language")
    if language is not None and language != "und":
        issues.append({"reasonCode":"unsupported_document_language","entity":work,"value":language})
    event = fact(work,"creation-event",True)
    if event is not None:
        entity(event,{"event"})
        evidence.conflict(event,{"event-type","creator","creation-display"})
        event_type = fact(event,"event-type")
        if event_type is not None and event_type != "creation":
            raise MuseumError("recorded LIDO explicit creation event required")
        fact(event,"creation-display")
        creator = fact(event,"creator",True)
        if creator is not None: entity(creator,{"person","group"},True)
    for claim in selection.withheld:
        value=loads(claim.assertion)
        if value["subject"]==work and value["relation"]==PUBLISHER:
            raise MuseumError("recorded LIDO conflicting selected publishers")
    hashes = {loads(c.selector)["recordHash"] for c in selection.selected} | {row["recordHash"] for row in entity_rows}
    issuers = {loads(r.authority_evidence)["agentIri"] for r in state.records if r.selector.record_hash in hashes}
    publishers = {}
    for value,claim in evidence.claims.get((work,PUBLISHER),[]):
        obj=value["object"]
        if set(obj)!={"entity"} or not isinstance(obj["entity"],str) or obj["entity"] in issuers:
            raise MuseumError("recorded LIDO publisher must be a distinct declared legal-body entity")
        publisher=obj["entity"]
        prior=publishers.setdefault(claim.issuer,{"entity":publisher,"proofs":[]})
        if prior["entity"]!=publisher: raise MuseumError("recorded LIDO inconsistent selected publishers")
        row=loads(claim.selector)
        prior["proofs"].append({"entity":work,"source":row,"sourcePointer":row["pointer"]+"/object/entity",
            "issuer":claim.issuer,"basis":claim.basis,"reviewEvidence":[loads(r) for r in claim.review_evidence],"rule":PUBLISHER})
    if len({row["entity"] for row in publishers.values()})>1:
        raise MuseumError("recorded LIDO common selected publisher required")
    for issuer in sorted(issuers):
        if issuer not in publishers:
            issues.append({"reasonCode":"missing_selected_publisher_assertion","entity":work,"issuer":issuer,"relation":PUBLISHER})
    for publisher in sorted({row["entity"] for row in publishers.values()}): entity(publisher,{"person","group"},True)
    for relation in (*FIELDS.values(),PUBLISHER):
        if relation not in policy["singleValuedRelations"]:
            issues.append({"reasonCode":"missing_single_valued_policy","relation":relation})
    return issues,publishers


def project_recorded_lido(source, selection_bytes, plan_bytes, premis_plan_bytes, iiif_plan_bytes, lido_plan_bytes, *,
                          lido_plan_hash, lido_profile_hash, lido_schema, **iiif_kwargs):
    if type(source) is not RecordedSemanticSource or source.state.mode != "recorded_state":
        raise MuseumError("recorded LIDO requires the verified recorded account source")
    if any(r.disclosure!="public" for r in source.state.records):
        raise MuseumError("recorded LIDO restricted source unsupported")
    if lido_profile_hash!=PROFILE_HASH or keccak256(lido_plan_bytes)!=lido_plan_hash:
        raise MuseumError("recorded LIDO plan/profile hash mismatch")
    plan=loads(lido_plan_bytes,maximum=524288,canonical=True)
    expected={"mode":MODE,"version":"1","sourceStateHash":source.state.commitment,"profileHash":source.profile_hash,
        "linkedArtPlanHash":iiif_kwargs["plan_hash"],"premisPlanHash":iiif_kwargs["premis_plan_hash"],
        "iiifPlanHash":iiif_kwargs["iiif_plan_hash"],"lidoProfileHash":PROFILE_HASH}
    if not isinstance(plan,dict) or set(plan)!=set(expected)|{"recordId"} or any(plan[k]!=v for k,v in expected.items()):
        raise MuseumError("recorded LIDO plan scope mismatch")
    if not isinstance(plan["recordId"],str) or not format_checker().conforms(plan["recordId"],"uri"):
        raise MuseumError("recorded LIDO record URI required")
    iiif=project_recorded_iiif(source,selection_bytes,plan_bytes,premis_plan_bytes,iiif_plan_bytes,**iiif_kwargs)
    linked=iiif.premis.projection.linked_art if iiif.premis.projection else project_recorded(source,selection_bytes,plan_bytes,
        selection_hash=iiif_kwargs["selection_hash"],plan_hash=iiif_kwargs["plan_hash"])
    selection=select_recorded(source,selection_bytes,policy_hash=iiif_kwargs["selection_hash"])
    layout=loads(iiif_plan_bytes,maximum=524288)
    work=layout["work"]
    sidecar=loads(linked.sidecar,maximum=67108864)
    identities={r.identifier for r in linked.resources} | {e["id"] for e in sidecar["extensionEntities"]+sidecar["externalEntities"]}
    identities |= {source_record_id(r) for r in source.state.records} | {layout["manifestId"]}
    identities |= {c[k] for c in layout["canvases"] for k in ("canvasId","pageId","annotationId")}
    if plan["recordId"] in identities:
        raise MuseumError("recorded LIDO record ID aliases source or presentation identity")
    entity_rows=loads(plan_bytes,maximum=524288)["entityAuthoritySet"]
    issues,publishers=_availability(source.state,selection,loads(selection_bytes,maximum=524288),entity_rows,work)
    if iiif.projection is None:
        issues.insert(0,{"reasonCode":"recorded_iiif_unavailable","reportHash":keccak256(iiif.report),
                         "issues":loads(iiif.report,maximum=67108864)["issues"]})
    source_evidence=loads(linked.report,maximum=67108864)["sourceEvidence"]
    if issues:
        return RecordedLIDOResult(None,iiif,dumps({"mode":MODE,"version":"1","status":"unsupported",
            "reasonCode":"incomplete_selected_lido_evidence","issues":issues,"sourceStateHash":source.state.commitment,
            "profileHash":source.profile_hash,"lidoProfileHash":PROFILE_HASH,"lidoPlanHash":lido_plan_hash,
            "iiifReportHash":keccak256(iiif.report),"sourceEvidence":source_evidence,
            "claims":{"registered":False,"creatorTruthVerified":False,"publisherTruthVerified":False,
                      "mediaRetrieved":False,"institutionalIngest":False,"fullMuseumScope":False}}))
    projection=_project_selected_work(source.state,iiif.projection,selection,selection_bytes,plan_bytes,lido_plan_bytes,
        lido_plan_hash=lido_plan_hash,lido_profile=lido_schema,mode=MODE,export_profile_hash=PROFILE_HASH,
        publishers=publishers,profile_hash=source.profile_hash,plan_hash=iiif_kwargs["plan_hash"],
        premis_plan_hash=iiif_kwargs["premis_plan_hash"],iiif_plan_hash=iiif_kwargs["iiif_plan_hash"])
    report=dumps(loads(projection.report,maximum=67108864)|{"status":"supported","sourceEvidence":source_evidence,
        "publisherAuthority":"Explicit selected account statement only; no legal identity verified."})
    return RecordedLIDOResult(replace(projection,report=report),iiif,report)
