"""Prospective, exact-record account review selection; never proof of personhood.

Only the registered QualifiedAccountReviewProfile opts mappings and reviews into
these rules. Old registered policies and their entrypoints remain unchanged.
"""

from dataclasses import replace

from .account_profile import ACCOUNT_PREFIX
from .canonical import dumps, keccak256, loads, schema_id
from .chain_rpc import MAX_TRANSCRIPT
from .independent_wire import require
from .linked_art import format_checker
from .projection import _project_selected
from .qualified_review_profile import QualifiedAccountReviewProfile, NAMES
from .recorded_semantic import RecordedSemanticSource, CLASS, RECORD_TYPE
from .review import (BODY_SCHEMA_BYTES, REVIEW_DATATYPE, REVIEW_MAPPING_RULE,
                     REVIEW_RELATION, _selector, _validate)
from .semantic_selection import SelectedClaim, SelectionDiagnostic, SemanticSelection

MODE = "qualified_recorded_account_selection"
QUALIFICATION = "authenticated_account_under_selected_policy"
ADMISSION_FIELDS = {"selector", "profileHash", "principal", "family", "authorizationClass", "scope"}
REVIEW_FIELDS = ADMISSION_FIELDS | {"targetSelector", "targetRevisionHash", "targetProfileHash",
                                    "mappingRule", "allowSelfReview"}


def _source(source):
    require(type(source) is RecordedSemanticSource
            and type(source.profile) is QualifiedAccountReviewProfile,
            "registered qualified account source required")
    require(source.profile_hash == source.profile.profile_hash and len(source.records) <= 512,
            "qualified source profile or record bound")


def _capture_rows(source):
    rows = loads(source.capture_bytes, maximum=MAX_TRANSCRIPT, canonical=True)["records"]
    index = {row["recordHash"]: row for row in rows}
    require(len(rows) == len(index) and set(index) == set(source.records),
            "qualified source capture record set mismatch")
    return index


def source_admission(source, selector):
    """Describe authenticated facts for a policy author; does not grant a role."""
    _source(source)
    return _source_admission(source, selector, _capture_rows(source))


def _scope(source, selector, capture_rows):
    record = source.record(selector)
    kind, collection, token, object_id = capture_rows[record.selector.record_hash]["subject"]
    return {"chainId": source.anchor["chainId"], "core": source.anchor["core"],
            "host": record.selector.host, "collectionId": collection,
            "subjectKind": ("collection", "token", "media")[int(kind)],
            "subjectId": record.selector.subject_id, "tokenId": token, "objectId": object_id}


def _source_admission(source, selector, capture_rows):
    record = source.record(selector)
    assertion, principal, _ = source.assertion(selector)
    payload = source.payload(record)
    require(record.selector.record_type == RECORD_TYPE and record.selector.authorization_class == CLASS,
            "qualified source family or authorization mismatch")
    scope = _scope(source, selector, capture_rows)
    require(payload["anchorSubject"] == {"kind": scope["subjectKind"], "subjectId": scope["subjectId"]}
            and assertion["assertingAgent"] == principal, "qualified source scope or principal mismatch")
    return {"selector": selector, "profileHash": payload["profileHash"], "principal": principal,
            "family": record.selector.record_type, "authorizationClass": record.selector.authorization_class,
            "scope": scope}


def _admit(source, admission, capture_rows, *, review=False):
    fields = REVIEW_FIELDS if review else ADMISSION_FIELDS
    require(isinstance(admission, dict) and set(admission) == fields, "qualified admission fields")
    actual = _source_admission(source, admission["selector"], capture_rows)
    require(actual == {key: admission[key] for key in ADMISSION_FIELDS},
            "qualified admission differs from authenticated facts")
    return actual


