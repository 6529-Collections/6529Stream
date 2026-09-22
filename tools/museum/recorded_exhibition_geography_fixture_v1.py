"""Offline, fully replayed typed TGN authority fixture for geography joins.

This is test support, not observed chain evidence.  It constructs deterministic
RPC response rows, records them once, and then admits only exact transcript
bytes through the production ReplayTransport readers.  The resulting source,
publication, registered interpretation, recorded package, and Authority V2
package all use the real consumers.  No EVM, RPC endpoint, signature key, or
authority publisher is contacted.

The transport provenance is therefore ``externally_admitted_synthetic_transcript``.
The production readers call the replay trust class ``trusted_rpc`` because an
external transcript hash is mandatory; that name does not turn these generated
rows into public-chain, consensus, deployment, publisher, or human-review
evidence.
"""

from copy import deepcopy
from pathlib import Path
import tempfile

from . import authority_v2
from .account_profile import account_iri
from .authority_package_v2 import build_authority_package
from .authority_snapshot import (FOAF_FOCUS, GVP, RDF_TYPE, SKOS,
                                 canonical_authority_iri, parse_snapshot)
from .canonical import (MuseumError, dumps, hex_bytes, keccak256, loads,
                        record_chain, schema_id, subject_id)
from .chain_abi import Array, calldata, encode
from .chain_rpc import ReplayTransport
from .independent_publication import (EVENT_DATA, EVENT_TOPIC,
                                      IndependentPublicationAdapter)
from .independent_source import IndependentSourceAdapter, PROFILE as SOURCE_PROFILE
from .independent_wire import (DOCUMENT, DOCUMENT_SPEC, RAW_BYTES, RAW_DEFINITION,
                               RECEIPT, RECORD, SUBJECT, TYPE_HASH, ZERO,
                               domain, generic_hash)
from .package import write_package
from .package_recorded import INPUT_FILES, build_recorded_package
from .recorded_semantic import RegisteredInterpretationCapture, RecordedSemanticSource
from .review import (REVIEW_DATATYPE, REVIEW_MAPPING_RULE, REVIEW_RELATION,
                     review_literal, _selector, _validate)
from .schemas import NAMES as OLD_NAMES
from .typed_authority_profile import (ASSERTION_SCHEMA_BYTES, NAMES,
                                      TypedAuthorityProfile)


ROOT = Path(__file__).resolve().parents[2] / "schemas/museum"
CHAIN_ID = 31337
SCOPE = 1
RECORD_TYPE = schema_id("INDEPENDENT_SEMANTIC_ASSERTION")
ZERO_ADDRESS = "0x" + "00" * 20
PROFILE = "STREAM_MUSEUM_RECORDED_EXHIBITION_GEOGRAPHY_FIXTURE_V1"
PROVENANCE = "externally_admitted_synthetic_transcript"


def _h(label):
    return keccak256((PROFILE + ":" + str(label)).encode("utf-8"))


def _a(number):
    return "0x" + number.to_bytes(20, "big").hex()


class _MapTransport:
    def __init__(self, rows):
        self.rows = rows

    def request(self, method, params):
        key = dumps([method, params])
        if key not in self.rows:
            raise MuseumError("unexpected offline typed TGN fixture request")
        return deepcopy(self.rows[key])


