"""Registered interpretation and historical account admission for independent records."""

from types import MappingProxyType

from .account_profile import (ACCOUNT_PREFIX, ASSERTION_SCHEMA_BYTES, JCS_ID, NAME,
                              AccountProjectionProfile, account_iri)
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .chain_rpc import MAX_TRANSCRIPT, ReplayTransport, RpcTransport
from .independent_publication import IndependentPublicationAdapter
from .independent_source import IndependentSourceAdapter
from .independent_wire import RAW_BYTES, require
from .review import _selector, _validate
from .schemas import NAMES
from .source import BoundSourceState, RecordSelector, RetainedSourceRecord


CLASS = "INDEPENDENT_ATTESTOR"
RECORD_TYPE = schema_id("INDEPENDENT_SEMANTIC_ASSERTION")


def resolve_pointer(payload, pointer):
    if pointer == "":
        return payload
    require(isinstance(pointer, str) and pointer.startswith("/"), "record evidence pointer required")
    value = loads(payload, maximum=8192, canonical=True)
    for part in pointer[1:].split("/"):
        index = 0
        while index < len(part):
            if part[index] == "~":
                require(index + 1 < len(part) and part[index + 1] in "01", "record evidence pointer escape")
                index += 1
            index += 1
        key = part.replace("~1", "/").replace("~0", "~")
        if isinstance(value, list):
            position = uint(key, 64)
            require(position < len(value), "record evidence array position")
            value = value[position]
        else:
            require(isinstance(value, dict) and key in value, "record evidence field absent")
            value = value[key]
    return dumps(value)


class RegisteredInterpretationCapture:
    """Reuse the exact native document/chunk reader at the original source anchor."""
    def __init__(self, publication, profile, transport):
        require(type(publication) is IndependentPublicationAdapter and publication.provenance == "trusted_rpc",
                "actual publication adapter required")
        require(type(profile) is AccountProjectionProfile and type(transport) in (RpcTransport, ReplayTransport),
                "registered interpretation profile/transport required")
        self.publication = publication
        self.publication_bytes = publication.snapshot()
        self.profile = profile
        self.probe = IndependentSourceAdapter(publication.source.anchor_bytes, transport, provenance="trusted_rpc")
        self._started = False
        self._snapshot = None

    def snapshot(self):
        if self._snapshot is not None:
            return self._snapshot
        require(not self._started, "failed interpretation capture cannot resume")
        self._started = True
        probe = self.probe
        probe._block()
        for field in ("schemas", "store"):
            require(keccak256(hex_bytes(probe.reader.code(probe.a[field]))) == probe.pins[probe.a[field]],
                    "registered interpretation dependency code mismatch")
        for name, (kind, raw) in self.profile.documents.items():
            identifier = schema_id(name)
            probe._document(identifier, kind)
            _, actual, view = probe.documents[identifier]
            require(actual == raw and view[3][2] == keccak256(raw), "registered interpretation exact bytes mismatch")
            # JCS bootstraps through RAW_BYTES; every selected JSON document uses the registered JCS definition.
            require(view[3][3] == (RAW_BYTES if identifier == JCS_ID else JCS_ID),
                    "registered interpretation canonicalization mismatch")
        probe._block()
        if isinstance(probe.reader.transport, ReplayTransport):
            probe.reader.transport.finish()
        self._snapshot = dumps({"mode": "registered_account_interpretation", "version": "1",
            "anchorHash": keccak256(probe.anchor_bytes), "publicationHash": keccak256(self.publication_bytes),
            "profileId": schema_id(NAME), "profileHash": self.profile.profile_hash,
            "profileSchemaId": schema_id(NAMES[0]), "transcriptHash": keccak256(probe.reader.transcript()),
            "documents": [{"documentId": key, "originalHex": "0x" + payload.hex(),
                "rawViewHex": "0x" + raw.hex()} for key, (raw, payload, _) in probe.documents.items()]})
        return self._snapshot


