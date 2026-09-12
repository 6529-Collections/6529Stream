"""Versioned semantic review literals; record authority stays with the adapter.

The resolver in this first implementation accepts synthetic fixture snapshots
only. It never upgrades an opaque record or a supplied reviewer name into a
verified chain statement.
"""

from dataclasses import dataclass

from .canonical import MuseumError, dumps, keccak256, loads, schema_id, uint
from .schema_inventory import EVALUATION_PROFILE_HASH, inventory_exact
from .schemas import HEX32, IRI, NAMES, definitions, enum, obj, schemas
from .source import BoundSourceState, public_records


REVIEW_RELATION = "urn:6529stream:semantic-review:v1"
REVIEW_DATATYPE = "urn:6529stream:datatype:semantic-review:v1"
REVIEW_MAPPING_RULE = "urn:6529stream:museum:mapping:review-statement-v1"
BODY_SCHEMA_NAME = "STREAM_SEMANTIC_REVIEW_BODY_V1"
BODY_SCHEMA = dict(obj({
    "assertionRecord": definitions()["selector"], "assertionRevisionHash": HEX32,
    "profileHash": HEX32, "mappingRule": IRI, "disposition": enum("reviewed", "rejected"),
}), **{"$schema": "https://json-schema.org/draft/2020-12/schema",
       "$id": "urn:6529stream:schema:" + BODY_SCHEMA_NAME,
       "x-stream-document-status": "candidate_unregistered"})
BODY_SCHEMA_BYTES = dumps(BODY_SCHEMA)
ASSERTION_SCHEMA_BYTES = dumps(schemas()[NAMES[1]])


@dataclass(frozen=True)
class ReviewResolution:
    mode: str
    original_selector: bytes
    review_selector: bytes
    assertion_revision_hash: str
    reviewer: str
    original_issuer: str
    self_review: bool
    disposition: str
    body: bytes


def _validate(schema, raw):
    inventory_exact(schema, raw, schema_hash=keccak256(schema), payload_hash=keccak256(raw),
                    evaluation_hash=EVALUATION_PROFILE_HASH)
    return loads(raw, canonical=True)


def review_literal(body):
    raw = dumps(body)
    _validate(BODY_SCHEMA_BYTES, raw)
    return {"lexicalValue": raw.decode("utf-8"), "datatype": REVIEW_DATATYPE,
            "language": None, "unit": None, "precision": None}


def _selector(record, pointer):
    s = record.selector
    return {"recordHash": s.record_hash, "subjectId": s.subject_id, "schemaId": s.schema_id,
            "schemaHash": s.schema_hash, "recordType": s.record_type, "host": s.host,
            "recorder": s.recorder, "authorizationClass": s.authorization_class,
            "recordIndex": s.record_index, "recordChainHash": s.record_chain_hash, "pointer": pointer}


def _read_fixture_assertion(state, row, profile_hash):
    # Only an exact top-level assertion can be a claim/review in this wire.
    pointer = row.get("pointer")
    if not isinstance(pointer, str) or not pointer.startswith("/assertions/"):
        raise MuseumError("review selector must select an assertion")
    index_text = pointer[len("/assertions/"):]
    index = uint(index_text, 64)
    records = [r for r in public_records(state) if r.selector.record_hash == row.get("recordHash")]
    if len(records) != 1:
        raise MuseumError("review record unavailable or ambiguous")
    record = records[0]
    if row != _selector(record, pointer):
        raise MuseumError("review record selector mismatch")
    if (record.schema != ASSERTION_SCHEMA_BYTES or record.selector.schema_id != schema_id(NAMES[1])):
        raise MuseumError("review assertion schema mismatch")
    payload = _validate(ASSERTION_SCHEMA_BYTES, record.payload)
    if (payload["profileHash"] != profile_hash
            or payload["anchorSubject"]["subjectId"] != record.selector.subject_id):
        raise MuseumError("review enclosing profile or subject mismatch")
    if index >= len(payload["assertions"]):
        raise MuseumError("review assertion unavailable")
    assertion = payload["assertions"][index]
    facts = loads(record.authority_evidence, canonical=True)
    if (facts.get("mode") != "synthetic_fixture" or facts.get("recorder") != record.selector.recorder
            or facts.get("agentIri") != assertion["assertingAgent"]
            or facts.get("recordType") != record.selector.record_type
            or facts.get("authorizationClass") != record.selector.authorization_class):
        raise MuseumError("fixture review issuer or family mismatch")
    # These are explicit fixture facts. The real adapter must derive publication
    # order from the selected chain's authenticated block/transaction/log data.
    position = facts.get("publicationPosition")
    if not isinstance(position, list) or len(position) != 3:
        raise MuseumError("fixture publication position required")
    return assertion, facts["agentIri"], tuple(uint(v, 64) for v in position)


