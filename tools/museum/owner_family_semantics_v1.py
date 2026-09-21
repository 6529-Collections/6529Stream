"""Exact, qualified meaning for the ten native token-owner record families.

This module interprets records only after their original native wire has been
retained and after the fixed 51-document genesis plan has been admitted.  A
typed owner statement remains documentary evidence from its historical owner;
it does not establish current ownership, legal title, custody, institutional
identity, a performed activity, or an operative notice/recovery transition.
"""
from dataclasses import dataclass
from hashlib import sha256

from tools.metadata import owner_notice_profile as notice

from . import condition, institutional, loans, owner_exhibitions, valuations
from .account_profile import JCS_BYTES
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, subject_id, uint
from .genesis_registry_plan_v1 import (Plan, PROFILE_HASH as GENESIS_PLAN_PROFILE_HASH,
    admit as admit_plan, prepare as prepare_plan)
from .independent_wire import RAW_BYTES, ZERO, require
from .owner_catalog_source import FIXED_TYPES, native_hash, verify_native_wire
from .review import _validate


PROFILE = "STREAM_MUSEUM_OWNER_FAMILY_SEMANTICS_V1"
FAMILIES = tuple(FIXED_TYPES)
FAMILY_TYPES = {name: schema_id(name) for name in FAMILIES}
TYPE_FAMILIES = {value: key for key, value in FAMILY_TYPES.items()}
UNKNOWN_FAMILY = "OWNER_UNKNOWN"
SCHEMA_NAMES = {
    "ACCESSION": "STREAM_ACCESSION_V1",
    "CONDITION_REPORT": "STREAM_CONDITION_REPORT_V1",
    "EXHIBITION": "STREAM_EXHIBITION_V1",
    "LOAN": "STREAM_LOAN_V1",
    "DEACCESSION": "STREAM_DEACCESSION_V1",
    "CITATION": "STREAM_CITATION_RECORD_V1",
    "VALUATION": "STREAM_VALUATION_V1",
    "STEWARD_DESIGNATION": notice.STEWARD,
    "RECOVERY_RESPONSE": notice.RESPONSE,
    "REDEMPTION_CLAIM": "STREAM_REDEMPTION_CLAIM_V1",
}
NOTICE_PROFILES = {
    "STEWARD_DESIGNATION": notice.SP,
    "RECOVERY_RESPONSE": notice.RP,
}
JCS_NAME = "RFC8785_JCS"
MAX_ROWS, MAX_PAYLOAD = 4096, 8192
GENESIS_PLAN_MANIFEST_HASH = "0x48f2df88db34d816954a990353ee5043cb06b08f86549cc095915fc936a2136d"
SCHEMA_HASHES = {
    "ACCESSION": "0x1312b613acbd768ab1396df44bfa1a2d37f133268361df3add1ac195bad62dd9",
    "CONDITION_REPORT": "0x649bbbe1aae4b310d0c0b8ce1f9332271474f9fc341ce2e176222b7d566431e8",
    "EXHIBITION": "0xef47f6195633773a1533e3bde6e1dfee86ca3d111256353fc40f23f75c4bf8c5",
    "LOAN": "0xde7f3500bceb9e1cafdfed30bec86ec6a2d906373030cfdbcf56331867b4f4cb",
    "DEACCESSION": "0x5f8723e6680cbcbc80a05016ed73b6022695b368cfefc2a9eef561e20cb72438",
    "CITATION": "0x34786d1e4da0549fcdd6044cb936898f9b9ebfc55524d6d8602d59be2397c8a3",
    "VALUATION": "0x852e92257b952827b33dcdb0b54c58a1711681bc70f63fef2a492558d71857a7",
    "STEWARD_DESIGNATION": "0xe6d13067056e0f81773d5f66feba198a371e76bb073f7e1fd7d6dd2bc1ffc022",
    "RECOVERY_RESPONSE": "0x898ad55cd6c9e2ab7d1d7092e7c377f97b6fd0021066c672d02d31c5b5554024",
    "REDEMPTION_CLAIM": "0x2d975b84193e9cf5651539c0ae71a0f91f32ba283fe4a5808f20972463bde765",
}
CLAIMS = {
    "exactRetainedDefinitionBytesChecked": True,
    "exactPayloadSchemaCheckedForTypedRows": True,
    "currentOwnerProven": False,
    "legalTitleProven": False,
    "custodyTransferred": False,
    "institutionIdentityProven": False,
    "activityPerformed": False,
    "noticeTransitionProven": False,
    "recoveryActionStateProven": False,
    "redemptionFulfillmentProven": False,
    "registrationObservedByThisInterpreter": False,
}
QUALIFICATION = (
    "Historical native token-owner statements interpreted against exact retained prospective genesis "
    "definition bytes. Unknown families, same-family alternative schemas, URI-only commitments and "
    "invalid typed meanings remain opaque. Typed meaning does not establish current ownership, legal "
    "title, custody, named-party identity, performed activity, valuation accuracy, notice/recovery "
    "state, redemption fulfillment, live definition registration or external reference truth."
)
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "families": list(FAMILIES),
    "schemaNames": SCHEMA_NAMES, "noticeProfiles": NOTICE_PROFILES,
    "definitionPlan": {"profileHash": GENESIS_PLAN_PROFILE_HASH,
        "manifestHash": GENESIS_PLAN_MANIFEST_HASH},
    "schemaCommitments": [{"family": family, "name": SCHEMA_NAMES[family],
        "contentHash": SCHEMA_HASHES[family]} for family in FAMILIES],
    "rules": {
        "definitions": "Exact retained 51-document plan; no repository fallback or live registration inference.",
        "wire": "Record hash, token subject, embedded payload digest and native receipt identity are independently checked.",
        "meaning": "Only exact family schema plus RFC8785_JCS receipt commitments enter typed interpretation.",
        "notices": "Notice schema documents use RAW_BYTES as their registry canonicalizer, while owner payloads still use RFC8785_JCS.",
        "history": "Full native lane order is supplied separately; an earlier opaque redemption prevents a primacy conclusion."},
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