def _review(source, selector, capture_rows):
    review, reviewer, position = source.assertion(selector)
    record = source.record(selector)
    require(record.selector.schema_id == schema_id(NAMES[1])
            and source.payload(record)["profileHash"] == source.profile_hash,
            "review must opt into qualified account profile")
    require(review["origin"] == "direct_statement" and review["relation"] == REVIEW_RELATION
            and review["mappingRule"] == REVIEW_MAPPING_RULE, "qualified review statement type")
    literal = review["object"].get("literal")
    require(isinstance(literal, dict) and literal["datatype"] == REVIEW_DATATYPE
            and all(literal[key] is None for key in ("language", "unit", "precision")),
            "qualified review literal type")
    raw = literal["lexicalValue"].encode("utf-8")
    body = _validate(BODY_SCHEMA_BYTES, raw)
    original, issuer, original_position = source.assertion(body["assertionRecord"])
    original_record = source.record(body["assertionRecord"])
    require(original_record.selector.schema_id == schema_id(NAMES[1])
            and source.payload(original_record)["profileHash"] == source.profile_hash,
            "review target must opt into qualified account profile")
    require(original_position < position, "qualified review must follow original publication")
    require(body["assertionRevisionHash"] == keccak256(dumps(original))
            and body["profileHash"] == source.profile_hash and body["mappingRule"] == original["mappingRule"]
            and review["subject"] == original["id"], "qualified review revision/profile/rule mismatch")
    require(_source_admission(source, selector, capture_rows)["scope"] == _source_admission(source, body["assertionRecord"], capture_rows)["scope"],
            "qualified review must retain target scope")
    return {"reviewRecord": selector, **{key: body[key] for key in
            ("assertionRecord", "assertionRevisionHash", "profileHash", "mappingRule")},
            "reviewer": reviewer, "reviewedAt": review["createdAt"], "selfReview": reviewer == issuer,
            "originalIssuer": issuer, "disposition": body["disposition"], "reviewLiteralHex": "0x" + raw.hex(),
            "originalPublicationPosition": [str(v) for v in original_position],
            "reviewPublicationPosition": [str(v) for v in position],
            "eligible": original["reviewStatus"] not in ("withdrawn", "disputed")
                        and review["reviewStatus"] not in ("withdrawn", "disputed")}


def resolve_qualified_review(source, review_selector, admission, *, profile_hash):
    """Resolve fresh evidence each time; a supplied resolution never grants authority."""
    _source(source)
    require(profile_hash == source.profile_hash, "qualified resolver profile mismatch")
    return _resolve_review(source, review_selector, admission, _capture_rows(source))


def _resolve_review(source, review_selector, admission, capture_rows):
    actual = _admit(source, admission, capture_rows, review=True)
    require(admission["selector"] == review_selector and type(admission["allowSelfReview"]) is bool,
            "qualified reviewer selector/self policy mismatch")
    result = _review(source, review_selector, capture_rows)
    require(admission["targetSelector"] == result["assertionRecord"]
            and admission["targetRevisionHash"] == result["assertionRevisionHash"]
            and admission["targetProfileHash"] == result["profileHash"]
            and admission["mappingRule"] == result["mappingRule"], "qualified review admission target mismatch")
    require(not result["selfReview"] or admission["allowSelfReview"], "SELF review requires explicit admission")
    return {**result, "policyAdmissionHash": keccak256(dumps(admission)), "qualification": QUALIFICATION,
            "scope": actual["scope"], "humanIndependenceEstablished": False}


def _entries(policy, name):
    values = policy[name]
    require(isinstance(values, list) and len(values) <= 512
            and len({dumps(value) for value in values}) == len(values), "qualified policy entries duplicated or invalid")
    return values


