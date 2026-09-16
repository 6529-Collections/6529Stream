"""Prospective token-scoped media inputs; no deployment, mint, or publication.

The caller must first establish the token on the exact Core and publish the
seed record under :attr:`TokenScope.wire_subject`.  This module then derives
the token subject independently and prepares the existing V1 media statements
with that exact token anchor.  It never turns a collection record into token
evidence and never performs a chain call.
"""
from dataclasses import dataclass

from .canonical import dumps, hex_bytes, loads, subject_id, uint
from .current_authority_capture import (alignment_payload as collection_alignment_payload,
    declaration_payload as collection_declaration_payload, review_payload as collection_review_payload)
from .current_media_inputs import payloads as collection_payloads
from .independent_wire import ZERO, require
from .review import ASSERTION_SCHEMA_BYTES, _validate
from .typed_authority_profile import ASSERTION_SCHEMA_BYTES as TYPED_ASSERTION_SCHEMA_BYTES


@dataclass(frozen=True)
class TokenScope:
    """Exact native subject and semantic anchor for one already-minted token."""

    chain_id: str
    core: str
    collection_id: str
    token_id: str
    subject_id: str
    wire_subject: tuple[int, int, int, str]
    anchor_subject: dict


def token_scope(chain_id, core, collection_id, token_id):
    """Derive the only token subject accepted by :func:`token_payloads`."""
    chain = uint(chain_id)
    collection = uint(collection_id)
    token = uint(token_id)
    require(chain > 0 and collection > 0 and token > 0, "token scope identifiers must be nonzero")
    core_bytes = hex_bytes(core, 20)
    require(any(core_bytes), "token scope Core must be nonzero")
    identifier = subject_id("token", chain_id, core, collection_id, token_id=token_id)
    return TokenScope(chain_id, core, collection_id, token_id, identifier,
        (1, collection, token, ZERO), {"kind": "token", "subjectId": identifier})


def token_payloads(*, chain_id, core, collection_id, token_id, attestor, profile_hash,
                   prior, source_digest, created_at):
    """Prepare the existing V1 media statements for one exact token seed.

    ``prior`` must be the selector returned by publication of the seed under
    the same token subject.  The returned bytes remain prospective until an
    authenticated account publishes every row under ``scope.wire_subject``.
    """
    scope = token_scope(chain_id, core, collection_id, token_id)
    require(isinstance(prior, dict) and prior.get("subjectId") == scope.subject_id,
        "token media seed selector belongs to a different subject")
    originals = collection_payloads(chain_id=uint(chain_id), attestor=attestor,
        subject_id=scope.subject_id, profile_hash=profile_hash, prior=prior,
        source_digest=source_digest, created_at=created_at)
    result = []
    expected_original = {"kind": "collection", "subjectId": scope.subject_id}
    for raw in originals:
        value = loads(raw, maximum=8192, canonical=True)
        require(value["anchorSubject"] == expected_original,
            "base media payload anchor shape changed")
        selectors = list(value["sourceRecords"])
        selectors.extend(selector for entity in value["entities"] for selector in entity["sourceRecords"])
        require(selectors and all(selector["subjectId"] == scope.subject_id for selector in selectors),
            "collection or foreign selector cannot enter token media payload")
        value["anchorSubject"] = scope.anchor_subject
        token_raw = dumps(value)
        require(len(token_raw) <= 8192, "token media payload exceeds host bound")
        _validate(ASSERTION_SCHEMA_BYTES, token_raw)
        result.append(token_raw)
    require(result, "token media payload set is empty")
    return tuple(result)


def _token_typed_payload(raw, subject_id):
    """Change only a fresh prospective typed payload's collection anchor."""
    value = loads(raw, maximum=8192, canonical=True)
    require(value["anchorSubject"] == {"kind": "collection", "subjectId": subject_id},
        "base typed payload anchor shape changed")
    selectors = list(value["sourceRecords"])
    selectors.extend(selector for entity in value["entities"] for selector in entity["sourceRecords"])
    require(selectors and all(selector["subjectId"] == subject_id for selector in selectors),
        "collection or foreign selector cannot enter token authority payload")
    value["anchorSubject"] = {"kind": "token", "subjectId": subject_id}
    result = dumps(value)
    require(len(result) <= 8192, "token authority payload exceeds host bound")
    _validate(TYPED_ASSERTION_SCHEMA_BYTES, result)
    return result


def token_declaration_payload(profile, agent, subject_id, source_selector, source_raw,
                              created_at, label):
    """Prepare a fresh synthetic-fixture Type declaration for a token seed."""
    raw, entity = collection_declaration_payload(profile, agent, subject_id, source_selector,
        source_raw, created_at, label)
    return _token_typed_payload(raw, subject_id), entity


def token_alignment_payload(profile, agent, subject_id, source_selector, source_raw,
                            declaration_selector, declaration, created_at, parsed, label,
                            type_fact):
    """Prepare a fresh automated fixture alignment under the same token subject."""
    raw, assertion = collection_alignment_payload(profile, agent, subject_id, source_selector,
        source_raw, declaration_selector, declaration, created_at, parsed, label, type_fact)
    return _token_typed_payload(raw, subject_id), assertion


def token_review_payload(profile, agent, subject_id, original_selector, original_raw,
                         original_assertion, created_at):
    """Prepare the later exact SELF review for the token fixture alignment."""
    raw = collection_review_payload(profile, agent, subject_id, original_selector, original_raw,
        original_assertion, created_at)
    return _token_typed_payload(raw, subject_id)