@dataclass(frozen=True)
class DefinitionSet:
    plan_hash: str
    documents: tuple[tuple[str, str, str, str, bytes], ...]
    report: dict

    def document(self, name):
        for row in self.documents:
            if row[0] == name:
                return {"name": row[0], "documentId": row[1], "contentHash": row[2],
                    "canonicalizationId": row[3], "bytes": row[4]}
        raise MuseumError("owner semantics retained definition missing: " + name)


def definitions(plan_files=None, plan_hash=None):
    """Admit the exact retained plan, or create the fixed development copy."""
    if plan_files is None:
        require(plan_hash is None, "owner semantics plan hash without retained files")
        plan = prepare_plan()
    else:
        require(plan_hash is not None, "owner semantics retained plan external pin required")
        plan = admit_plan(dict(plan_files), plan_hash)
    require(type(plan) is Plan and len(plan.documents) == 51
        and plan.manifest_hash == GENESIS_PLAN_MANIFEST_HASH,
        "owner semantics exact definition plan required")
    rows = []
    for document in plan.documents:
        metadata = document.metadata()
        rows.append((document.name, metadata["documentId"], metadata["specification"]["contentHash"],
            document.canonicalization_id, document.content))
    names = {row[0] for row in rows}
    require({JCS_NAME, *SCHEMA_NAMES.values(), *NOTICE_PROFILES.values()} <= names,
        "owner semantics required retained definitions missing")
    by_name = {row[0]: row for row in rows}
    local = {"STREAM_ACCESSION_V1": institutional.SCHEMAS["ACCESSION"],
        "STREAM_DEACCESSION_V1": institutional.SCHEMAS["DEACCESSION"],
        "STREAM_CITATION_RECORD_V1": institutional.SCHEMAS["CITATION"],
        "STREAM_REDEMPTION_CLAIM_V1": institutional.SCHEMAS["REDEMPTION_CLAIM"],
        "STREAM_CONDITION_REPORT_V1": condition.SCHEMA_BYTES,
        "STREAM_EXHIBITION_V1": owner_exhibitions.SCHEMA_BYTES,
        "STREAM_LOAN_V1": loans.SCHEMA_BYTES, "STREAM_VALUATION_V1": valuations.SCHEMA_BYTES,
        notice.STEWARD: notice.canonical(notice.schema(notice.STEWARD)),
        notice.RESPONSE: notice.canonical(notice.schema(notice.RESPONSE)),
        notice.SP: notice.canonical(notice.profile(notice.STEWARD)),
        notice.RP: notice.canonical(notice.profile(notice.RESPONSE)), JCS_NAME: JCS_BYTES}
    require(all(by_name[name][4] == raw and by_name[name][2] == keccak256(raw)
        for name, raw in local.items()), "owner semantics local validator/retained definition differs")
    require(all(by_name[SCHEMA_NAMES[family]][2] == SCHEMA_HASHES[family] for family in FAMILIES),
        "owner semantics fixed family definition commitment differs")
    report = {"profile": PROFILE, "profileHash": PROFILE_HASH, "planManifestHash": plan.manifest_hash,
        "definitionCount": "51", "familyCount": "10", "registrationObserved": False,
        "qualification": QUALIFICATION}
    return DefinitionSet(plan.manifest_hash, tuple(rows), report)


def definition_report(value):
    require(type(value) is DefinitionSet, "owner semantics definition set required")
    return dict(value.report, documents=[{"name": n, "documentId": i, "contentHash": h,
        "canonicalizationId": c, "bytes": str(len(raw))} for n, i, h, c, raw in value.documents])