def resolve_fixture_review(state: BoundSourceState, evidence: dict, *, profile_hash: str,
                           original_selector: dict, mapping_rule: str) -> ReviewResolution:
    if state.mode != "synthetic_fixture":
        raise MuseumError("authenticated recorded review adapter not implemented")
    # Validate the existing canonical backlink shape without adding self fields
    # to the original review body or changing the three top-level schemas.
    backlink_schema = dict(definitions()["review"], **{"$schema": BODY_SCHEMA["$schema"], "$defs": definitions()})
    _validate(dumps(backlink_schema), dumps(evidence))
    if (evidence["assertionRecord"] != original_selector or evidence["profileHash"] != profile_hash
            or evidence["mappingRule"] != mapping_rule):
        raise MuseumError("review backlink scope mismatch")
    original, issuer, original_position = _read_fixture_assertion(state, original_selector, profile_hash)
    review, reviewer, review_position = _read_fixture_assertion(state, evidence["reviewRecord"], profile_hash)
    if original_position >= review_position:
        raise MuseumError("review must follow original publication")
    revision = keccak256(dumps(original))
    if (original["mappingRule"] != mapping_rule or evidence["assertionRevisionHash"] != revision
            or original["reviewStatus"] == "withdrawn"):
        raise MuseumError("review original revision mismatch or withdrawn")
    if (review["subject"] != original["id"] or review["relation"] != REVIEW_RELATION
            or review["mappingRule"] != REVIEW_MAPPING_RULE or review["origin"] != "direct_statement"
            or review["reviewStatus"] == "withdrawn"):
        raise MuseumError("review statement type or eligibility mismatch")
    literal = review["object"].get("literal")
    if (not isinstance(literal, dict) or literal["datatype"] != REVIEW_DATATYPE
            or any(literal[key] is not None for key in ("language", "unit", "precision"))):
        raise MuseumError("review literal datatype mismatch")
    body_bytes = literal["lexicalValue"].encode("utf-8")
    body = _validate(BODY_SCHEMA_BYTES, body_bytes)
    if (body["assertionRecord"] != original_selector or body["assertionRevisionHash"] != revision
            or body["profileHash"] != profile_hash or body["mappingRule"] != mapping_rule):
        raise MuseumError("review body scope mismatch")
    is_self = reviewer == issuer
    if (evidence["reviewer"] != reviewer or evidence["reviewedAt"] != review["createdAt"]
            or evidence["selfReview"] is not is_self):
        raise MuseumError("review backlink issuer/time/self-review mismatch")
    return ReviewResolution("synthetic_fixture", dumps(original_selector), dumps(evidence["reviewRecord"]),
                            revision, reviewer, issuer, is_self, body["disposition"], body_bytes)


def main():
    import argparse
    from pathlib import Path
    parser = argparse.ArgumentParser(description="Generate the candidate semantic review body schema; no registration.")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    path = Path(__file__).resolve().parents[2] / "schemas/museum/review/review-body.schema.json"
    if args.check:
        if not path.exists() or path.read_bytes() != BODY_SCHEMA_BYTES:
            raise SystemExit("stale candidate semantic review body schema")
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(BODY_SCHEMA_BYTES)
    print(BODY_SCHEMA_NAME, keccak256(BODY_SCHEMA_BYTES), len(BODY_SCHEMA_BYTES), "candidate_unregistered")


if __name__ == "__main__":
    main()
