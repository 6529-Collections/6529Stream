"""Versioned PREMIS projection from verified recorded-account selected file assertions."""
from dataclasses import dataclass, replace

from .canonical import MuseumError, dumps, keccak256, loads
from .premis import FIELDS, PROFILE_HASH as FIXTURE_PROFILE_HASH, SCHEMA_SHA256, SCHEMA_URI
from .premis import PremisProjection, _file_facts, _project_selected_files, profile_document
from .recorded_selection import project_recorded, select_recorded
from .recorded_semantic import RecordedSemanticSource

MODE = "recorded_account_premis_file_projection"


def profile():
    original = profile_document()
    return {"id": "STREAM_MUSEUM_RECORDED_ACCOUNT_PREMIS_V1", "version": "1",
        "status": "prospective_unregistered_export_profile", "source": "Verified RecordedSemanticSource and exact account selection/profile; no fixture promotion.",
        "sourceScope": "Explicit selected supplemental DigitalObject identities and four selected file assertions. Not a canonical PreservationObjectRef adapter.",
        "sourceAuthority": "Historical independent-account attestor; opted-in SELF reviews remain SELF. No human identity or independent review inferred.",
        "rules": original["rules"], "limits": original["limits"],
        "targetSchemaUri": SCHEMA_URI, "targetSchemaSha256": "0x" + SCHEMA_SHA256,
        "validatorReuse": "Original PREMIS XSD validator only; the synthetic profile does not admit the recorded source.",
        "fixtureValidatorProfileHash": FIXTURE_PROFILE_HASH,
        "missingFacts": "Return unsupported with exact requested entity and missing relation/policy. Never infer facts from type, filename, captured payload size or record hash.",
        "invalidFacts": "Conflicting, qualified, malformed or out-of-range present assertions reject even if another fact is missing.",
        "selection": "Plan commits source state, registered account profile, Linked Art plan and this export profile. All four relations require single-valued conflict policy; unselected records cannot veto.",
        "coverage": "Retain complete source fields and bytes; only emitted field dispositions change. Identity and issuer retain original selected record selectors.",
        "claims": "Declared SHA-256, byte size and PRONOM identifier only; no media read, fixity event, detected format, finality or institutional conformance.",
        "remaining": ["recorded events/agents/rights", "canonical preservation objects", "recorded IIIF/LIDO", "institutional conformance"]}


PROFILE_BYTES = dumps(profile())
PROFILE_HASH = keccak256(PROFILE_BYTES)


@dataclass(frozen=True)
class RecordedPremisResult:
    projection: PremisProjection | None
    report: bytes


def _availability(linked, selection, targets, policy):
    """Pure selected-evidence checks, shared by admission tests without inventing captured records."""
    resources = {r.identifier: loads(r.content) for r in linked.resources}
    claims = {}
    for claim in selection.selected:
        value = loads(claim.assertion)
        claims.setdefault((value["subject"], value["relation"]), []).append((value, claim))
    for claim in selection.withheld:
        value = loads(claim.assertion)
        if value["subject"] in targets and value["relation"] in FIELDS.values():
            raise MuseumError("recorded PREMIS conflicting selected facts")
    issues = []
    if not targets:
        issues.append({"reasonCode": "no_selected_files"})
    for identifier in sorted(targets):
        resource = resources.get(identifier)
        if resource is None or resource.get("type") != "DigitalObject":
            issues.append({"reasonCode": "selected_digital_object_missing", "entity": identifier})
        _, _, missing = _file_facts(identifier, claims)
        issues += [row | {"reasonCode": "missing_selected_file_fact"} for row in missing]
    for relation in FIELDS.values():
        if relation not in policy["singleValuedRelations"]:
            issues.append({"reasonCode": "missing_single_valued_policy", "relation": relation})
    return issues


def project_recorded_premis(source, selection_bytes, plan_bytes, premis_plan_bytes, *,
                           selection_hash, plan_hash, premis_plan_hash, premis_profile_hash, premis_schema):
    if type(source) is not RecordedSemanticSource or source.state.mode != "recorded_state":
        raise MuseumError("recorded PREMIS requires the verified recorded account source")
    if any(record.disclosure != "public" for record in source.state.records):
        raise MuseumError("recorded PREMIS restricted source unsupported")
    if premis_profile_hash != PROFILE_HASH or keccak256(premis_plan_bytes) != premis_plan_hash:
        raise MuseumError("recorded PREMIS plan/profile hash mismatch")
    plan = loads(premis_plan_bytes, maximum=524288, canonical=True)
    if (not isinstance(plan, dict) or set(plan) != {"mode", "version", "sourceStateHash", "profileHash",
            "linkedArtPlanHash", "premisProfileHash", "objects"}
            or plan["mode"] != MODE or plan["version"] != "1"
            or plan["sourceStateHash"] != source.state.commitment or plan["profileHash"] != source.profile_hash
            or plan["linkedArtPlanHash"] != plan_hash or plan["premisProfileHash"] != PROFILE_HASH):
        raise MuseumError("recorded PREMIS plan scope mismatch")
    targets = plan["objects"]
    if (not isinstance(targets, list) or len(targets) > 512
            or any(not isinstance(v, str) for v in targets) or len(set(targets)) != len(targets)):
        raise MuseumError("recorded PREMIS object selection invalid")
    linked = project_recorded(source, selection_bytes, plan_bytes, selection_hash=selection_hash, plan_hash=plan_hash)
    selection = select_recorded(source, selection_bytes, policy_hash=selection_hash)
    issues = _availability(linked, selection, targets, loads(selection_bytes, maximum=524288))
    source_evidence = loads(linked.report, maximum=67108864)["sourceEvidence"]
    if issues:
        return RecordedPremisResult(None, dumps({"mode": MODE, "version": "1", "status": "unsupported",
            "reasonCode": "incomplete_selected_file_evidence", "issues": issues,
            "sourceStateHash": source.state.commitment, "profileHash": source.profile_hash,
            "premisProfileHash": PROFILE_HASH, "premisPlanHash": premis_plan_hash,
            "selectionPolicyHash": selection_hash, "linkedArtReportHash": keccak256(linked.report),
            "coverageHash": keccak256(linked.coverage), "sourceEvidence": source_evidence,
            "claims": {"registered": False, "bytesFixityVerified": False, "formatIdentified": False,
                       "fullPremisCrosswalk": False, "fullMuseumScope": False}}))
    projected = _project_selected_files(source.state, linked, selection, targets,
        selection_hash=selection_hash, profile_hash=source.profile_hash, premis_plan_hash=premis_plan_hash,
        premis_profile=premis_schema, mode=MODE, export_profile_hash=PROFILE_HASH)
    report = dumps(loads(projected.report, maximum=67108864) | {"status": "supported", "sourceEvidence": source_evidence})
    return RecordedPremisResult(replace(projected, report=report), report)
