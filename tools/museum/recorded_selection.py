"""Explicit account-only selection and model entrypoint for captured independent records."""

from dataclasses import replace

from .account_profile import ACCOUNT_PREFIX
from .canonical import MuseumError, dumps, keccak256, loads
from .identity import KINDS
from .independent_wire import require
from .linked_art import format_checker
from .projection import _project_selected
from .recorded_semantic import RecordedSemanticSource
from .review import BODY_SCHEMA_BYTES, REVIEW_DATATYPE, REVIEW_MAPPING_RULE, REVIEW_RELATION, _selector, _validate
from .semantic_selection import SelectedClaim, SelectionDiagnostic, SemanticSelection


def select_recorded(source, policy_bytes, *, policy_hash):
    require(type(source) is RecordedSemanticSource, "concrete recorded semantic source required")
    require(len(source.records) <= 512, "recorded selection record limit")
    require(keccak256(policy_bytes) == policy_hash, "recorded selection policy hash mismatch")
    policy = loads(policy_bytes, maximum=524288, canonical=True)
    require(isinstance(policy, dict) and set(policy) == {"mode", "version", "sourceStateHash", "profileHash",
        "sourceAuthoritySet", "reviewerAuthoritySet", "singleValuedRelations", "independentReviewRequired",
        "allowAccountSelfReview"}, "recorded selection policy fields")
    require(policy["mode"] == "recorded_account_selection" and policy["version"] == "1"
        and policy["sourceStateHash"] == source.state.commitment and policy["profileHash"] == source.profile_hash,
        "recorded selection scope mismatch")
    require(type(policy["independentReviewRequired"]) is bool and type(policy["allowAccountSelfReview"]) is bool,
        "recorded review policy boolean required")
    require(not policy["independentReviewRequired"], "independent human review is unsupported by account profile")
    for field in ("sourceAuthoritySet", "reviewerAuthoritySet", "singleValuedRelations"):
        values = policy[field]
        require(isinstance(values, list) and len(values) <= 512 and len({dumps(v) for v in values}) == len(values),
            "recorded selection entries invalid or duplicated")
        if field != "singleValuedRelations":
            require(all(isinstance(v, dict) for v in values), "recorded selectors must be objects")
    require(all(isinstance(v, str) and format_checker().conforms(v, "uri") for v in policy["singleValuedRelations"]),
        "recorded single-valued relation IRI required")
    sources = {dumps(row): source.assertion(row) for row in policy["sourceAuthoritySet"]}
    reviews, diagnostics = {key: [] for key in sources}, []
    for row in policy["reviewerAuthoritySet"]:
        review, reviewer, position = source.assertion(row)
        require(review["relation"] == REVIEW_RELATION and review["mappingRule"] == REVIEW_MAPPING_RULE
            and review["origin"] == "direct_statement", "selected recorded review type mismatch")
        literal = review["object"].get("literal")
        require(isinstance(literal, dict) and literal["datatype"] == REVIEW_DATATYPE
            and all(literal[f] is None for f in ("language", "unit", "precision")), "recorded review literal mismatch")
        body = _validate(BODY_SCHEMA_BYTES, literal["lexicalValue"].encode("utf-8"))
        original, issuer, original_position = source.assertion(body["assertionRecord"])
        require(reviewer == issuer, "cross-account review is unsupported; human independence unresolved")
        require(policy["allowAccountSelfReview"], "account SELF review requires explicit policy opt-in")
        require(original_position < position, "recorded review must follow exact original publication")
        require(body["assertionRevisionHash"] == keccak256(dumps(original))
            and body["profileHash"] == source.profile_hash and body["mappingRule"] == original["mappingRule"]
            and review["subject"] == original["id"], "recorded review original revision/profile/rule mismatch")
        key = dumps(body["assertionRecord"])
        if key not in sources:
            diagnostics.append(SelectionDiagnostic(dumps(row), "review target outside selected source set"))
            continue
        if original["reviewStatus"] == "withdrawn" or review["reviewStatus"] == "withdrawn":
            diagnostics.append(SelectionDiagnostic(dumps(row), "review or original revision withdrawn"))
            continue
        if original["origin"] == "direct_statement":
            diagnostics.append(SelectionDiagnostic(dumps(row), "direct account statement needs no review"))
            continue
        evidence = {"reviewRecord": row, "assertionRecord": body["assertionRecord"],
            "assertionRevisionHash": body["assertionRevisionHash"], "profileHash": body["profileHash"],
            "mappingRule": body["mappingRule"], "reviewer": reviewer, "reviewedAt": review["createdAt"],
            "selfReview": True}
        reviews[key].append((body["disposition"], dumps(evidence)))
    selected, withheld = [], []
    for key, (assertion, issuer, _) in sorted(sources.items()):
        if assertion["reviewStatus"] == "withdrawn":
            diagnostics.append(SelectionDiagnostic(key, "selected account revision withdrawn"))
            continue
        basis, evidence = "direct_account_statement", ()
        dispositions = {value[0] for value in reviews[key]}
        if assertion["origin"] != "direct_statement":
            if "reviewed" not in dispositions:
                diagnostics.append(SelectionDiagnostic(key, "mapping lacks an opted-in account SELF review"))
                continue
            basis, evidence = "account_confirmed_SELF_review", tuple(sorted(value[1] for value in reviews[key]))
        claim = SelectedClaim(key, dumps(assertion), issuer, basis, evidence)
        if assertion["origin"] != "direct_statement" and "rejected" in dispositions:
            withheld.append(claim)
            diagnostics.append(SelectionDiagnostic(key, "conflicting account SELF review dispositions"))
        else:
            selected.append(claim)
    groups = {}
    for claim in selected:
        assertion = loads(claim.assertion)
        if assertion["relation"] in policy["singleValuedRelations"]:
            groups.setdefault((assertion["subject"], assertion["relation"]), []).append(claim)
    conflicted = set()
    for group in groups.values():
        if len({dumps(loads(c.assertion)["object"]) for c in group}) > 1:
            conflicted.update(c.selector for c in group)
    for claim in selected:
        if claim.selector in conflicted:
            withheld.append(claim)
            diagnostics.append(SelectionDiagnostic(claim.selector, "conflicting eligible source values"))
    selected = [c for c in selected if c.selector not in conflicted]
    admitted = {r["recordHash"] for r in policy["sourceAuthoritySet"] + policy["reviewerAuthoritySet"]}
    for record in source.state.records:
        if record.selector.record_hash not in admitted:
            diagnostics.append(SelectionDiagnostic(dumps(_selector(record, "")), "unselected public record; retain original sidecar bytes"))
    return SemanticSelection(source.state.commitment, source.profile_hash, policy_hash, tuple(selected),
        tuple(sorted(withheld, key=lambda c: c.selector)), tuple(sorted(diagnostics, key=lambda d: (d.selector, d.reason))))


