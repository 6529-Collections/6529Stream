"""Exact canonical assertion selection for synthetic semantic projections."""

from dataclasses import dataclass

from .canonical import MuseumError, dumps, keccak256, loads
from .linked_art import format_checker
from .review import (BODY_SCHEMA_BYTES, REVIEW_DATATYPE, REVIEW_MAPPING_RULE, REVIEW_RELATION,
                     _read_fixture_assertion, _selector, _validate, resolve_fixture_review)
from .source import BoundSourceState, FixtureSourceAdapter, public_records


@dataclass(frozen=True)
class SelectedClaim:
    selector: bytes
    assertion: bytes
    issuer: str
    basis: str
    review_evidence: tuple[bytes, ...]


@dataclass(frozen=True)
class SelectionDiagnostic:
    selector: bytes
    reason: str


@dataclass(frozen=True)
class SemanticSelection:
    source_state_hash: str
    profile_hash: str
    policy_hash: str
    selected: tuple[SelectedClaim, ...]
    withheld: tuple[SelectedClaim, ...]
    diagnostics: tuple[SelectionDiagnostic, ...]


def select_canonical_fixture(state: BoundSourceState, policy_bytes: bytes, *, policy_hash: str,
                             profile_hash: str) -> SemanticSelection:
    if state.mode != "synthetic_fixture":
        raise MuseumError("recorded canonical selection adapter not implemented")
    if type(state.records) is not tuple or len(state.records) > 512:
        raise MuseumError("source record count limit")
    identity = loads(state.identity, maximum=16 * 1024 * 1024, canonical=True)
    if not isinstance(identity, dict):
        raise MuseumError("fixture state identity must be an object")
    expected = FixtureSourceAdapter(identity.get("fixtureName"), state.records).snapshot()
    if expected.identity != state.identity:
        raise MuseumError("fixture state commitment does not bind records")
    if keccak256(policy_bytes) != policy_hash:
        raise MuseumError("semantic selection policy hash mismatch")
    policy = loads(policy_bytes, maximum=524288, canonical=True)
    if set(policy) != {"mode", "version", "sourceStateHash", "profileHash", "sourceAuthoritySet",
                       "reviewerAuthoritySet", "singleValuedRelations", "independentReviewRequired"}:
        raise MuseumError("semantic selection policy fields mismatch")
    if (policy["mode"] != "synthetic_canonical_assertion_selection" or policy["version"] != "1"
            or policy["sourceStateHash"] != state.commitment or policy["profileHash"] != profile_hash
            or type(policy["independentReviewRequired"]) is not bool):
        raise MuseumError("semantic selection policy state or profile mismatch")
    for key in ("sourceAuthoritySet", "reviewerAuthoritySet", "singleValuedRelations"):
        values = policy[key]
        if not isinstance(values, list) or len(values) > 512 or len({dumps(v) for v in values}) != len(values):
            raise MuseumError("invalid or duplicate semantic policy entries")
        if key != "singleValuedRelations" and any(not isinstance(v, dict) for v in values):
            raise MuseumError("semantic policy selectors must be objects")
    if any(not isinstance(v, str) or not format_checker().conforms(v, "uri") for v in policy["singleValuedRelations"]):
        raise MuseumError("semantic relation identifiers required")

    sources = {}
    diagnostics = []
    for row in policy["sourceAuthoritySet"]:
        assertion, issuer, _ = _read_fixture_assertion(state, row, profile_hash)
        sources[dumps(row)] = (assertion, issuer)
    reviews = {key: [] for key in sources}
    for row in policy["reviewerAuthoritySet"]:
        review, reviewer, _ = _read_fixture_assertion(state, row, profile_hash)
        if (review["relation"] != REVIEW_RELATION or review["mappingRule"] != REVIEW_MAPPING_RULE
                or review["origin"] != "direct_statement" or review["reviewStatus"] == "withdrawn"):
            diagnostics.append(SelectionDiagnostic(dumps(row), "review statement not eligible"))
            continue
        literal = review["object"].get("literal")
        if not isinstance(literal, dict) or literal["datatype"] != REVIEW_DATATYPE:
            raise MuseumError("selected review datatype mismatch")
        body = _validate(BODY_SCHEMA_BYTES, literal["lexicalValue"].encode("utf-8"))
        key = dumps(body["assertionRecord"])
        if key not in sources:
            diagnostics.append(SelectionDiagnostic(dumps(row), "review target outside selected source set"))
            continue
        original, issuer = sources[key]
        if original["reviewStatus"] == "withdrawn":
            diagnostics.append(SelectionDiagnostic(dumps(row), "review target revision is withdrawn"))
            continue
        if original["origin"] == "direct_statement":
            diagnostics.append(SelectionDiagnostic(dumps(row), "direct source statement does not require review"))
            continue
        evidence = {"reviewRecord": row, "assertionRecord": body["assertionRecord"],
                    "assertionRevisionHash": body["assertionRevisionHash"], "profileHash": body["profileHash"],
                    "mappingRule": body["mappingRule"], "reviewer": reviewer, "reviewedAt": review["createdAt"],
                    "selfReview": reviewer == issuer}
        result = resolve_fixture_review(state, evidence, profile_hash=profile_hash,
                                        original_selector=body["assertionRecord"], mapping_rule=original["mappingRule"])
        if policy["independentReviewRequired"] and result.self_review:
            diagnostics.append(SelectionDiagnostic(dumps(row), "author-confirmed self-review does not satisfy independent policy"))
            continue
        reviews[key].append((result, dumps(evidence)))

    selected, withheld = [], []
    for key, (assertion, issuer) in sorted(sources.items()):
        if assertion["reviewStatus"] == "withdrawn":
            diagnostics.append(SelectionDiagnostic(key, "selected source revision is withdrawn"))
            continue
        basis, evidence = "direct_statement", ()
        review_rows = reviews[key]
        dispositions = {r.disposition for r, _ in review_rows}
        if assertion["origin"] != "direct_statement":
            if "reviewed" not in dispositions:
                diagnostics.append(SelectionDiagnostic(key, "mapping lacks an admitted approving review"))
                continue
            evidence = tuple(sorted(e for _, e in review_rows))
            basis = ("author_confirmed_self_review" if all(r.self_review for r, _ in review_rows)
                     else "reviewed_under_selected_policy")
        claim = SelectedClaim(key, dumps(assertion), issuer, basis, evidence)
        if assertion["origin"] != "direct_statement" and "rejected" in dispositions:
            withheld.append(claim)
            diagnostics.append(SelectionDiagnostic(key, "conflicting admitted review dispositions"))
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

    # An unselected record is retained as an opaque attributed sidecar input;
    # malformed claims inside it are not evaluated and cannot veto selection.
    selected_records = {row["recordHash"] for row in policy["sourceAuthoritySet"] + policy["reviewerAuthoritySet"]}
    for record in public_records(state):
        if record.selector.record_hash not in selected_records:
            diagnostics.append(SelectionDiagnostic(dumps(_selector(record, "")), "unselected public record; retain original sidecar bytes"))
    return SemanticSelection(state.commitment, profile_hash, policy_hash, tuple(selected),
                             tuple(sorted(withheld, key=lambda c: c.selector)),
                             tuple(sorted(diagnostics, key=lambda d: (d.selector, d.reason))))