def _verify_definition_set(value):
    require(type(value) is DefinitionSet and value.plan_hash == GENESIS_PLAN_MANIFEST_HASH
        and len(value.documents) == 51 and len({row[0] for row in value.documents}) == 51,
        "owner semantics exact definition set required")
    require(all(row[1] == schema_id(row[0]) and row[2] == keccak256(row[4]) for row in value.documents),
        "owner semantics retained definition identity/content differs")
    require(all(value.document(SCHEMA_NAMES[family])["contentHash"] == SCHEMA_HASHES[family]
        for family in FAMILIES), "owner semantics retained family definition differs")
    exact = {JCS_NAME: JCS_BYTES,
        notice.STEWARD: notice.canonical(notice.schema(notice.STEWARD)),
        notice.RESPONSE: notice.canonical(notice.schema(notice.RESPONSE)),
        notice.SP: notice.canonical(notice.profile(notice.STEWARD)),
        notice.RP: notice.canonical(notice.profile(notice.RESPONSE)),
        "STREAM_ACCESSION_V1": institutional.SCHEMAS["ACCESSION"],
        "STREAM_DEACCESSION_V1": institutional.SCHEMAS["DEACCESSION"],
        "STREAM_CITATION_RECORD_V1": institutional.SCHEMAS["CITATION"],
        "STREAM_REDEMPTION_CLAIM_V1": institutional.SCHEMAS["REDEMPTION_CLAIM"],
        "STREAM_CONDITION_REPORT_V1": condition.SCHEMA_BYTES,
        "STREAM_EXHIBITION_V1": owner_exhibitions.SCHEMA_BYTES,
        "STREAM_LOAN_V1": loans.SCHEMA_BYTES, "STREAM_VALUATION_V1": valuations.SCHEMA_BYTES}
    require(all(value.document(name)["bytes"] == raw for name, raw in exact.items()),
        "owner semantics exact validator definition bytes differ")


def _typed_record(original, state):
    require(type(original) is dict and all(k in original for k in
        ("recordHash", "record", "receipt", "signatureBundleHex", "authority")),
        "owner semantics original row shape")
    require(type(state) is dict and all(k in state for k in
        ("chainId", "core", "tokenId", "host", "subjectId")), "owner semantics source state shape")
    r, t = original["record"], original["receipt"]
    require(type(r) is list and len(r) == 7 and type(t) is list and len(t) == 13,
        "owner semantics native tuple shape")
    record = (r[0], r[1], r[2], (uint(r[3][0], 16), hex_bytes(r[3][1]), r[3][2]), r[4],
        hex_bytes(r[5]), uint(r[6], 64))
    receipt = (uint(t[0]), t[1], uint(t[2], 64), uint(t[3], 64), t[4], t[5], t[6],
        uint(t[7]), uint(t[8], 64), t[9], t[10], t[11], t[12])
    bundle = hex_bytes(original["signatureBundleHex"])
    require(receipt[0] == uint(state["tokenId"]) and record[1] == state["subjectId"]
        and record[1] == subject_id("token", str(uint(state["chainId"])), state["core"], "0",
            token_id=str(receipt[0])) and receipt[1] != "0x" + "00" * 20,
        "owner semantics native token subject differs")
    require(0 < len(bundle) <= MAX_PAYLOAD and keccak256(bundle) == receipt[12],
        "owner semantics signature bundle commitment differs")
    require(native_hash(uint(state["chainId"]), state["host"], state["core"], record, receipt)
        == original["recordHash"], "owner semantics native record hash differs")
    verify_native_wire(uint(state["chainId"]), state["host"], state["core"],
        uint(state["timestamp"], 64) if "timestamp" in state else receipt[2],
        original["recordHash"], receipt[0], record, receipt, bundle)
    payload = record[5]
    algorithm, digest, canonicalizer = record[3]
    require(len(payload) <= MAX_PAYLOAD and ((algorithm in (1, 2, 3, 6) and len(digest) == 32)
        or (algorithm in (4, 5) and 0 < len(digest) <= 128)), "owner semantics native content shape")
    if payload and algorithm in (1, 2):
        actual = hex_bytes(keccak256(payload)) if algorithm == 1 else sha256(payload).digest()
        require(actual == digest, "owner semantics embedded payload digest differs")
    return record, receipt, payload, algorithm, canonicalizer