class _OfflineTypedTgnReplayFixture:
    def __init__(self, *, match_kind="equivalent_entity", review_status="reviewed",
                 alternate_declaration=False, publication_block="4"):
        if match_kind not in ("equivalent_entity", "close_match", "related_reference"):
            raise MuseumError("unsupported offline TGN fixture match kind")
        if review_status not in ("reviewed", "unreviewed", "disputed"):
            raise MuseumError("unsupported offline TGN fixture review status")
        if type(alternate_declaration) is not bool:
            raise MuseumError("offline TGN alternate declaration flag")
        if publication_block not in ("4", "6"):
            raise MuseumError("unsupported offline TGN publication block")
        self.match_kind = match_kind
        self.review_status = review_status
        self.alternate_declaration = alternate_declaration
        self.publication_block = int(publication_block)
        self.timestamp = 1780000003 if publication_block == "4" else 1790000001
        self.profile = TypedAuthorityProfile(ROOT)
        self.rows = {}
        # Core and source chronology deliberately match the synthetic Title V5
        # owner fixture.  The independent host/Registry remain distinct.
        self.core, self.host, self.schemas, self.store = _a(2), _a(71002), _a(71003), _a(71004)
        self.attestor = _a(71005)
        self.runtimes = {self.core: b"\x60\x01", self.host: b"\x60\x02",
                         self.schemas: b"\x60\x03", self.store: b"\x60\x04"}
        suffix = str(self.publication_block)
        transaction_count = 5 if alternate_declaration else 4
        transaction_label = "tx:" if publication_block == "4" else "tx:block6:"
        self.block = {"hash": _h("independent declaration block " + suffix),
            "number": hex(self.publication_block), "timestamp": hex(self.timestamp),
            "stateRoot": _h("independent declaration state " + suffix),
            "parentHash": _h("independent parent " + str(self.publication_block - 1)),
            "transactionsRoot": _h("transactions"), "receiptsRoot": _h("receipts"),
            "transactions": [_h(transaction_label + str(i)) for i in range(transaction_count)]}
        self.block_ref = {"blockHash": self.block["hash"], "requireCanonical": True}
        self.deployment_evidence = dumps({"kind": PROVENANCE, "claims": {
            "actualDeployment": False, "rpcTruth": False, "consensusFinality": False,
            "publisherAuthentication": False, "independentHumanReview": False}})
        self.anchor = {"profile": SOURCE_PROFILE, "chainId": str(CHAIN_ID),
            "blockHash": self.block["hash"], "blockNumber": str(self.publication_block),
            "timestamp": str(self.timestamp),
            # Environment is the source-declared target environment shared by
            # the owner dossier.  PROVENANCE below remains synthetic and makes
            # clear that this is not an observed public-chain capture.
            "stateRoot": self.block["stateRoot"], "environment": "public_chain",
            "deploymentEvidenceHash": keccak256(self.deployment_evidence),
            "host": self.host, "core": self.core, "schemas": self.schemas, "store": self.store,
            "codePins": [{"address": a, "runtimeHash": keccak256(raw)}
                         for a, raw in self.runtimes.items()],
            "lanes": [{"scopeKey": str(SCOPE), "recordType": RECORD_TYPE}]}
        self.anchor_raw = dumps(self.anchor)
        self._pointers, self._pointer_number = {}, 72000
        self._install_common()
        self._install_documents()
        self.snapshot_raw, self.snapshot_descriptor, self.snapshot_descriptor_hash, self.parsed_snapshot = self._snapshot()
        self.records = self._records()
        self._install_records()
        self._install_publications()

    def put(self, method, params, result):
        self.rows[dumps([method, params])] = result

    def call(self, target, signature, outputs, values, inputs=(), arguments=()):
        self.put("eth_call", [{"to": target, "data": calldata(signature, inputs, arguments),
            "gas": "0x1312d00"}, self.block_ref], "0x" + encode(outputs, values).hex())

    def code(self, address, raw):
        self.put("eth_getCode", [address, self.block_ref], "0x" + raw.hex())

    def _install_common(self):
        self.put("eth_chainId", [], hex(CHAIN_ID))
        self.put("eth_getBlockByHash", [self.block["hash"], False], self.block)
        self.put("eth_getBlockByNumber", [self.block["number"], False], self.block)
        for address, raw in self.runtimes.items():
            self.code(address, raw)
        for signature, output, value in (
                ("core()", "address", self.core),
                ("schemaRegistry()", "address", self.schemas),
                ("chunkStore()", "address", self.store),
                ("coreCodeHash()", "bytes32", keccak256(self.runtimes[self.core])),
                ("schemaRegistryCodeHash()", "bytes32", keccak256(self.runtimes[self.schemas])),
                ("chunkStoreCodeHash()", "bytes32", keccak256(self.runtimes[self.store]))):
            self.call(self.host, signature, (output,), (value,))
        self.call(self.host, "supportsInterface(bytes4)", ("bool",), (True,),
                  ("bytes4",), ("0x771b2917",))
        self.call(self.schemas, "chunkStore()", ("address",), (self.store,))

    def _carrier(self, digest, raw):
        prior = self._pointers.get(digest)
        if prior is not None:
            if prior[1] != raw:
                raise MuseumError("offline fixture digest collision")
            return prior[0]
        pointer = _a(self._pointer_number); self._pointer_number += 1
        self._pointers[digest] = (pointer, raw)
        self.call(self.store, "chunk(bytes32)", ("address", "uint32"),
                  (pointer, len(raw)), ("bytes32",), (digest,))
        self.code(pointer, b"\0" + raw)
        return pointer

    def _document(self, name, kind, raw, canonical, predecessor=ZERO):
        identifier = schema_id(name)
        chunks = tuple(raw[i:i + 8192] for i in range(0, len(raw), 8192))
        hashes = tuple(keccak256(chunk) for chunk in chunks)
        spec = (name, kind, keccak256(raw), canonical, predecessor, "", len(raw))
        declaration = keccak256(encode((DOCUMENT_SPEC, Array("bytes32")), (spec, hashes)))
        value = (True, 0, declaration, spec, hashes)
        self.call(self.schemas, "document(bytes32)", (DOCUMENT,), (value,),
                  ("bytes32",), (identifier,))
        for digest, chunk in zip(hashes, chunks): self._carrier(digest, chunk)

    def _install_documents(self):
        self._document("RAW_BYTES", 1, RAW_DEFINITION, RAW_BYTES)
        predecessors = self.profile.document_predecessors
        canonicalizations = self.profile.document_canonicalizations
        for name, (kind, raw) in self.profile.documents.items():
            self._document(name, kind, raw, canonicalizations[name], predecessors.get(name, ZERO))

    def _snapshot(self):
        root = canonical_authority_iri("GETTY_TGN", "7002327")
        focus = root + "-place"
        graph = {root: {
            FOAF_FOCUS: [{"type": "uri", "value": focus}],
            SKOS + "prefLabel": [{"type": "literal", "value": "Milos", "lang": "en"}],
            RDF_TYPE: [{"type": "uri", "value": GVP + "PhysPlaceConcept"}],
            SKOS + "broader": [{"type": "uri", "value": "http://vocab.getty.edu/tgn/1000074"}],
        }, focus: {RDF_TYPE: [{"type": "uri", "value": "http://www.w3.org/2003/01/geo/wgs84_pos#SpatialThing"}]}}
        raw = dumps(graph)
        descriptor = dumps({"version": "1", "authority": "GETTY_TGN", "identifier": "7002327",
            "canonicalIri": root, "sourceUri": "https://example.test/retained-tgn-7002327.rdf.json",
            "retrievedAt": "2026-09-16T12:34:56Z",
            "contentHash": {"algorithm": "1", "digest": keccak256(raw), "canonicalizationId": RAW_BYTES},
            "byteLength": str(len(raw)), "mediaType": "application/rdf+json",
            "attribution": "Synthetic retained TGN-shaped fixture; not bytes authenticated by Getty.",
            "reuseTerms": "Synthetic fixture only; no authority publisher claim."})
        pin = keccak256(descriptor)
        return raw, descriptor, pin, parse_snapshot(descriptor, raw, descriptor_hash=pin)

    def _selector(self, row, pointer=""):
        return {"recordHash": row["hash"], "subjectId": row["record"][1],
            "schemaId": row["record"][4], "schemaHash": row["receipt"][9],
            "recordType": row["record"][0], "host": self.host, "recorder": self.attestor,
            "authorizationClass": "INDEPENDENT_ATTESTOR", "pointer": pointer,
            "recordIndex": str(row["receipt"][4]), "recordChainHash": row["receipt"][5]}

    def _make_record(self, payload, index, previous):
        sid = subject_id("collection", str(CHAIN_ID), self.core, str(SCOPE))
        schema = schema_id(NAMES[1]); schema_hash = keccak256(ASSERTION_SCHEMA_BYTES)
        content = (1, hex_bytes(keccak256(payload)), schema_id("RFC8785_JCS"))
        effective, nonce = 1780000000, index
        deadline = 1780001000 if self.publication_block == 4 else 1790001000
        words = encode(("bytes32", "address", "uint256", "bytes32", "bytes32", "bytes32", "uint16",
            "bytes32", "bytes32", "bytes32", "bytes32", "uint64", "uint256", "uint64"),
            (TYPE_HASH, self.attestor, SCOPE, sid, RECORD_TYPE, schema, 1, keccak256(content[1]),
             content[2], keccak256(b""), keccak256(payload), effective, nonce, deadline))
        saved_domain = domain(CHAIN_ID, self.host)
        bundle = encode(("bytes32", ("bytes32",) * 14, "bytes"),
                        (saved_domain, encode_to_words(words), b""))
        signature = (1, hex_bytes(keccak256(bundle)), RAW_BYTES)
        record = (RECORD_TYPE, sid, content, "", schema, schema_id("DIRECT"), signature, effective)
        authorization = keccak256(b"\x19\x01" + hex_bytes(saved_domain) + hex_bytes(keccak256(words)))
        digest = generic_hash(CHAIN_ID, self.host, self.core, SCOPE, self.attestor, record)
        chain = record_chain(str(CHAIN_ID), self.host, str(SCOPE), RECORD_TYPE, previous, digest, str(index))
        receipt = (SCOPE, self.attestor, 5, self.timestamp, index, chain, authorization, nonce,
                   deadline, schema_hash, keccak256(self.profile.documents["RFC8785_JCS"][1]))
        return {"payload": payload, "bundle": bundle, "record": record, "receipt": receipt,
                "subject": (0, SCOPE, 0, ZERO), "hash": digest}

    def _payload_shell(self, source_records):
        sid = subject_id("collection", str(CHAIN_ID), self.core, str(SCOPE))
        return {"profileSchemaId": schema_id(NAMES[0]), "profileHash": self.profile.profile_hash,
            "anchorSubject": {"kind": "collection", "subjectId": sid}, "entities": [],
            "assertions": [], "sourceRecords": source_records, "authorityAlignments": []}

    def _records(self):
        rows, previous = [], ZERO
        seed = dumps({"fixture": "offline typed TGN declaration source", "version": 1})
        first = self._make_record(seed, 0, previous); rows.append(first); previous = first["receipt"][5]
        seed_selector = self._selector(first)
        agent = account_iri(str(CHAIN_ID), self.attestor)
        entity_id = "urn:6529stream:museum:fixture:place:milos"
        entity = {"id": entity_id, "kind": "place", "names": [
            {"value": "Milos", "language": "en", "kind": "preferred"}],
            "declaringAgent": agent, "sourceRecords": [seed_selector], "predecessors": [],
            "continuation": None}
        declaration = self._payload_shell([seed_selector]); declaration["entities"] = [entity]
        declaration["assertions"] = [{"id": "urn:fixture:milos:declared-name", "subject": entity_id,
            "relation": "http://www.w3.org/2000/01/rdf-schema#label",
            "object": {"literal": {"lexicalValue": "Milos", "datatype": "http://www.w3.org/2001/XMLSchema#string",
                "language": "en", "unit": None, "precision": None}}, "assertingAgent": agent,
            "createdAt": "2026-09-16T12:34:53Z", "evidence": [{"source": {"algorithm": "1",
                "digest": keccak256(seed), "canonicalizationId": schema_id("RFC8785_JCS")},
                "selectorType": "whole_document", "selector": "", "basis": "own_signed_statement"}],
            "origin": "direct_statement", "reviewStatus": "unreviewed",
            "mappingRule": "urn:fixture:mapping:declared-place-name", "rationale": "Synthetic fixture declaration.",
            "reviewEvidence": [], "corrects": [], "disputes": []}]
        declaration_raw = dumps(declaration); _validate(ASSERTION_SCHEMA_BYTES, declaration_raw)
        second = self._make_record(declaration_raw, 1, previous); rows.append(second); previous = second["receipt"][5]
        declaration_selector = self._selector(second, "/entities/0")
        authority_entity = entity
        authority_declaration_selector = declaration_selector
        if self.alternate_declaration:
            authority_entity = deepcopy(entity)
            authority_entity["names"] = [
                {"value": "Milos (alternate declaration)", "language": "en", "kind": "preferred"}]
            alternate = self._payload_shell([seed_selector])
            alternate["entities"] = [authority_entity]
            alternate["assertions"] = [{
                "id": "urn:fixture:milos:alternate-declared-name", "subject": entity_id,
                "relation": "http://www.w3.org/2000/01/rdf-schema#label",
                "object": {"literal": {"lexicalValue": "Milos (alternate declaration)",
                    "datatype": "http://www.w3.org/2001/XMLSchema#string", "language": "en",
                    "unit": None, "precision": None}}, "assertingAgent": agent,
                "createdAt": "2026-09-16T12:34:53Z", "evidence": [{"source": {"algorithm": "1",
                    "digest": keccak256(seed), "canonicalizationId": schema_id("RFC8785_JCS")},
                    "selectorType": "whole_document", "selector": "", "basis": "own_signed_statement"}],
                "origin": "direct_statement", "reviewStatus": "unreviewed",
                "mappingRule": "urn:fixture:mapping:alternate-declared-place-name",
                "rationale": "Synthetic fixture alternate declaration.",
                "reviewEvidence": [], "corrects": [], "disputes": []}]
            alternate_raw = dumps(alternate); _validate(ASSERTION_SCHEMA_BYTES, alternate_raw)
            alternate_row = self._make_record(alternate_raw, 2, previous)
            rows.append(alternate_row); previous = alternate_row["receipt"][5]
            authority_declaration_selector = self._selector(alternate_row, "/entities/0")
        parsed = self.parsed_snapshot
        def fact(row):
            return {"subject": row["subject"], "predicate": row["predicate"],
                    "object": row["object"]["value"], "sourcePointer": row["sourcePointer"]}
        alignment = {"entityId": entity_id, "authority": "GETTY_TGN", "identifier": "7002327",
            "canonicalIri": canonical_authority_iri("GETTY_TGN", "7002327"),
            "focusIri": parsed["focusIri"], "matchKind": self.match_kind,
            "snapshotRef": {"path": "authorities/getty-tgn-7002327.rdf.json",
                "contentHash": loads(self.snapshot_descriptor)["contentHash"],
                "byteLength": str(len(self.snapshot_raw)), "mediaType": "application/rdf+json"},
            "retrievedAt": "2026-09-16T12:34:56Z", "authorityRevision": "not_supplied",
            "labelAtReview": {"value": "Milos", "language": "en", "kind": "preferred"},
            "basis": "Synthetic account-authored mapping to exact retained bytes; Getty did not authenticate this fixture.",
            "assertionId": "urn:fixture:milos:tgn-alignment"}
        body = {"alignment": alignment, "entityKind": "Place",
            "typeEvidence": [fact(parsed["typeFacts"][0])],
            "contextChecks": [{"scope": "authority_catalog_hierarchy", "fact": fact(parsed["hierarchyFacts"][0]),
                "localStatement": "Declared island context.", "conclusion": "consistent",
                "rationale": "Synthetic fixture correspondence."}], "change": None,
            "declaration": {"scope": "prior_record", "selector": authority_declaration_selector,
                "declarationHash": keccak256(dumps(authority_entity))}}
        assertion = {"id": alignment["assertionId"], "subject": entity_id,
            "relation": authority_v2.RELATION, "object": {"literal": authority_v2.alignment_literal(body)},
            "assertingAgent": agent, "createdAt": "2026-09-16T12:34:54Z",
            "evidence": [{"source": {"algorithm": "1", "digest": keccak256(seed),
                "canonicalizationId": schema_id("RFC8785_JCS")}, "selectorType": "whole_document",
                "selector": "", "basis": "documentary_evidence"}], "origin": "automated_mapping",
            "reviewStatus": "unreviewed", "mappingRule": authority_v2.RULE,
            "rationale": "Synthetic fixture mapping submitted for exact account SELF review.",
            "reviewEvidence": [], "corrects": [], "disputes": []}
        if self.review_status == "disputed":
            # A disputed direct account statement is retained but explicitly
            # ineligible in the Authority V2 reconciliation.
            assertion["origin"] = "direct_statement"
            assertion["reviewStatus"] = "disputed"
        mapped = self._payload_shell([seed_selector, authority_declaration_selector])
        mapped["assertions"] = [assertion]
        mapped["authorityAlignments"] = [alignment]
        mapped_raw = dumps(mapped); _validate(ASSERTION_SCHEMA_BYTES, mapped_raw)
        mapping_index = 3 if self.alternate_declaration else 2
        mapping = self._make_record(mapped_raw, mapping_index, previous)
        rows.append(mapping); previous = mapping["receipt"][5]
        assertion_selector = self._selector(mapping, "/assertions/0")
        review_body = {"assertionRecord": assertion_selector, "assertionRevisionHash": keccak256(dumps(assertion)),
            "profileHash": self.profile.profile_hash, "mappingRule": authority_v2.RULE, "disposition": "reviewed"}
        review = {"id": "urn:fixture:milos:tgn-alignment-review", "subject": assertion["id"],
            "relation": REVIEW_RELATION, "object": {"literal": review_literal(review_body)},
            "assertingAgent": agent, "createdAt": "2026-09-16T12:34:55Z",
            "evidence": [{"source": {"algorithm": "1", "digest": keccak256(mapped_raw),
                "canonicalizationId": schema_id("RFC8785_JCS")}, "selectorType": "json_pointer",
                "selector": "/assertions/0", "basis": "own_signed_statement"}],
            "origin": "direct_statement", "reviewStatus": "unreviewed", "mappingRule": REVIEW_MAPPING_RULE,
            "rationale": "Synthetic fixture account reviews its exact mapping revision.",
            "reviewEvidence": [], "corrects": [], "disputes": []}
        reviewed = self._payload_shell([assertion_selector]); reviewed["assertions"] = [review]
        reviewed_raw = dumps(reviewed); _validate(ASSERTION_SCHEMA_BYTES, reviewed_raw)
        review_row = self._make_record(reviewed_raw, mapping_index + 1, previous); rows.append(review_row)
        self.entity, self.declaration_raw = entity, declaration_raw
        self.declaration_selector = declaration_selector
        self.authority_entity = authority_entity
        self.authority_declaration_selector = authority_declaration_selector
        self.assertion, self.assertion_selector = assertion, assertion_selector
        self.review_selector = None  # filled after the review record hash exists
        self.review_selector = self._selector(review_row, "/assertions/0")
        return rows

    def _install_records(self):
        for row in self.records:
            payload_pointer = self._carrier(keccak256(row["payload"]), row["payload"])
            bundle_pointer = self._carrier(keccak256(row["bundle"]), row["bundle"])
            self.call(self.host, "collectionRecord(bytes32)", (RECORD, RECEIPT),
                      (row["record"], row["receipt"]), ("bytes32",), (row["hash"],))
            self.call(self.host, "recordSubject(bytes32)", (SUBJECT,), (row["subject"],),
                      ("bytes32",), (row["hash"],))
            self.call(self.host, "recordPayload(bytes32)", ("address", "bytes"),
                      (payload_pointer, row["payload"]), ("bytes32",), (row["hash"],))
            self.call(self.host, "recordSignatureBundle(bytes32)", ("address", "bytes"),
                      (bundle_pointer, row["bundle"]), ("bytes32",), (row["hash"],))
            self.call(self.host, "isIndependentAttestorNonceUsed(address,uint256)", ("bool",), (True,),
                      ("address", "uint256"), (self.attestor, row["receipt"][7]))
            self.call(self.host, "recordHashAt(uint256,bytes32,uint256)", ("bytes32",), (row["hash"],),
                      ("uint256", "bytes32", "uint256"), (SCOPE, RECORD_TYPE, row["receipt"][4]))
        head = self.records[-1]["receipt"][5]
        self.call(self.host, "recordChainHash(uint256,bytes32)", ("bytes32", "uint64"),
                  (head, len(self.records)), ("uint256", "bytes32"), (SCOPE, RECORD_TYPE))
        self.call(self.host, "latestCollectionRecordHashFor(uint256,bytes32,bytes32,address)", ("bytes32",),
                  (self.records[-1]["hash"],), ("uint256", "bytes32", "bytes32", "address"),
                  (SCOPE, RECORD_TYPE, self.records[0]["record"][1], self.attestor))

    def _install_publications(self):
        authority = "0x" + (5).to_bytes(32, "big").hex()
        for index, row in enumerate(self.records):
            tx = self.block["transactions"][index]
            log = {"address": self.host,
                "topics": [EVENT_TOPIC, "0x" + SCOPE.to_bytes(32, "big").hex(), RECORD_TYPE,
                           row["record"][1]],
                "data": "0x" + encode(EVENT_DATA, (row["record"], row["hash"], row["receipt"][5],
                                                     self.attestor, authority, 1)).hex(),
                "blockHash": self.block["hash"], "blockNumber": self.block["number"],
                "transactionHash": tx, "transactionIndex": hex(index), "logIndex": hex(index),
                "removed": False}
            receipt = {"transactionHash": tx, "status": "0x1", "blockHash": self.block["hash"],
                "blockNumber": self.block["number"], "transactionIndex": hex(index), "logs": [log]}
            self.put("eth_getTransactionReceipt", [tx], receipt)

    def capture(self):
        synthetic = IndependentSourceAdapter(self.anchor_raw, _MapTransport(self.rows))
        source_capture = synthetic.snapshot(); source_transcript = synthetic.reader.transcript()
        source = IndependentSourceAdapter(self.anchor_raw,
            ReplayTransport(source_transcript, keccak256(source_transcript)), provenance="trusted_rpc")
        hints = dumps({"profile": "STREAM_MUSEUM_INDEPENDENT_PUBLICATION_V1",
            "records": [{"recordHash": row["hash"], "transactionHash": self.block["transactions"][i]}
                        for i, row in enumerate(self.records)]})
        synthetic_publication = IndependentPublicationAdapter(source, hints, _MapTransport(self.rows))
        publications = synthetic_publication.snapshot()
        publication_transcript = synthetic_publication.reader.transcript()
        source = IndependentSourceAdapter(self.anchor_raw,
            ReplayTransport(source_transcript, keccak256(source_transcript)), provenance="trusted_rpc")
        publication = IndependentPublicationAdapter(source, hints,
            ReplayTransport(publication_transcript, keccak256(publication_transcript)), provenance="trusted_rpc")
        probe = IndependentSourceAdapter(self.anchor_raw, _MapTransport(self.rows))
        probe._block()
        for field in ("schemas", "store"):
            probe.reader.code(probe.a[field])
        for name, (kind, _) in self.profile.documents.items():
            probe._document(schema_id(name), kind)
        probe._block()
        interpretation_transcript = probe.reader.transcript()
        interpretation = RegisteredInterpretationCapture(publication, self.profile,
            ReplayTransport(interpretation_transcript, keccak256(interpretation_transcript)))
        source = RecordedSemanticSource(interpretation, profile_hash=self.profile.profile_hash)
        return source, {"anchor.json": self.anchor_raw, "transcript.json": source_transcript,
            "publication-hints.json": hints, "publication-transcript.json": publication_transcript,
            "interpretation-transcript.json": interpretation_transcript,
            "deployment-evidence.json": self.deployment_evidence,
            "source-capture.json": source.capture_bytes, "publications.json": source.publication_bytes,
            "interpretation.json": source.interpretation_bytes}


