"""Exact same-account declaration continuation; no authority from a reused IRI."""
from .authority import NATIVE_KINDS, need
from .canonical import dumps, keccak256
from .review import _selector


def declaration_evidence(value, selector):
    return {"value": value, "source": selector, "declarationHash": keccak256(dumps(value))}


def lineage(source, record, entity):
    result = []; current = record; value = entity
    while value.get("continuation") is not None:
        need(len(result) < 8, "declaration continuation exceeds eight links")
        continuation = value["continuation"]; selector = continuation["selector"]
        need(selector in value["sourceRecords"], "continuation predecessor is not an entity source reference")
        prior = source._prior(current, selector)
        previous, observed = source.entity(source.state, selector, source.profile_hash)
        need(observed is prior and continuation["declarationHash"] == keccak256(dumps(previous)), "continuation predecessor hash differs")
        need(all(previous[key] == value[key] for key in ("id", "kind", "declaringAgent")), "continuation changes account, identity or kind")
        result.append(declaration_evidence(previous, selector)); current, value = prior, previous
    return result


def validate_continuations(source, record, payload):
    # Bound recursive payload admission as well as an already-cached lineage walk.
    depth = getattr(source, "_declaration_admission_depth", 0)
    need(depth <= 8, "declaration continuation admission depth exceeds eight")
    source._declaration_admission_depth = depth + 1
    try:
        for entity in payload["entities"]: lineage(source, record, entity)
    finally:
        source._declaration_admission_depth = depth


def resolve_declaration(source, assertion_selector, assertion, body):
    record = source.record(assertion_selector); payload = source.payload(record)
    reference = body["declaration"]
    if reference["scope"] == "same_record":
        selector = _selector(record, reference["pointer"])
    else:
        selector = reference["selector"]
        need(selector in payload["sourceRecords"], "prior declaration is not an assertion source reference")
        source._prior(record, selector)
    value, declared = source.entity(source.state, selector, source.profile_hash)
    need(value["id"] == assertion["subject"] and value["kind"] == NATIVE_KINDS[body["entityKind"]]
        and value["declaringAgent"] == assertion["assertingAgent"], "authority declaration account, identity or kind differs")
    evidence = declaration_evidence(value, selector)
    if reference["scope"] == "prior_record":
        need(evidence["declarationHash"] == reference["declarationHash"], "authority declaration hash differs")
    return evidence, lineage(source, declared, value)