class RecordedSemanticSource:
    def __init__(self, interpretation, *, profile_hash):
        require(type(interpretation) is RegisteredInterpretationCapture, "concrete registered interpretation required")
        self.interpretation_bytes = interpretation.snapshot()
        self.profile = interpretation.profile
        require(profile_hash == self.profile.profile_hash, "recorded semantic profile hash mismatch")
        self.profile_hash = profile_hash
        publication = interpretation.publication
        self.publication_bytes = publication.snapshot()
        self.publication = loads(self.publication_bytes, maximum=MAX_TRANSCRIPT, canonical=True)
        self.capture_bytes = publication.source.snapshot()
        capture = loads(self.capture_bytes, maximum=MAX_TRANSCRIPT, canonical=True)
        self.anchor = MappingProxyType(dict(publication.source.a))
        documents = {d["documentId"]: hex_bytes(d["payloadHex"]) for d in capture["documents"]}
        positions = {p["recordHash"]: tuple(uint(v) for v in p["publicationPosition"])
                     for p in self.publication["publications"]}
        self.positions, canonicalizations, self._payloads = MappingProxyType(positions), {}, set()
        records = []
        for row in capture["records"]:
            generic, receipt, subject = row["record"], row["receipt"], row["subject"]
            selector = RecordSelector(self.anchor["host"], row["recordHash"], generic[1], generic[4],
                keccak256(documents[generic[4]]), generic[0], receipt[1], CLASS, receipt[4], receipt[5])
            agent = account_iri(self.anchor["chainId"], receipt[1])
            facts = dumps({"mode": "historical_independent_account", "recorder": receipt[1], "agentIri": agent,
                "recordType": generic[0], "authorizationClass": CLASS,
                "publicationPosition": [str(v) for v in positions[row["recordHash"]]],
                "payloadHash": generic[2][1], "subjectKind": ("collection", "token", "media")[uint(subject[0])],
                "humanIdentityEstablished": False, "reviewIndependenceEstablished": False})
            records.append(RetainedSourceRecord(selector, hex_bytes(row["payloadHex"]), generic[2][1],
                                               documents[generic[4]], facts, "public"))
            canonicalizations[row["recordHash"]] = generic[2][2]
        identity = dumps({"mode": "recorded_state", "profile": NAME, "environment": self.anchor["environment"],
            "anchorHash": keccak256(publication.source.anchor_bytes), "sourceCaptureHash": keccak256(self.capture_bytes),
            "publicationHash": keccak256(self.publication_bytes), "interpretationHash": keccak256(self.interpretation_bytes),
            "profileHash": profile_hash, "records": [{"selector": r.selector.__dict__, "payloadHash": r.payload_hash,
                "authorityEvidenceHash": keccak256(r.authority_evidence), "disclosure": r.disclosure} for r in records]})
        self._state = BoundSourceState("recorded_state", identity, tuple(records))
        self.records = MappingProxyType({r.selector.record_hash: r for r in records})
        self.canonicalizations = MappingProxyType(canonicalizations)
        self.accounts = frozenset(account_iri(self.anchor["chainId"], r.selector.recorder) for r in records)

    @property
    def state(self):
        return self._state

    def record(self, selector):
        require(isinstance(selector, dict) and isinstance(selector.get("pointer"), str), "exact recorded selector required")
        record = self.records.get(selector.get("recordHash"))
        require(record is not None and selector == _selector(record, selector["pointer"]), "recorded selector mismatch")
        resolve_pointer(record.payload, selector["pointer"])
        return record

    def _prior(self, current, selector):
        record = self.record(selector)
        require(self.positions[record.selector.record_hash] < self.positions[current.selector.record_hash],
                "semantic evidence must precede this publication")
        return record

    def payload(self, record):
        h = record.selector.record_hash
        require(record is self.records.get(h), "foreign recorded source")
        if h in self._payloads:
            return loads(record.payload, canonical=True)
        require(record.selector.record_type == RECORD_TYPE and record.selector.schema_id == schema_id(NAMES[1])
                and record.schema == ASSERTION_SCHEMA_BYTES, "recorded semantic original schema/family mismatch")
        require(self.canonicalizations[h] == JCS_ID, "semantic payload needs registered JCS canonicalization")
        payload = _validate(record.schema, record.payload)
        facts = loads(record.authority_evidence)
        require(payload["profileSchemaId"] == schema_id(NAMES[0])
            and payload["profileHash"] == self.profile_hash and payload["anchorSubject"] == {
            "kind": facts["subjectKind"], "subjectId": record.selector.subject_id}, "semantic profile or subject mismatch")
        # These selected-record admission checks never parse wholly unselected opaque records.
        priors = [self._prior(record, row) for row in payload["sourceRecords"]]
        for entity in payload["entities"]:
            require(entity["declaringAgent"] == facts["agentIri"], "entity declaring account mismatch")
            require(not entity["id"].casefold().startswith(ACCOUNT_PREFIX), "account cannot become a declared entity")
            for row in entity["sourceRecords"]:
                self._prior(record, row)
        for assertion in payload["assertions"]:
            require(assertion["assertingAgent"] == facts["agentIri"], "asserting account does not match historical attestor")
            for evidence in assertion["evidence"]:
                matches = [r for r in priors if evidence["source"] == {"algorithm": "1", "digest": r.payload_hash,
                    "canonicalizationId": self.canonicalizations[r.selector.record_hash]}]
                require(matches, "semantic evidence hash is not a referenced original record")
                require(evidence["selectorType"] in ("json_pointer", "whole_document"), "unsupported semantic evidence selector")
                if evidence["selectorType"] == "whole_document":
                    require(evidence["selector"] == "", "whole document selector must be empty")
                for prior in matches:
                    resolve_pointer(prior.payload, evidence["selector"])
                if evidence["basis"] == "own_signed_statement":
                    require(all(p.selector.recorder == record.selector.recorder for p in matches), "own statement has another attestor")
        self._payloads.add(h)
        return payload

    def assertion(self, row):
        record = self.record(row)
        require(row["pointer"].startswith("/assertions/"), "recorded assertion pointer required")
        index = uint(row["pointer"][len("/assertions/"):], 64)
        body = self.payload(record)
        require(index < len(body["assertions"]), "recorded assertion index")
        return body["assertions"][index], account_iri(self.anchor["chainId"], record.selector.recorder), self.positions[record.selector.record_hash]

    def entity(self, state, row, profile_hash):
        require(state is self._state and profile_hash == self.profile_hash, "recorded entity state mismatch")
        record = self.record(row)
        require(row["pointer"].startswith("/entities/"), "recorded entity pointer required")
        index = uint(row["pointer"][len("/entities/"):], 64)
        body = self.payload(record)
        require(index < len(body["entities"]), "recorded entity index")
        return body["entities"][index], record
