"""Synthetic original Artist statements for the physical Production consumer.

Every mutation is applied before native Metadata/Artist records, Store chunks,
events and RPC transcripts are constructed.  The resulting attribution package
uses the production source readers and dossier builder.  These generated RPC
answers prove neither an actual deployment nor a physical production event.
"""

from copy import deepcopy

from . import attribution_dossier
from .canonical import MuseumError, dumps, keccak256, loads
from .chain_rpc import MAX_TRANSCRIPT
from .native_attribution_semantics import PROFILE
from .test_native_attribution_source import Fixture


RELATION = "urn:6529stream:museum:physical-production:v1"
RULE = RELATION + ":original-artist-statement"
DATATYPE = RELATION + ":body"
OBJECT_ID = "urn:fixture:physical-production:object"
EVENT_ID = "urn:fixture:physical-production:event"


def _entity(identifier, kind, name, assertion, sources):
    return {"id": identifier, "kind": kind,
        "names": [{"value": name, "language": "en", "kind": "preferred"}],
        "declaringAgent": assertion["assertingAgent"],
        "sourceRecords": deepcopy(sources), "predecessors": []}


def _pin(value, index):
    entity = value["entities"][index]
    return {"id": entity["id"], "pointer": "/entities/" + str(index),
        "hash": keccak256(dumps(entity))}


def set_body(assertion, body):
    """Encode a source-original literal, before any native record exists."""
    assertion["object"] = {"literal": {"lexicalValue": dumps(body).decode("utf-8"),
        "datatype": DATATYPE, "language": None, "unit": None, "precision": None}}


def supplied(*, status="completed", object_kind="physical_object", event_kind="event",
             review_status="unreviewed", origin="direct_statement", conflict=False,
             declaration_collision=False, selected=None, single_valued=False,
             rotated=False, disputed=False, mutate_body=None, mutate_payload=None):
    """Return a real, synthetic attribution package and its original values.

    ``selected`` is an optional sequence of original assertion indices.  A
    conflict adds an otherwise valid second original assertion with a different
    status.  A declaration collision selects two different local declarations
    with the same IRI.  Callbacks edit only the original pre-publication payload.
    No production verifier is replaced or bypassed.
    """
    if conflict and declaration_collision:
        raise MuseumError("fixture conflict variants must be requested separately")

    def setup(value):
        assertion = value["assertions"][0]
        value["entities"] = [
            _entity(OBJECT_ID, object_kind, "Original physical print", assertion, value["sourceRecords"]),
            _entity(EVENT_ID, event_kind, "Recorded production statement", assertion, value["sourceRecords"]),
        ]
        body = {"version": "1", "kind": "physical_production", "status": status,
            "physicalObject": _pin(value, 0), "productionEvent": _pin(value, 1)}
        assertion.update(id="urn:fixture:physical-production:assertion:0", subject=OBJECT_ID,
            relation=RELATION, mappingRule=RULE, origin=origin, reviewStatus=review_status,
            rationale="Synthetic original Artist statement; no observed physical event is claimed.")
        if mutate_body is not None:
            mutate_body(body)
        set_body(assertion, body)
        if conflict or declaration_collision:
            second = deepcopy(assertion)
            second["id"] = "urn:fixture:physical-production:assertion:1"
            other_body = deepcopy(body)
            if declaration_collision:
                other = deepcopy(value["entities"][0])
                other["names"][0]["value"] = "Different original declaration with the same IRI"
                value["entities"].append(other)
                other_body["physicalObject"] = _pin(value, 2)
            else:
                other_body["status"] = "planned" if status == "completed" else "completed"
            set_body(second, other_body)
            value["assertions"].append(second)
        if mutate_payload is not None:
            mutate_payload(value)

    fixture = Fixture(mutate=setup, rotated=rotated, disputed=disputed)
    semantic = fixture.semantic()
    snapshot_raw = semantic.snapshot()
    snapshot = loads(snapshot_raw, maximum=MAX_TRANSCRIPT, canonical=True)
    row = next(row for row in snapshot["statements"] if row["status"] == "supported")
    indices = range(len(row["value"]["assertions"])) if selected is None else selected
    references = [{**row["source"], "pointer": "/assertions/" + str(index)} for index in indices]
    policy = {"profile": PROFILE, "sourceSnapshotHash": keccak256(snapshot_raw),
        "sourceAuthoritySet": references, "reviewerAuthoritySet": [],
        "singleValuedRelations": [RELATION] if single_valued else [],
        "allowSelfReview": False, "independentHumanReviewRequired": False}
    policy_raw = dumps(policy)
    files = attribution_dossier.build_files(semantic.artist, semantic=semantic,
        selection_raw=policy_raw, selection_hash=keccak256(policy_raw))
    payload = deepcopy(fixture.semantic_value)
    return {"source_files": files, "source_hash": keccak256(files["manifest.json"]),
        "payload": payload, "body": loads(payload["assertions"][0]["object"]["literal"]["lexicalValue"].encode()),
        "policy": policy, "snapshot": snapshot,
        "provenance": {"kind": "synthetic_fixture", "actualRpcObserved": False,
            "actualEvmExecuted": False, "physicalEventObserved": False}}
