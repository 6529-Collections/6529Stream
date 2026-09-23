"""Concrete offline source fixture for qualified physical-transfer exports."""

from copy import deepcopy
from dataclasses import dataclass

from . import general_semantic_dossier_v1 as general_dossier
from . import physical_transfer_semantics_v1 as semantics
from .canonical import dumps, keccak256
from .general_semantic_fixture_v1 import OfflineGeneralSemanticFixture


@dataclass(frozen=True)
class PhysicalTransferCase:
    source_files: dict
    source_hash: str
    body: dict
    payload: bytes
    fixture: OfflineGeneralSemanticFixture
    selection: bytes
    selection_hash: str


def _entity(identifier, kind, label, issuer, sources):
    return {"id": identifier, "kind": kind,
        "names": [{"value": label, "language": "en", "kind": "preferred"}],
        "declaringAgent": issuer, "sourceRecords": deepcopy(sources), "predecessors": []}


def _pin(entity, index):
    return {"id": entity["id"], "pointer": "/entities/" + str(index),
            "hash": keccak256(dumps(entity))}


def build_case(*, kind="physical_acquisition", status="completed",
               authority="institution", parties=True, evidence_order="prior",
               selection_indices=None, mutate=None):
    """Build a fully replayed General dossier containing one transfer statement.

    ``mutate(value, body)`` runs before the body is serialized and before the
    General receipt, lane, payload chunks, and package are reconstructed.
    """
    if kind not in semantics.KINDS or status not in semantics.STATUSES:
        raise ValueError("unsupported physical transfer fixture shape")
    captured = {}

    def inject(value):
        assertion = value["assertions"][0]
        issuer = assertion["assertingAgent"]
        tag = "acquisition" if kind == "physical_acquisition" else "custody"
        entities = [
            _entity("urn:fixture:physical-object", "physical_object",
                    "Fixture physical object", issuer, value["sourceRecords"]),
            _entity("urn:fixture:" + tag + ":event", "event",
                    "Fixture transfer event", issuer, value["sourceRecords"]),
            _entity("urn:fixture:" + tag + ":activity", "event",
                    "Fixture enclosing activity", issuer, value["sourceRecords"]),
        ]
        if parties:
            entities.extend((
                _entity("urn:fixture:party:from", "person", "Declared transferor",
                        issuer, value["sourceRecords"]),
                _entity("urn:fixture:party:to", "group", "Declared transferee",
                        issuer, value["sourceRecords"]),
            ))
        value["entities"] = entities
        body = {"version": "1", "kind": kind, "status": status,
            "physicalObject": _pin(entities[0], 0),
            "transferEvent": _pin(entities[1], 1),
            "activity": _pin(entities[2], 2),
            "fromParty": _pin(entities[3], 3) if parties else None,
            "toParty": _pin(entities[4], 4) if parties else None,
            "instrumentEvidence": {"evidenceIndex": "0",
                "sourceRecord": deepcopy(value["sourceRecords"][0])}}
        assertion.update(subject=entities[0]["id"], relation=semantics.RELATION,
            mappingRule=semantics.RULE, object={"literal": {
                "lexicalValue": "", "datatype": semantics.DATATYPE,
                "language": None, "unit": None, "precision": None}})
        if mutate is not None:
            mutate(value, body)
        assertion["object"]["literal"]["lexicalValue"] = dumps(body).decode("utf-8")
        captured["body"] = deepcopy(body)

    fixture = OfflineGeneralSemanticFixture(authority=authority,
        evidence_order=evidence_order, mutate=inject)
    source = fixture.source()
    selection, selection_hash = fixture.selection(source, indices=selection_indices)
    assembled = general_dossier.build(source, selection, selection_hash, disclosure="public")
    body = captured["body"]
    return PhysicalTransferCase(dict(assembled.files), assembled.manifest_hash,
        body, dumps(body), fixture, selection, selection_hash)