def _leaf_rows(value, path=""):
    if type(value) is dict and value:
        for key, child in value.items():
            escaped = key.replace("~", "~0").replace("/", "~1")
            yield from _leaf_rows(child, path + "/" + escaped)
    elif type(value) is list and value:
        for index, child in enumerate(value):
            yield from _leaf_rows(child, path + "/" + str(index))
    else:
        kind = "null" if value is None else "boolean" if type(value) is bool else "string" if type(value) is str else "number" if type(value) in (int, float) else "array" if type(value) is list else "object"
        yield {"jsonPointer": path, "valueType": kind, "value": value,
            "disposition": "retained_stream_semantic_value"}


def _relation(predicate, value, pointer, qualification):
    return {"predicate": predicate, "value": value, "sourcePointer": pointer,
        "qualification": qualification}


def _meaning(family, value, original, state):
    common = {"kind": "historical_owner_documentary_statement", "recordHash": original["recordHash"],
        "owner": original["receipt"][1], "tokenId": str(uint(original["receipt"][0])),
        "currentOwnerProven": False, "legalTitleProven": False, "custodyTransferred": False,
        "namedPartyIdentityProven": False}
    q = "historical_owner_statement_only"
    relations = []
    if family in ("ACCESSION", "DEACCESSION", "REDEMPTION_CLAIM", "CITATION"):
        common.update({"documentId": value["recordId"], "recordedDate": value["recordedDate"],
            "supersedes": value["supersedes"]})
        relations.append(_relation("documents-token", value["tokenId"], "/tokenId", q))
    if family == "ACCESSION":
        common.update({"accessionIdentifier": value["accessionIdentifier"],
            "acquiringInstitution": value["acquiringInstitution"], "titleBinding": value["titleBinding"],
            "tokenTransferVerified": False, "instrumentValidityProven": False})
        relations += [_relation("declares-accession-identifier", value["accessionIdentifier"], "/accessionIdentifier", q),
            _relation("names-acquiring-institution", value["acquiringInstitution"], "/acquiringInstitution", "identity_unverified"),
            _relation("references-title-instrument", value["titleBinding"]["instrument"], "/titleBinding/instrument", "instrument_validity_unverified"),
            _relation("names-title-custodian", value["titleBinding"]["custodian"], "/titleBinding/custodian", "custody_not_established"),
            _relation("documents-token-transfer", value["titleBinding"]["transfer"], "/titleBinding/transfer", "transfer_not_independently_verified")]
    elif family == "DEACCESSION":
        common.update({"reasonClass": value["reasonClass"], "disposition": value["disposition"],
            "titleBinding": value["titleBinding"], "tokenTransferVerified": False})
        relations += [_relation("declares-deaccession-reason", value["reasonClass"], "/reasonClass", q),
            _relation("documents-disposition", value["disposition"], "/disposition", "referenced_bytes_not_retrieved"),
            _relation("references-title-instrument", value["titleBinding"]["instrument"], "/titleBinding/instrument", "instrument_validity_unverified"),
            _relation("names-title-custodian", value["titleBinding"]["custodian"], "/titleBinding/custodian", "custody_not_established"),
            _relation("documents-token-transfer", value["titleBinding"]["transfer"], "/titleBinding/transfer", "transfer_not_independently_verified")]
    elif family == "REDEMPTION_CLAIM":
        common.update({"program": value["program"], "entitlementDescription": value["entitlementDescription"],
            "fulfillment": value["fulfillment"], "fulfillmentProven": False, "programPrimacy": "not_evaluated"})
        relations += [_relation("claims-redemption-program", value["program"], "/program", "lane_primacy_requires_complete_order"),
            _relation("describes-entitlement", value["entitlementDescription"], "/entitlementDescription", q),
            _relation("references-fulfillment", value["fulfillment"], "/fulfillment", "fulfillment_not_verified")]
    elif family == "CITATION":
        common.update({"citedWork": value["citedWork"], "citingWork": value["citingWork"],
            "contextNote": value["contextNote"], "citedStateVerified": False})
        relations += [_relation("cites-work-state", value["citedWork"], "/citedWork", "cited_state_not_verified"),
            _relation("references-citing-work", value["citingWork"], "/citingWork", "referenced_bytes_not_retrieved")]
    elif family == "CONDITION_REPORT":
        common.update({"documentId": value["reportId"], "examinationDate": value["examinationDate"],
            "examiner": value["examiner"], "reportedFinality": value["finality"],
            "reportedFixity": value["fixity"], "reportedRender": value["render"],
            "examinationPerformedProven": False})
        relations += [_relation("reports-examination-date", value["examinationDate"], "/examinationDate", q),
            _relation("names-examiner", value["examiner"], "/examiner", "identity_and_performance_unverified"),
            _relation("reports-condition-of", value["workCitation"], "/workCitation", "cited_state_not_reverified")]
    elif family == "EXHIBITION":
        common.update({"documentId": value["exhibitionId"], "status": value["status"],
            "subject": value["subject"], "institution": value["institution"], "venue": value["venue"],
            "opening": value["opening"], "closing": value["closing"], "performanceProven": False})
        relations += [_relation("documents-exhibition-subject", value["subject"], "/subject", q),
            _relation("names-exhibiting-institution", value["institution"], "/institution", "identity_and_performance_unverified"),
            _relation("names-venue", value["venue"], "/venue", "location_not_verified"),
            _relation("declares-activity-status", value["status"], "/status", "reported_status_not_performed_activity")]
    elif family == "LOAN":
        common.update({"documentId": value["loanId"], "status": value["status"], "lender": value["lender"],
            "borrower": value["borrower"], "opening": value["opening"], "closing": value["closing"],
            "referencedRecords": {k: value[k] for k in ("insuranceValuation", "outboundConditionReport", "returnConditionReport")},
            "loanEnforcementProven": False, "custodyTransferred": False, "performedActivityProven": False})
        relations += [_relation("names-lender", value["lender"], "/lender", "identity_and_authority_unverified"),
            _relation("names-borrower", value["borrower"], "/borrower", "identity_and_authority_unverified"),
            _relation("declares-activity-status", value["status"], "/status", "reported_status_not_performed_activity"),
            _relation("references-insurance-valuation", value["insuranceValuation"], "/insuranceValuation", "referenced_record_not_joined_by_interpreter"),
            _relation("references-outbound-condition", value["outboundConditionReport"], "/outboundConditionReport", "referenced_record_not_joined_by_interpreter"),
            _relation("references-return-condition", value["returnConditionReport"], "/returnConditionReport", "referenced_record_not_joined_by_interpreter")]
    elif family == "VALUATION":
        common.update({"documentId": value["valuationId"], "status": value["status"], "scope": value["scope"],
            "basis": value["basis"], "effectiveDate": value["effectiveDate"], "confidential": value["confidential"],
            "declaredAmount": value["amount"], "currency": value["currency"], "instrument": value["instrument"],
            "monetaryAccuracyProven": False, "professionalIdentityProven": False,
            "countersignaturesVerified": False})
        relations += [_relation("declares-valuation-basis", value["basis"], "/basis", q),
            _relation("declares-valuation-amount", value["amount"], "/amount", "literal_owner_statement_no_financial_truth"),
            _relation("references-valuation-instrument", value["instrument"], "/instrument", "instrument_bytes_not_retrieved")]
    elif family == "STEWARD_DESIGNATION":
        common.update({"profileHash": value["profileHash"], "predecessor": value["predecessor"],
            "steward": value["steward"], "contactEndpoints": value["contactEndpoints"],
            "specializedState": "unknown_without_notice_evidence", "noticeStandingProven": False})
        relations += [_relation("names-notice-steward", value["steward"], "/steward", "documentary_identity_only"),
            _relation("declares-notice-endpoints", value["contactEndpoints"], "/contactEndpoints", "availability_not_verified")]
    elif family == "RECOVERY_RESPONSE":
        common.update({"profileHash": value["profileHash"], "recoveryId": value["recoveryId"],
            "recoveryManifestHash": value["recoveryManifestHash"], "response": value["response"],
            "grounds": value["grounds"], "evidenceReferences": value["evidenceReferences"],
            "specializedState": "unknown_without_notice_evidence", "scheduledProven": False,
            "timelinessProven": False, "processedProven": False, "vetoAuthorityGranted": False})
        relations += [_relation("responds-to-recovery", value["recoveryId"], "/recoveryId", "action_existence_and_schedule_unverified"),
            _relation("declares-response", value["response"], "/response", "statement_never_veto_or_execution")]
    covered = tuple(row["sourcePointer"] for row in relations)
    for key, child in value.items():
        pointer = "/" + key.replace("~", "~0").replace("/", "~1")
        if not any(pointer == prefix or pointer.startswith(prefix + "/") for prefix in covered):
            relations.append(_relation("retains-payload-field:" + key, child, pointer,
                "lossless_declared_field_only"))
    return common, relations