def select_qualified_recorded(source, policy_bytes, *, policy_hash):
    _source(source)
    require(keccak256(policy_bytes) == policy_hash, "qualified policy hash mismatch")
    policy = loads(policy_bytes, maximum=524288, canonical=True)
    require(isinstance(policy, dict) and set(policy) == {"mode", "version", "sourceStateHash", "profileHash",
            "sourceAuthoritySet", "reviewerAuthoritySet", "sourceAdmissions", "reviewAdmissions",
            "singleValuedRelations", "independentReviewRequired", "qualification"}, "qualified policy fields")
    require(policy["mode"] == MODE and policy["version"] == "1"
            and policy["sourceStateHash"] == source.state.commitment and policy["profileHash"] == source.profile_hash,
            "qualified policy scope mismatch")
    require(policy["independentReviewRequired"] is False and policy["qualification"] == QUALIFICATION,
            "independent human review is not established by account distinction")
    for name in ("sourceAuthoritySet", "reviewerAuthoritySet", "sourceAdmissions", "reviewAdmissions", "singleValuedRelations"):
        _entries(policy, name)
    require(all(isinstance(value, str) and format_checker().conforms(value, "uri")
                for value in policy["singleValuedRelations"]), "qualified relation IRI required")
    capture_rows = _capture_rows(source)
    admissions = {}
    for selector_key, admission_key, reviewing in (("sourceAuthoritySet", "sourceAdmissions", False),
                                                   ("reviewerAuthoritySet", "reviewAdmissions", True)):
        rows = {}
        for item in policy[admission_key]:
            _admit(source, item, capture_rows, review=reviewing)
            key = dumps(item["selector"])
            require(key not in rows, "qualified selector has multiple admissions")
            rows[key] = item
        require(set(rows) == {dumps(row) for row in policy[selector_key]}, "qualified admission set mismatch")
        admissions[admission_key] = rows
    claims = {key: source.assertion(loads(key)) for key in admissions["sourceAdmissions"]}
    reviews, diagnostics = {key: [] for key in claims}, []
    for key, item in admissions["reviewAdmissions"].items():
        result = _resolve_review(source, loads(key), item, capture_rows)
        target = dumps(result["assertionRecord"])
        if target not in claims:
            diagnostics.append(SelectionDiagnostic(key, "review target outside selected source set"))
        elif not result["eligible"]:
            diagnostics.append(SelectionDiagnostic(key, "review or original withdrawn/disputed; evidence retained"))
        else:
            reviews[target].append(result)
    selected, withheld = [], []
    for key, (assertion, issuer, _) in sorted(claims.items()):
        # Supplied backlinks are documentary joins, never substitutes for an admitted review.
        for backlink in assertion["reviewEvidence"]:
            result = _review(source, backlink["reviewRecord"], capture_rows)
            require(backlink["assertionRecord"] == loads(key)
                    and backlink == {field: result[field] for field in backlink}, "qualified backlink mismatch")
        if assertion["reviewStatus"] == "withdrawn":
            diagnostics.append(SelectionDiagnostic(key, "selected revision withdrawn"))
            continue
        mapping = assertion["origin"] != "direct_statement"
        if mapping:
            require(source.record(loads(key)).selector.schema_id == schema_id(NAMES[1])
                    and admissions["sourceAdmissions"][key]["profileHash"] == source.profile_hash,
                    "mapping must opt into qualified account profile")
        dispositions = {item["disposition"] for item in reviews[key]}
        evidence = tuple(sorted(dumps(item) for item in reviews[key]))
        basis = "direct_account_statement"
        if mapping:
            basis = ("account_confirmed_SELF_review" if reviews[key] and all(item["selfReview"] for item in reviews[key])
                     else "policy_admitted_account_review")
        claim = SelectedClaim(key, dumps(assertion), issuer, basis, evidence)
        if assertion["reviewStatus"] == "disputed" or (mapping and "rejected" in dispositions):
            withheld.append(claim)
            diagnostics.append(SelectionDiagnostic(key, "selected dispute or opposing review; no recency winner"))
        elif mapping and "reviewed" not in dispositions:
            diagnostics.append(SelectionDiagnostic(key, "mapping lacks an admitted approving review"))
        else:
            selected.append(claim)
    groups = {}
    for claim in selected:
        assertion = loads(claim.assertion)
        if assertion["relation"] in policy["singleValuedRelations"]:
            scope = admissions["sourceAdmissions"][claim.selector]["scope"]
            groups.setdefault((dumps(scope), assertion["subject"], assertion["relation"]), []).append(claim)
    conflicts = {claim.selector for group in groups.values()
                 if len({dumps(loads(item.assertion)["object"]) for item in group}) > 1 for claim in group}
    for claim in selected:
        if claim.selector in conflicts:
            withheld.append(claim)
            diagnostics.append(SelectionDiagnostic(claim.selector, "conflicting eligible values in exact scope"))
    selected = [claim for claim in selected if claim.selector not in conflicts]
    admitted = {row["recordHash"] for row in policy["sourceAuthoritySet"] + policy["reviewerAuthoritySet"]}
    for record in source.state.records:
        if record.selector.record_hash not in admitted:
            diagnostics.append(SelectionDiagnostic(dumps(_selector(record, "")), "unselected public record; sidecar only, no veto"))
    return SemanticSelection(source.state.commitment, source.profile_hash, policy_hash, tuple(selected),
        tuple(sorted(withheld, key=lambda claim: claim.selector)),
        tuple(sorted(diagnostics, key=lambda row: (row.selector, row.reason))))