def project_recorded(source, selection_bytes, plan_bytes, *, selection_hash, plan_hash):
    selection = select_recorded(source, selection_bytes, policy_hash=selection_hash)
    require(keccak256(plan_bytes) == plan_hash, "recorded plan hash mismatch")
    plan = loads(plan_bytes, maximum=524288, canonical=True)
    require(isinstance(plan, dict) and isinstance(plan.get("externalEntities"), list), "recorded external references required")
    for item in plan["externalEntities"]:
        require(isinstance(item, dict) and isinstance(item.get("id"), str), "recorded external reference shape")
        if item.get("kind") == "account" or item["id"].casefold().startswith(ACCOUNT_PREFIX):
            require(item.get("kind") == "account" and item["id"] in source.accounts,
                "external account reference must match historical chain and attestor exactly")
    result = _project_selected(source.state, selection_bytes, plan_bytes, selection_hash=selection_hash,
        plan_hash=plan_hash, profile_hash=source.profile_hash, profile=source.profile, selection=selection,
        entity_reader=source.entity, plan_mode="recorded_account_resource_projection",
        sidecar_mode="recorded_account_projection_sidecar", report_mode="recorded_account_resource_projection",
        external_kinds=KINDS | {"account"})
    report = loads(result.report, maximum=67108864, canonical=True)
    report["sourceEvidence"] = {"trustModel": "externally anchored trusted RPC; no MPT or consensus proof",
        "environment": source.anchor["environment"], "sourceCaptureHash": keccak256(source.capture_bytes),
        "publicationHash": keccak256(source.publication_bytes), "registeredInterpretationHash": keccak256(source.interpretation_bytes),
        "recordAuthority": "historical independent attestor account", "humanIdentityEstablished": False,
        "independentReviewEstablished": False, "declaredLanesOnly": True}
    return replace(result, report=dumps(report))