def _semantic(family, payload, state, original):
    if family in institutional.SCHEMAS:
        value = institutional.validate_payload(family, payload)
        require(value["tokenId"] == str(uint(state["tokenId"])), "owner semantics institutional token differs")
        if family == "CITATION":
            from .citations import parse_citation
            citation = parse_citation(value["citedWork"], require_state=True)
            require(citation["chainId"] == str(uint(state["chainId"])) and citation["core"] == state["core"]
                and citation["tokenId"] == str(uint(state["tokenId"])), "owner semantics cited work subject differs")
        if family in ("ACCESSION", "DEACCESSION"):
            transfer = value["titleBinding"]["transfer"]
            require(transfer["chainId"] == str(uint(state["chainId"])) and transfer["core"] == state["core"]
                and transfer["tokenId"] == str(uint(state["tokenId"])), "owner semantics title binding subject differs")
            if "blockNumber" in state:
                require(uint(transfer["blockNumber"]) <= uint(state["blockNumber"]),
                    "owner semantics title binding future block")
        return value
    if family == "CONDITION_REPORT":
        row = condition.admit_payload(payload)
        value, citation = row["value"], row["citation"]
        require(value["tokenId"] == str(uint(state["tokenId"])) and citation["chainId"] == str(uint(state["chainId"]))
            and citation["core"] == state["core"], "owner semantics condition subject differs")
        return value
    if family == "EXHIBITION":
        value, _ = owner_exhibitions.validate_payload(payload)
        subject = value["subject"]
        require(subject["kind"] == "token" and subject["tokenId"] == str(uint(state["tokenId"])),
            "owner semantics exhibition token subject differs")
        if "collectionId" in state:
            require(subject["collectionId"] == str(uint(state["collectionId"])),
                "owner semantics exhibition collection subject differs")
        return value
    if family == "LOAN":
        value = _validate(loans.SCHEMA_BYTES, payload)
        require(dumps(value) == payload and value["tokenId"] == str(uint(state["tokenId"])),
            "owner semantics loan token/JCS differs")
        loans._iri(value["loanId"])
        identities = {value["loanId"]: ("Activity", dumps(value))}
        for role in ("lender", "borrower"):
            party = value[role]; identifier = party["entityId"]
            loans._iri(identifier); loans._reference(party["reference"])
            require(not identifier.casefold().startswith(("urn:6529stream:account:", "eip155:")),
                "owner semantics loan party account equivalence")
            exact = (party["kind"], dumps(party))
            require(identifier not in identities or identities[identifier] == exact,
                "owner semantics loan conflicting party declaration")
            identities[identifier] = exact
            identity = party["identity"]
            if identity["kind"] in ("address", "record"):
                require(any(hex_bytes(identity["value"], 20 if identity["kind"] == "address" else 32)),
                    "owner semantics loan party identity missing")
            else:
                loans._iri(identity["value"])
                require(identity["value"].startswith("did:"), "owner semantics loan party DID differs")
        require(value["lender"]["entityId"] != value["borrower"]["entityId"], "owner semantics loan parties differ")
        bounds = [loans._date(value[key]) for key in ("opening", "closing")]
        if all(bounds) and value["opening"]["earliest"] is not None and value["closing"]["latest"] is not None:
            require(loans._instant(value["opening"]["earliest"]) <= loans._instant(value["closing"]["latest"]),
                "owner semantics loan dates differ")
        for ref in value["conditionReferences"]:
            loans._reference(ref)
        if value["returnConditions"]["reference"] is not None:
            loans._reference(value["returnConditions"]["reference"])
        for field in ("insuranceValuation", "outboundConditionReport", "returnConditionReport"):
            ref = value[field]
            if ref is not None:
                loans._reference(ref)
                require(any(hex_bytes(ref["recordHash"], 32)),
                    "owner semantics loan zero linked record")
        return value
    if family == "VALUATION":
        value = _validate(valuations.SCHEMA_BYTES, payload)
        require(dumps(value) == payload and value["tokenId"] == str(uint(state["tokenId"])),
            "owner semantics valuation token/JCS differs")
        valuations._iri(value["valuationId"]); valuations._date(value["effectiveDate"])
        require((value["scope"]["kind"] == "object") == (value["scope"]["loanId"] is None),
            "owner semantics valuation scope differs")
        if value["scope"]["loanId"] is not None:
            valuations._iri(value["scope"]["loanId"])
        valuations._reference(value["instrument"])
        require(not value["confidential"] or value["amount"] is None, "owner semantics confidential valuation figure")
        require(value["amount"] is None or value["currency"] is not None, "owner semantics valuation currency missing")
        if value["currency"] is not None:
            currency = value["currency"]
            if currency["kind"] == "ISO4217":
                require(len(currency["code"]) == 3 and all("A" <= c <= "Z" for c in currency["code"]),
                    "owner semantics valuation ISO currency differs")
            if currency["reference"] is not None:
                valuations._reference(currency["reference"])
        if value["basisReference"] is not None:
            valuations._reference(value["basisReference"])
        for ref in value["references"]:
            valuations._reference(ref)
        require(len(value["supersedes"]) == len(set(value["supersedes"]))
            and all(item != ZERO and item != original["recordHash"] for item in value["supersedes"]),
            "owner semantics valuation supersession differs")
        identities = {value["valuationId"]: ("LinguisticObject", dumps(value))}
        for role in ("issuer", "appraiser"):
            party = value[role]
            if party is None:
                continue
            valuations._iri(party["entityId"]); valuations._reference(party["reference"])
            valuations.identity(party["identity"])
            require(not party["entityId"].casefold().startswith(("urn:6529stream:account:", "eip155:")),
                "owner semantics valuation named account equivalence")
            exact = (party["kind"], dumps(party))
            require(party["entityId"] not in identities or identities[party["entityId"]] == exact,
                "owner semantics valuation conflicting party")
            identities[party["entityId"]] = exact
        counters = set()
        for counter in value["countersignatures"]:
            valuations.identity(counter["attestor"]); valuations._reference(counter["reference"])
            require(any(hex_bytes(counter["recordHash"], 32)) and counter["recordHash"] not in counters,
                "owner semantics valuation countersignature differs")
            counters.add(counter["recordHash"])
        return value
    if family in NOTICE_PROFILES:
        native_name = SCHEMA_NAMES[family]
        value = notice.validate(payload, native_name)
        require(value["subjectId"] == state["subjectId"], "owner semantics notice subject differs")
        return value
    raise MuseumError("owner semantics unsupported family")


