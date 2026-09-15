"""Immutable input boundary. The concrete adapter here is synthetic-only.

Authority values supplied by this adapter support fixture assertions, not chain
verification. A recorded adapter must establish its own accepted state evidence.
"""

from dataclasses import dataclass
from typing import Literal, Protocol

from .canonical import MuseumError, hex_bytes, keccak256, loads, uint


@dataclass(frozen=True)
class RecordSelector:
    host: str
    record_hash: str
    subject_id: str
    schema_id: str
    schema_hash: str
    record_type: str
    recorder: str
    authorization_class: str
    record_index: str
    record_chain_hash: str

    def __post_init__(self):
        for value in (self.host, self.recorder):
            hex_bytes(value, 20)
        for value in (self.record_hash, self.subject_id, self.schema_id,
                      self.schema_hash, self.record_type, self.record_chain_hash):
            hex_bytes(value, 32)
        uint(self.record_index, 64)


@dataclass(frozen=True)
class SourceRecord:
    selector: RecordSelector
    payload: bytes
    payload_hash: str
    schema: bytes
    authority_evidence: bytes
    disclosure: Literal["public", "restricted"]

    def __post_init__(self):
        if type(self.payload) is not bytes or type(self.schema) is not bytes:
            raise MuseumError("source bytes must be immutable")
        loads(self.payload, canonical=True)
        loads(self.schema, canonical=True)
        if keccak256(self.payload) != self.payload_hash:
            raise MuseumError("source payload hash mismatch")
        if keccak256(self.schema) != self.selector.schema_hash:
            raise MuseumError("source schema hash mismatch")
        if self.disclosure not in ("public", "restricted"):
            raise MuseumError("unknown disclosure rule")


@dataclass(frozen=True)
class RetainedSourceRecord:
    """Hash-bound opaque historical bytes; selected interpretation validates JSON later."""
    selector: RecordSelector
    payload: bytes
    payload_hash: str
    schema: bytes
    authority_evidence: bytes
    disclosure: Literal["public", "restricted"]

    def __post_init__(self):
        if type(self.payload) is not bytes or type(self.schema) is not bytes or type(self.authority_evidence) is not bytes:
            raise MuseumError("retained source bytes must be immutable")
        if keccak256(self.payload) != self.payload_hash or keccak256(self.schema) != self.selector.schema_hash:
            raise MuseumError("retained source hash mismatch")
        if self.disclosure not in ("public", "restricted"):
            raise MuseumError("unknown disclosure rule")


@dataclass(frozen=True)
class BoundSourceState:
    mode: Literal["synthetic_fixture", "draft_preview", "recorded_state"]
    identity: bytes
    records: tuple[SourceRecord | RetainedSourceRecord, ...]

    @property
    def commitment(self):
        return keccak256(self.identity)


class SourceStateAdapter(Protocol):
    def snapshot(self) -> BoundSourceState:
        """Return one immutable state with independently established evidence."""
        ...


class FixtureSourceAdapter:
    def __init__(self, fixture_name: str, records: tuple[SourceRecord, ...]):
        from .canonical import dumps
        if type(records) is not tuple or not fixture_name:
            raise MuseumError("invalid fixture input")
        keys = [r.selector.record_hash for r in records]
        if len(keys) != len(set(keys)):
            raise MuseumError("duplicate fixture record")
        self._state = BoundSourceState("synthetic_fixture", dumps({
            "mode": "synthetic_fixture", "fixtureName": fixture_name,
            "records": [{"selector": r.selector.__dict__, "payloadHash": r.payload_hash,
                         "authorityEvidenceHash": keccak256(r.authority_evidence),
                         "disclosure": r.disclosure} for r in records]}), records)

    def snapshot(self):
        return self._state


def public_records(state: BoundSourceState) -> tuple[SourceRecord, ...]:
    """Do not expose excluded record identifiers, values or evidence in reports."""
    return tuple(record for record in state.records if record.disclosure == "public")