def project_qualified_recorded(source, policy_bytes, plan_bytes, *, policy_hash, plan_hash):
    selection = select_qualified_recorded(source, policy_bytes, policy_hash=policy_hash)
    require(keccak256(plan_bytes) == plan_hash, "qualified projection plan hash mismatch")
    plan = loads(plan_bytes, maximum=524288, canonical=True)
    require(isinstance(plan, dict) and isinstance(plan.get("externalEntities"), list), "qualified external references required")
    for item in plan["externalEntities"]:
        require(isinstance(item, dict) and isinstance(item.get("id"), str), "qualified external reference shape")
        if item.get("kind") == "account" or item["id"].casefold().startswith(ACCOUNT_PREFIX):
            require(item.get("kind") == "account" and item["id"] in source.accounts,
                    "qualified external account must match historical chain and attestor")
    # The shared resource mapper is keyed by entity IRI. It must not merge
    # distinct native scopes or attach a claim to an unrelated declaration.
    require(isinstance(plan.get("entityAuthoritySet"), list) and len(plan["entityAuthoritySet"]) <= 512,
            "qualified entity selectors required")
    capture_rows, scopes = _capture_rows(source), {}

    def bind(identifier, scope):
        encoded = dumps(scope)
        require(identifier not in scopes or scopes[identifier] == encoded,
                "qualified projection entity crosses native scopes")
        scopes[identifier] = encoded

    for row in plan["entityAuthoritySet"]:
        declaration, _ = source.entity(source.state, row, source.profile_hash)
        bind(declaration["id"], _scope(source, row, capture_rows))
    for claim in selection.selected:
        assertion = loads(claim.assertion)
        bind(assertion["subject"], _scope(source, loads(claim.selector), capture_rows))
    result = _project_selected(source.state, policy_bytes, plan_bytes, selection_hash=policy_hash,
        plan_hash=plan_hash, profile_hash=source.profile_hash, profile=source.profile, selection=selection,
        entity_reader=source.entity, plan_mode="qualified_recorded_account_projection",
        sidecar_mode="qualified_recorded_account_sidecar", report_mode="qualified_recorded_account_projection",
        external_kinds=source.profile.entity_kinds | {"account"})
    report = loads(result.report, maximum=67108864, canonical=True)
    report["sourceEvidence"] = {"trustModel": "externally anchored trusted RPC; no MPT or consensus proof",
        "environment": source.anchor["environment"], "sourceCaptureHash": keccak256(source.capture_bytes),
        "publicationHash": keccak256(source.publication_bytes), "registeredInterpretationHash": keccak256(source.interpretation_bytes),
        "qualification": QUALIFICATION, "humanIdentityEstablished": False, "independentReviewEstablished": False,
        "protocolAuthorityGranted": False, "declaredLanesOnly": True}
    return replace(result, report=dumps(report))