def interpret(original, state, definition_plan):
    """Interpret one exact retained owner row; unsupported meaning stays opaque."""
    _verify_definition_set(definition_plan)
    record, receipt, payload, algorithm, canonicalizer = _typed_record(original, state)
    family = TYPE_FAMILIES.get(record[0])
    base = {"profile": PROFILE, "profileHash": PROFILE_HASH,
        "recordHash": original["recordHash"], "recordType": record[0],
        "family": family if family is not None else UNKNOWN_FAMILY,
        "status": "opaque", "semantic": None, "semanticBytesHex": "0x" + payload.hex(),
        "reason": "unsupported_owner_family" if family is None else None, "definition": None,
        "ownerMeaning": None, "relations": [], "leaves": [], "claims": CLAIMS,
        "qualification": QUALIFICATION}
    if family is None:
        return base
    schema = definition_plan.document(SCHEMA_NAMES[family])
    jcs = definition_plan.document(JCS_NAME)
    base["definition"] = {"schemaName": schema["name"], "schemaId": schema["documentId"],
        "schemaHash": schema["contentHash"], "schemaRegistryCanonicalizationId": schema["canonicalizationId"],
        "payloadCanonicalizationName": JCS_NAME, "payloadCanonicalizationId": jcs["documentId"],
        "payloadCanonicalizationHash": jcs["contentHash"], "planManifestHash": definition_plan.plan_hash,
        "registrationObserved": False}
    if record[2] != schema["documentId"] or receipt[9] != schema["contentHash"]:
        base["reason"] = "exact_family_schema_definition_not_retained"
        return base
    if canonicalizer != jcs["documentId"] or receipt[10] != jcs["contentHash"]:
        base["reason"] = "exact_payload_canonicalization_definition_not_retained"
        return base
    if algorithm not in (1, 2) or not payload:
        base["reason"] = "embedded_jcs_payload_unavailable"
        return base
    try:
        value = _semantic(family, payload, state, original)
        if family in NOTICE_PROFILES:
            profile = definition_plan.document(NOTICE_PROFILES[family])
            require(value["profileHash"] == profile["contentHash"], "owner semantics notice profile differs")
            base["definition"]["semanticProfile"] = {"name": profile["name"],
                "documentId": profile["documentId"], "contentHash": profile["contentHash"]}
        meaning, relations = _meaning(family, value, original, state)
    except (MuseumError, notice.NoticeError, KeyError, TypeError, ValueError, IndexError, UnicodeError) as exc:
        base["reason"] = "typed_payload_semantics_invalid"
        base["semanticError"] = str(exc)[:512]
        return base
    base.update(status="typed", semantic=value, reason=None, ownerMeaning=meaning,
        relations=relations, leaves=list(_leaf_rows(value)))
    return base