def encode_to_words(raw):
    """Convert the exact fourteen-word ABI encoding into the saved words tuple."""
    if len(raw) != 32 * 14:
        raise MuseumError("offline fixture signed word width")
    return tuple("0x" + raw[i:i + 32].hex() for i in range(0, len(raw), 32))


def build_authority_case(*, match_kind="equivalent_entity", review_status="reviewed",
                         alternate_declaration=False, publication_block="4"):
    """Return one concrete replayed TGN Authority V2 package and join identities.

    ``match_kind='equivalent_entity'`` resolves a qualified equivalence.
    Weaker match kinds replay the same complete source but deliberately emit no
    equivalent resource.  In every case the returned transcripts are generated
    fixture evidence whose exact byte commitments are checked by ReplayTransport.
    """
    fixture = _OfflineTypedTgnReplayFixture(match_kind=match_kind, review_status=review_status,
        alternate_declaration=alternate_declaration, publication_block=publication_block)
    source, inputs = fixture.capture()
    selection = dumps({"mode": "recorded_account_selection", "version": "1",
        "sourceStateHash": source.state.commitment, "profileHash": source.profile_hash,
        "sourceAuthoritySet": [fixture.assertion_selector],
        "reviewerAuthoritySet": [fixture.review_selector] if review_status != "unreviewed" else [],
        "singleValuedRelations": [authority_v2.RELATION,
            "urn:6529stream:museum:content-kind:v1",
            "http://www.cidoc-crm.org/cidoc-crm/P190_has_symbolic_content"],
        "independentReviewRequired": False,
        "allowAccountSelfReview": True})
    plan = dumps({"mode": "recorded_account_resource_projection", "version": "account-2",
        "sourceStateHash": source.state.commitment, "profileHash": source.profile_hash,
        "selectionPolicyHash": keccak256(selection), "crosswalkHash": fixture.profile.crosswalk_hash,
        "entityAuthoritySet": [fixture.authority_declaration_selector],
        "externalEntities": [{"id": account_iri(str(CHAIN_ID), fixture.attestor), "kind": "account"}]})
    inputs.update({"selection.json": selection, "plan.json": plan})
    pins = {"source_hash": keccak256(inputs["transcript.json"]),
        "publication_hash": keccak256(inputs["publication-transcript.json"]),
        "interpretation_hash": keccak256(inputs["interpretation-transcript.json"]),
        "profile_hash": fixture.profile.profile_hash, "selection_hash": keccak256(selection),
        "plan_hash": keccak256(plan)}
    if set(inputs) != set(INPUT_FILES):
        raise MuseumError("offline TGN fixture recorded input denominator")
    recorded = build_recorded_package(inputs, root=ROOT, disclosure="public", **pins)
    request = dumps({"version": "1", "requests": [{"entityId": fixture.entity["id"],
        "entityKind": "Place", "authority": "GETTY_TGN", "sourceText": "Milos"}]})
    snapshots = {"authorities/getty-tgn-7002327.rdf.json":
        (fixture.snapshot_descriptor, fixture.snapshot_raw, fixture.snapshot_descriptor_hash)}
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "recorded"; write_package(recorded, path)
        result = build_authority_package(path, recorded.manifest_hash, request, selection, snapshots,
            request_hash=keccak256(request), selection_hash=keccak256(selection),
            profile_hash=authority_v2.PROFILE_HASH, disclosure="public")
    report = loads(dict(result.files)["authority/report.json"], maximum=2097152, canonical=True)
    files = dict(result.files); files["manifest.json"] = result.manifest
    return {"files": files, "manifest": result.manifest,
        "manifestHash": result.manifest_hash, "sourceManifestHash": recorded.manifest_hash,
        "report": report, "declarationBytes": fixture.declaration_raw,
        "declarationPayloadHash": keccak256(fixture.declaration_raw),
        "declarationHash": keccak256(dumps(fixture.entity)), "declarationEntity": fixture.entity,
        "declarationSelector": fixture.declaration_selector,
        "authorityDeclarationHash": keccak256(dumps(fixture.authority_entity)),
        "authorityDeclarationEntity": fixture.authority_entity,
        "authorityDeclarationSelector": fixture.authority_declaration_selector,
        "entityId": fixture.entity["id"], "authorityAssertionId": fixture.assertion["id"],
        "authorityAssertionHash": keccak256(dumps(fixture.assertion)),
        "context": {"chainId": str(CHAIN_ID), "core": fixture.core,
            "host": fixture.host, "blockNumber": str(fixture.publication_block),
            "blockHash": fixture.block["hash"], "timestamp": str(fixture.timestamp)},
        "provenance": {"mode": PROVENANCE, "actualRpc": False, "actualEvm": False,
            "cryptographicStateProof": False, "consensusFinality": False,
            "authorityPublisherAuthenticated": False, "independentHumanReview": False},
        "variant": {"matchKind": match_kind, "reviewStatus": review_status,
            "alternateDeclaration": alternate_declaration, "publicationBlock": publication_block}}