def interpret_all(original_rows, state, definition_plan):
    require(type(original_rows) is list and len(original_rows) <= MAX_ROWS,
        "owner semantics row denominator bound")
    seen, out = set(), []
    for original in original_rows:
        require(original.get("recordHash") not in seen, "owner semantics duplicate record occurrence")
        seen.add(original["recordHash"])
        out.append(interpret(original, state, definition_plan))
    originals = {row["recordHash"]: row for row in original_rows}
    for source, meaning in zip(original_rows, out):
        if meaning["status"] != "typed" or meaning["family"] != "LOAN":
            continue
        joins, invalid = [], False
        for field, expected in (("insuranceValuation", "VALUATION"),
                ("outboundConditionReport", "CONDITION_REPORT"),
                ("returnConditionReport", "CONDITION_REPORT")):
            ref = meaning["semantic"][field]
            if ref is None:
                joins.append({"field": field, "status": "not_declared"})
                continue
            target = originals.get(ref["recordHash"])
            if target is None:
                joins.append({"field": field, "status": "referenced_record_not_retained"})
                continue
            tr, tt = target["record"], target["receipt"]
            expected_ref = {"algorithm": str(uint(tr[3][0], 16)), "digest": tr[3][1],
                "canonicalizationId": tr[3][2]}
            valid = (TYPE_FAMILIES.get(tr[0]) == expected and tr[2] == schema_id(SCHEMA_NAMES[expected])
                and tr[1] == source["record"][1] and uint(tt[0]) == uint(source["receipt"][0])
                and ref["hash"] == expected_ref)
            joins.append({"field": field, "status": "exact_original_correspondence" if valid
                else "conflicting_retained_record", "recordHash": ref["recordHash"]})
            invalid |= not valid
        meaning["ownerMeaning"]["referencedRecordJoins"] = joins
        if invalid:
            meaning.update(status="opaque", semantic=None,
                reason="linked_original_record_correspondence_invalid", ownerMeaning=None,
                relations=[], leaves=[])
        else:
            join_by_field = {row["field"]: row["status"] for row in joins}
            pointer_fields = {"/insuranceValuation": "insuranceValuation",
                "/outboundConditionReport": "outboundConditionReport",
                "/returnConditionReport": "returnConditionReport"}
            for relation in meaning["relations"]:
                field = pointer_fields.get(relation["sourcePointer"])
                if field and join_by_field[field] == "exact_original_correspondence":
                    relation["qualification"] = "exact_original_content_correspondence_only_no_operativeness"
    return out


def annotate(meanings, lanes):
    """Bind meanings to complete native lane order and qualify redemption primacy."""
    require(type(meanings) is list and type(lanes) is list and len(meanings) <= MAX_ROWS,
        "owner semantics annotation shape/bound")
    by_hash = {row["recordHash"]: row for row in meanings}
    require(len(by_hash) == len(meanings), "owner semantics duplicate meaning")
    analyses, covered = [], set()
    for lane in lanes:
        require(type(lane) is dict and type(lane.get("records")) is list
            and len(lane["records"]) == uint(lane["count"]), "owner semantics lane denominator differs")
        hashes = lane["records"]
        require(len(hashes) == len(set(hashes)) and all(item in by_hash for item in hashes)
            and not (set(hashes) & covered),
            "owner semantics lane record denominator differs")
        require(all(by_hash[item]["recordType"] == lane["recordType"] for item in hashes),
            "owner semantics lane record type differs")
        covered.update(hashes)
        family = TYPE_FAMILIES.get(lane["recordType"], UNKNOWN_FAMILY)
        analysis = {"recordType": lane["recordType"], "family": family, "records": list(hashes),
            "state": lane.get("state"), "meaning": "documentary_history"}
        positions = {digest: index for index, digest in enumerate(hashes)}
        for index, digest in enumerate(hashes):
            row = by_hash[digest]
            if row["status"] != "typed" or "supersedes" not in row["semantic"]:
                continue
            refs = row["semantic"]["supersedes"]
            correspondence = [{"recordHash": target,
                "status": "earlier_same_family_subject" if target in positions and positions[target] < index
                    else "conflicting_or_unretained_predecessor"} for target in refs]
            if any(item["status"] != "earlier_same_family_subject" for item in correspondence):
                row.update(status="opaque", semantic=None,
                    reason="supersession_correspondence_invalid", ownerMeaning=None,
                    relations=[], leaves=[])
            else:
                row["ownerMeaning"]["supersessionCorrespondence"] = correspondence
        if family == "REDEMPTION_CLAIM":
            first_by_program, opaque_before_candidate = {}, False
            for index, digest in enumerate(hashes):
                row = by_hash[digest]
                if row["status"] != "typed":
                    opaque_before_candidate = True
                    continue
                program = row["semantic"]["program"]
                if program in first_by_program:
                    disposition = "supplemental_documentation"
                elif opaque_before_candidate:
                    disposition = "unresolved_due_to_earlier_opaque"
                else:
                    first_by_program[program] = digest; disposition = "first_supported_candidate"
                row["ownerMeaning"]["programPrimacy"] = disposition
                row["ownerMeaning"]["laneIndex"] = str(index)
            analysis.update(meaning="redemption_program_documentary_primacy",
                firstSupportedByProgram=first_by_program,
                unresolvedDueToEarlierOpaque=opaque_before_candidate)
        elif family in ("STEWARD_DESIGNATION", "RECOVERY_RESPONSE"):
            analysis.update(meaning="specialized_state_unknown_without_notice_evidence",
                perAuthorHeadComputed=False)
        analyses.append(analysis)
    require(covered == set(by_hash), "owner semantics rows outside supplied complete lanes")
    return {"rows": meanings, "laneAnalysis": analyses,
        "claims": CLAIMS, "qualification": QUALIFICATION}
