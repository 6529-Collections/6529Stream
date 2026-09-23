"""Fresh native dossier records for the isolated current token fixture.

This mixin only composes already pinned native products.  It does not start a
chain, change the original token/media records, or turn fixture statements into
Museum acceptance.  A caller invokes :meth:`publish_native_dossier_records`
after ``CurrentTokenFixture.after_media_publications`` and before selecting the
single source block used by the read-only catalogue adapters.
"""

from .account_profile import JCS_ID
from .canonical import dumps, hex_bytes, keccak256, schema_id, subject_id, uint
from .chain_abi import decode, encode
from .current_museum_capture import h
from .independent_publication import EVENT_DATA as INDEPENDENT_EVENT_DATA
from .independent_publication import EVENT_TOPIC as INDEPENDENT_EVENT_TOPIC
from .independent_wire import (RAW_BYTES, RECEIPT as INDEPENDENT_RECEIPT, RECORD, SUBJECT,
    ZERO, ZERO_ADDRESS, generic_hash, json_values, require,
    verify_record as verify_independent_record)
from .metadata_catalog_source import verify_record as verify_metadata_record
from .owner_catalog_source import (OWNER_RECORD, RECORD_EVENT as OWNER_EVENT_TOPIC,
    verify_native_wire as verify_owner_record)


OWNER = "StreamOwnerRecords"
INDEPENDENT = "StreamCollectionAttestations"
METADATA = "StreamCollectionMetadataV1"
REGISTRY = "StreamModuleRegistry"

OWNER_MANIFEST_URI = "https://example.org/local-token-dossier/owner-records.json"
OWNER_MANIFEST_HASH = schema_id("local token dossier OwnerRecords module manifest")
OWNER_SCHEMA_NAME = "LOCAL_TOKEN_DOSSIER_OWNER_CONDITION_V1"
METADATA_SCHEMA_NAME = "LOCAL_TOKEN_DOSSIER_CURATOR_NOTE_V1"
INDEPENDENT_SCHEMA_NAME = "LOCAL_TOKEN_DOSSIER_DEPLOYMENT_NOTE_V1"
OWNER_RECORD_TYPE = schema_id("CONDITION_REPORT")
METADATA_RECORD_TYPE = schema_id("TOKEN_DOSSIER_CURATOR_NOTE")
INDEPENDENT_RECORD_TYPE = schema_id("INDEPENDENT_SEMANTIC_ASSERTION")
CURATOR_FAMILY = schema_id("6529STREAM_RECORD_FAMILY_CURATOR_V1")
CURATOR_CLASS = 3
CURATOR_MASK = 1 << CURATOR_CLASS
METADATA_EVENT_TOPIC = schema_id(
    "CollectionRecordRecorded(uint256,bytes32,bytes32,"
    "(bytes32,bytes32,(uint16,bytes,bytes32),string,bytes32,bytes32,(uint16,bytes,bytes32),uint64),"
    "bytes32,bytes32,address,bytes32,uint16)"
)
METADATA_EVENT_DATA = (RECORD, "bytes32", "bytes32", "address", "bytes32", "uint16")

OWNER_SCHEMA = dumps({
    "type": "object", "additionalProperties": False,
    "properties": {
        "kind": {"const": "local_token_dossier_owner_condition"},
        "statement": {"type": "string"},
        "subjectId": {"type": "string"},
        "tokenId": {"type": "string"},
        "version": {"const": "1"},
    },
    "required": ["kind", "statement", "subjectId", "tokenId", "version"],
})
METADATA_SCHEMA = dumps({
    "type": "object", "additionalProperties": False,
    "properties": {
        "authorizationClass": {"const": "CURATOR"},
        "collectionId": {"type": "string"},
        "kind": {"const": "local_token_dossier_curator_note"},
        "statement": {"type": "string"},
        "subjectId": {"type": "string"},
        "version": {"const": "1"},
    },
    "required": ["authorizationClass", "collectionId", "kind", "statement", "subjectId", "version"],
})
INDEPENDENT_SCHEMA = dumps({
    "type": "object", "additionalProperties": False,
    "properties": {
        "kind": {"const": "local_token_dossier_deployment_note"},
        "scopeKey": {"const": "0"},
        "statement": {"type": "string"},
        "subjectId": {"type": "string"},
        "version": {"const": "1"},
    },
    "required": ["kind", "scopeKey", "statement", "subjectId", "version"],
})

QUALIFICATION = (
    "Fresh local fixture Owner, Metadata and independent records from real pinned native products. "
    "They authenticate only their original local authors and protocol acceptance paths; they do not "
    "establish Museum acceptance, professional examination, institutional authority, consensus, or "
    "full object-dossier conformance."
)


def _transaction_hashes(rows):
    result = []
    for row in rows:
        value = row.get("transactionHash")
        require(isinstance(value, str) and hex_bytes(value, 32) != bytes(32),
            "native dossier transaction hash")
        result.append(value)
    return result


def _transaction_fields(fixture, receipt):
    """Retain the exact bounded RPC transaction fields used by this publication."""
    require(fixture.receipts and fixture.receipts[-1]["receipt"] == receipt,
        "native dossier publication receipt journal differs")
    row = fixture.receipts[-1]
    require(row["transactionHash"] == receipt.get("transactionHash")
        and isinstance(receipt.get("blockHash"), str)
        and isinstance(receipt.get("blockNumber"), str)
        and isinstance(receipt.get("transactionIndex"), str)
        and receipt.get("status") == "0x1",
        "native dossier publication transaction position differs")
    tx = row["transaction"]
    require(isinstance(tx, dict) and isinstance(tx.get("from"), str)
        and isinstance(tx.get("data"), str), "native dossier publication transaction fields")
    return {"transactionHash": row["transactionHash"], "from": tx["from"],
        "to": tx.get("to"), "inputHash": keccak256(hex_bytes(tx["data"])),
        "blockHash": receipt["blockHash"], "blockNumber": receipt["blockNumber"],
        "transactionIndex": receipt["transactionIndex"], "status": receipt.get("status")}


class TokenDossierPublicationsMixin:
    """Add genuine local native records without replacing the token fixture."""

    def _native_dossier_preflight(self):
        require(self.rpc("eth_chainId", []) == "0x7a69", "native dossier requires local chain 31337")
        require(hasattr(self, "token_scope") and hasattr(self, "token_buyer"),
            "native dossier requires an actual minted token")
        token = uint(self.token_scope.token_id)
        core = self.addresses["StreamCore"]
        require(token > 0 and self.token_scope.chain_id == "31337"
            and self.token_scope.core == core and self.token_scope.collection_id == "1",
            "native dossier token scope differs")
        require(self.call("StreamCore", "ownerOf", (token,)) == (self.token_buyer,)
            and self.call("StreamCore", "tokenCollectionIdentity", (token,)) == (True, 1, 1, False),
            "native dossier actual token owner/identity differs")
        require(self.token_buyer in self.rpc("eth_accounts", []),
            "native dossier direct owner is not an unlocked fixture account")
        require(self.attestor in self.safe_accounts, "native dossier writer must be an actual fixture Safe")

        metadata = self.addresses[METADATA]
        registry = self.addresses[REGISTRY]
        module_type, = self.call(METADATA, "streamModuleType")
        interface, = self.call(METADATA, "streamModuleInterfaceId")
        runtime = keccak256(hex_bytes(self.rpc("eth_getCode", [metadata, "latest"])))
        pointer = self.call("StreamCore", "getSatellitePointer", (schema_id("COLLECTION_METADATA"),))
        require(module_type == schema_id("COLLECTION_METADATA") and pointer[0] == metadata
            and pointer[1] == runtime and pointer[2] is False and pointer[3] == module_type
            and pointer[4] == interface and pointer[5] == registry,
            "native dossier existing Metadata is not the selected registered host")
        require(self.call(REGISTRY, "isModuleEligible", (metadata, module_type, interface)) == (True,)
            and self.call(METADATA, "core") == (core,)
            and self.call(METADATA, "schemaRegistry") == (self.schemas,)
            and self.call(METADATA, "chunkStore") == (self.store,)
            and self.call(METADATA, "artistRegistry") == (self.addresses["StreamArtistOnboardingRegistry"],),
            "native dossier selected Metadata dependencies differ")
        require(self.call(INDEPENDENT, "core") == (core,)
            and self.call(INDEPENDENT, "schemaRegistry") == (self.schemas,)
            and self.call(INDEPENDENT, "chunkStore") == (self.store,),
            "native dossier independent host dependencies differ")
        jcs, = self.call("StreamSchemaRegistry", "documentBytes", (JCS_ID,))
        require(jcs, "native dossier JCS definition is absent")
        return token

    def _register_native_dossier_module(self, name, expected_type):
        """Register one native self-described host without an interface artifact."""
        target = self.addresses[name]
        registry = self.addresses[REGISTRY]
        module_type, = self.call(name, "streamModuleType")
        version, = self.call(name, "streamModuleVersion")
        interface, = self.call(name, "streamModuleInterfaceId")
        uri, manifest_hash = self.call(name, "streamModuleManifest")
        raw_uri = uri.encode("utf-8") if isinstance(uri, str) else b""
        valid_uri = ((raw_uri.startswith(b"https://") and len(raw_uri) > 8
            and raw_uri[8] not in b"/?#") or (raw_uri.startswith(b"ipfs://") and len(raw_uri) > 7))
        require(module_type == expected_type and version != ZERO and manifest_hash != ZERO
            and interface != "0x00000000" and 0 < len(raw_uri) <= 2048 and valid_uri,
            "native dossier module identity differs")
        require(self.read(target, "supportsInterface(bytes4)", ("bytes4",), (interface,), ("bool",)) == (True,),
            "native dossier module does not support its declared interface")
        runtime = keccak256(hex_bytes(self.rpc("eth_getCode", [target, "latest"])))
        require(self.call(name, "streamModuleDeploymentManifestHash") == (self.deployment,)
            and self.call(name, "streamModuleCodeHash") == (runtime,),
            "native dossier module deployment/runtime commitment differs")
        item = (target, module_type, version, interface, 2000000, runtime,
            self.deployment, manifest_hash, uri)
        prior, = self.call(REGISTRY, "moduleRecord", (target,))
        require(prior[0] == 0, "native dossier module was already registered")
        chain, count = self.call(REGISTRY, "registrationChainHash")
        record_hash = h(("bytes32", "address", "bytes32", "bytes4", "bytes32", "bytes32", "bytes32", "bytes32"),
            (schema_id("6529STREAM_MODULE_REGISTRATION_RECORD_V1"), target, module_type,
             interface, version, runtime, self.deployment, manifest_hash))
        next_chain = h(("bytes32", "uint256", "address", "uint256", "bytes32", "bytes32", "bytes32", "uint64"),
            (schema_id("6529STREAM_RECORD_CHAIN_V1"), 31337, registry, 0,
             schema_id("MODULE_REGISTRATION"), chain, record_hash, count))
        fields = ("uint8", "bytes32", "bytes32", "bytes4", "uint32", "bytes32", "bytes32", "bytes32", "bytes32", "uint64")
        empty = h(fields, (0, ZERO, ZERO, "0x00000000", 0, ZERO, ZERO, ZERO, keccak256(b""), 0))
        facts = h(fields, (1, module_type, version, interface, 2000000, runtime,
            self.deployment, manifest_hash, keccak256(uri.encode("utf-8")), 1))
        scope = h(("bytes32", "uint256", "address", "address"),
            (schema_id("6529STREAM_MODULE_REGISTRATION_SCOPE_V1"), 31337, registry, target))
        state = ("bytes32", "bytes32", "bool", "bytes32", "uint256", "bytes32", "uint64", "address")
        old = h(state, (schema_id("6529STREAM_MODULE_REGISTRATION_STATE_V1"), scope,
            False, empty, count, chain, count, ZERO_ADDRESS))
        new = h(state, (schema_id("6529STREAM_MODULE_REGISTRATION_STATE_V1"), scope,
            True, facts, count + 1, next_chain, count + 1, target))
        before = len(self.receipts)
        self.govern_configuration(REGISTRY, "registerModule", (item,), (scope, old, new))
        record, = self.call(REGISTRY, "moduleRecord", (target,))
        require(record[:9] == (1, module_type, version, interface, 2000000, runtime,
            self.deployment, manifest_hash, uri)
            and self.call(REGISTRY, "isModuleEligible", (target, module_type, interface)) == (True,),
            "native dossier registered module readback differs")
        return {"name": name, "host": target, "moduleType": module_type,
            "moduleVersion": version, "interfaceId": interface, "runtimeHash": runtime,
            "deploymentManifestHash": self.deployment, "moduleManifestHash": manifest_hash,
            "moduleManifestURI": uri, "registry": registry,
            "transactions": _transaction_hashes(self.receipts[before:])}

    def _deploy_native_owner_host(self):
        core = self.addresses["StreamCore"]
        executor = self.addresses["StreamGovernanceExecutor"]
        address = self.deploy(OWNER, ((core, self.schemas, executor, self.deployment,
            OWNER_MANIFEST_URI, OWNER_MANIFEST_HASH,
            ("METADATA_ERC1271_VERIFY_GAS", 400000, 90000, 2),
            ("METADATA_DEPENDENCY_READ_GAS", 300000, 50000, 2)),))
        require(self.call(OWNER, "core") == (core,)
            and self.call(OWNER, "schemaRegistry") == (self.schemas,)
            and self.call(OWNER, "chunkStore") == (self.store,)
            and self.call(OWNER, "streamModuleManifest") == (OWNER_MANIFEST_URI, OWNER_MANIFEST_HASH),
            "native dossier OwnerRecords constructor binding differs")
        return address

    def _publish_native_owner_record(self, token, schema):
        host = self.addresses[OWNER]
        subject, = self.call(OWNER, "deriveOwnerSubject", (token,))
        require(subject == subject_id("token", "31337", self.addresses["StreamCore"], "1",
            token_id=str(token)), "native dossier owner subject differs")
        payload = dumps({"kind": "local_token_dossier_owner_condition",
            "statement": "Local fixture owner statement; no professional examination.",
            "subjectId": subject, "tokenId": str(token), "version": "1"})
        effective = int(self.rpc("eth_getBlockByNumber", ["latest", False])["timestamp"], 16)
        record = (OWNER_RECORD_TYPE, subject, schema, (1, hex_bytes(keccak256(payload)), JCS_ID),
            "", payload, effective)
        before_chain = self.call(OWNER, "recordChainHash", (token, OWNER_RECORD_TYPE))
        require(before_chain == (ZERO, 0), "native dossier owner lane is not fresh")
        receipt = self.send(self.data(OWNER, "recordOwnerRecord", (token, record)), host,
            sender=self.token_buyer)
        events = [row for row in receipt["logs"] if row["address"] == host
            and row.get("topics") and row["topics"][0] == OWNER_EVENT_TOPIC]
        require(len(events) == 1, "native dossier requires one Owner record event")
        topics = events[0]["topics"]
        require(len(topics) == 4 and int.from_bytes(hex_bytes(topics[1], 32), "big") == token
            and topics[2] == OWNER_RECORD_TYPE
            and hex_bytes(topics[3], 32)[12:] == hex_bytes(self.token_buyer, 20),
            "native dossier Owner indexed event differs")
        event_record, record_hash, chain_hash, relayed, version = decode(
            (OWNER_RECORD, "bytes32", "bytes32", "bool", "uint16"),
            hex_bytes(events[0]["data"]), maximum=32768)
        saved, saved_receipt = self.call(OWNER, "ownerRecord", (record_hash,))
        _, bundle = self.call(OWNER, "ownerRecordSignatureBundle", (record_hash,))
        stamp = int(self.rpc("eth_getBlockByNumber", ["latest", False])["timestamp"], 16)
        require(event_record == saved == record and relayed is False and version == 1
            and saved_receipt[1] == self.token_buyer and saved_receipt[4] == chain_hash
            and self.call(OWNER, "recordChainHash", (token, OWNER_RECORD_TYPE)) == (chain_hash, 1),
            "native dossier Owner receipt/readback differs")
        verify_owner_record(31337, host, self.addresses["StreamCore"], stamp,
            record_hash, token, saved, saved_receipt, bundle)
        return {"host": host, "recordHash": record_hash, "recordType": OWNER_RECORD_TYPE,
            "tokenId": str(token), "subjectId": subject, "author": self.token_buyer,
            "authorization": "DIRECT_CURRENT_OWNER", "recordIndex": "0",
            "recordChainHash": chain_hash, "transactionHash": receipt["transactionHash"],
            "record": json_values(saved), "nativeReceipt": json_values(saved_receipt),
            "signatureBundle": json_values(bundle),
            "event": json_values((event_record, record_hash, chain_hash, relayed, version)),
            "transaction": _transaction_fields(self, receipt)}

    def _publish_native_metadata_record(self, schema):
        host = self.addresses[METADATA]
        core = self.addresses["StreamCore"]
        subject = subject_id("collection", "31337", core, "1")
        payload = dumps({"authorizationClass": "CURATOR", "collectionId": "1",
            "kind": "local_token_dossier_curator_note",
            "statement": "Local fixture curator statement; no Museum acceptance.",
            "subjectId": subject, "version": "1"})
        admission = (METADATA_RECORD_TYPE, CURATOR_FAMILY, CURATOR_MASK)
        policy, = self.call(METADATA, "recordPolicy", (METADATA_RECORD_TYPE,))
        require(policy == (ZERO, 0, False),
            "native dossier Metadata type is not fresh")
        self.govern_configuration(METADATA, "admitRecordType", admission,
            self.call(METADATA, "recordTypeTransition", admission))
        policy, = self.call(METADATA, "recordPolicy", (METADATA_RECORD_TYPE,))
        require(policy == (CURATOR_FAMILY, CURATOR_MASK, True),
            "native dossier Metadata policy differs")
        grant = (1, CURATOR_FAMILY, CURATOR_CLASS, self.attestor, True)
        self.govern_configuration(METADATA, "setFamilyWriter", grant,
            self.call(METADATA, "familyWriterTransition", grant))
        require(self.call(METADATA, "familyWriter", grant[:-1]) == (True, 1),
            "native dossier Metadata writer grant differs")
        effective = int(self.rpc("eth_getBlockByNumber", ["latest", False])["timestamp"], 16)
        record = (METADATA_RECORD_TYPE, subject, (1, hex_bytes(keccak256(payload)), JCS_ID),
            "", schema, ZERO, (0, b"", ZERO), effective)
        expected, = self.call(METADATA, "deriveCollectionRecordHashFor", (self.attestor, 1, record))
        require(expected == generic_hash(31337, host, core, 1, self.attestor, record)
            and self.call(METADATA, "recordChainHash", (1, METADATA_RECORD_TYPE)) == (ZERO, 0),
            "native dossier Metadata original preimage/lane differs")
        receipt = self.transact(METADATA, "recordCollectionRecordWithPayload", (1, record, payload),
            safe=self.attestor)
        events = [row for row in receipt["logs"] if row["address"] == host
            and row.get("topics") and row["topics"][0] == METADATA_EVENT_TOPIC]
        require(len(events) == 1, "native dossier requires one Metadata record event")
        topics = events[0]["topics"]
        require(len(topics) == 4 and int.from_bytes(hex_bytes(topics[1], 32), "big") == 1
            and topics[2] == METADATA_RECORD_TYPE and topics[3] == subject,
            "native dossier Metadata indexed event differs")
        event_record, event_hash, event_chain, event_writer, event_authority, event_version = decode(
            METADATA_EVENT_DATA, hex_bytes(events[0]["data"]), maximum=32768)
        saved, saved_receipt = self.call(METADATA, "collectionRecord", (expected,))
        _, saved_payload = self.call(METADATA, "recordPayload", (expected,))
        stamp = int(self.rpc("eth_getBlockByNumber", ["latest", False])["timestamp"], 16)
        require(event_record == saved == record and event_hash == expected
            and event_chain == saved_receipt[5] and event_writer == self.attestor
            and event_authority == "0x" + CURATOR_CLASS.to_bytes(32, "big").hex()
            and event_version == 1 and saved_payload == payload
            and saved_receipt[0:3] == (1, self.attestor, CURATOR_CLASS)
            and self.call(METADATA, "recordChainHash", (1, METADATA_RECORD_TYPE)) == (saved_receipt[5], 1),
            "native dossier Metadata record readback differs")
        verify_metadata_record(31337, host, core, 1, stamp, expected,
            METADATA_RECORD_TYPE, (CURATOR_FAMILY, CURATOR_MASK, True), 0, ZERO,
            saved, saved_receipt, saved_payload)
        return {"host": host, "recordHash": expected, "recordType": METADATA_RECORD_TYPE,
            "collectionId": "1", "subjectId": subject, "author": self.attestor,
            "authorization": "CURATOR", "authorizationClass": str(CURATOR_CLASS),
            "recordIndex": "0", "recordChainHash": saved_receipt[5],
            "transactionHash": receipt["transactionHash"], "record": json_values(saved),
            "nativeReceipt": json_values(saved_receipt), "payload": json_values(saved_payload),
            "event": json_values((event_record, event_hash, event_chain, event_writer,
                event_authority, event_version)),
            "transaction": _transaction_fields(self, receipt)}

    def _publish_native_deployment_record(self, schema):
        host = self.addresses[INDEPENDENT]
        core = self.addresses["StreamCore"]
        subject = (0, 0, 0, ZERO)
        subject_id_, = self.call(INDEPENDENT, "deriveSubject", (subject,))
        require(subject_id_ == subject_id("collection", "31337", core, "0"),
            "native dossier deployment subject differs")
        payload = dumps({"kind": "local_token_dossier_deployment_note", "scopeKey": "0",
            "statement": "Local fixture deployment statement; no external authority.",
            "subjectId": subject_id_, "version": "1"})
        effective = int(self.rpc("eth_getBlockByNumber", ["latest", False])["timestamp"], 16)
        nonce = int(self.capture_context["nextNonce"]) + 4
        require(self.call(INDEPENDENT, "isIndependentAttestorNonceUsed", (self.attestor, nonce)) == (False,)
            and self.call(INDEPENDENT, "recordChainHash", (0, INDEPENDENT_RECORD_TYPE)) == (ZERO, 0),
            "native dossier deployment lane/nonce is not fresh")
        request = (self.attestor, 0, subject_id_, INDEPENDENT_RECORD_TYPE, schema, 1,
            hex_bytes(keccak256(payload)), JCS_ID, "", payload, effective, nonce, effective + 86400)
        receipt = self.transact(INDEPENDENT, "recordIndependentPreservation",
            (subject, request, b""), safe=self.attestor)
        events = [row for row in receipt["logs"] if row["address"] == host
            and row.get("topics") and row["topics"][0] == INDEPENDENT_EVENT_TOPIC]
        require(len(events) == 1, "native dossier requires one independent deployment event")
        topics = events[0]["topics"]
        require(len(topics) == 4 and int.from_bytes(hex_bytes(topics[1], 32), "big") == 0
            and topics[2] == INDEPENDENT_RECORD_TYPE and topics[3] == subject_id_,
            "native dossier independent indexed event differs")
        event_record, record_hash, chain_hash, attestor, authority, version = decode(
            INDEPENDENT_EVENT_DATA, hex_bytes(events[0]["data"]), maximum=32768)
        saved, saved_receipt = self.call(INDEPENDENT, "collectionRecord", (record_hash,))
        saved_subject, = self.call(INDEPENDENT, "recordSubject", (record_hash,))
        _, saved_payload = self.call(INDEPENDENT, "recordPayload", (record_hash,))
        _, bundle = self.call(INDEPENDENT, "recordSignatureBundle", (record_hash,))
        stamp = int(self.rpc("eth_getBlockByNumber", ["latest", False])["timestamp"], 16)
        require(event_record == saved and saved_subject == subject and saved_payload == payload
            and attestor == self.attestor and authority == "0x" + (5).to_bytes(32, "big").hex()
            and version == 1 and saved_receipt[5] == chain_hash
            and self.call(INDEPENDENT, "recordChainHash", (0, INDEPENDENT_RECORD_TYPE)) == (chain_hash, 1),
            "native dossier independent deployment readback differs")
        verify_independent_record(31337, host, core, stamp,
            (0, INDEPENDENT_RECORD_TYPE), 0, ZERO, record_hash,
            encode((RECORD, INDEPENDENT_RECEIPT), (saved, saved_receipt)),
            encode((SUBJECT,), (saved_subject,)), saved_payload, bundle)
        return {"host": host, "recordHash": record_hash,
            "recordType": INDEPENDENT_RECORD_TYPE, "scopeKey": "0", "subjectId": subject_id_,
            "author": self.attestor, "authorization": "INDEPENDENT_ATTESTOR",
            "recordIndex": "0", "recordChainHash": chain_hash, "nonce": str(nonce),
            "transactionHash": receipt["transactionHash"], "record": json_values(saved),
            "nativeReceipt": json_values(saved_receipt), "subject": json_values(saved_subject),
            "signatureBundle": json_values(bundle),
            "event": json_values((event_record, record_hash, chain_hash, attestor, authority, version)),
            "transaction": _transaction_fields(self, receipt)}

    def publish_native_dossier_records(self):
        """Publish and retain one actual record in each added native lane."""
        require(not hasattr(self, "native_dossier_records"),
            "native dossier records cannot be published twice")
        token = self._native_dossier_preflight()
        start = len(self.receipts)
        self._deploy_native_owner_host()
        registrations = [
            self._register_native_dossier_module(OWNER, schema_id("OWNER_RECORDS")),
            self._register_native_dossier_module(INDEPENDENT, schema_id("COLLECTION_ATTESTATIONS")),
        ]
        owner_schema = self.register_document(OWNER_SCHEMA_NAME, 0, OWNER_SCHEMA, JCS_ID)
        metadata_schema = self.register_document(METADATA_SCHEMA_NAME, 0, METADATA_SCHEMA, JCS_ID)
        independent_schema = self.register_document(INDEPENDENT_SCHEMA_NAME, 0, INDEPENDENT_SCHEMA, JCS_ID)
        records = {
            "owner": self._publish_native_owner_record(token, owner_schema),
            "metadata": self._publish_native_metadata_record(metadata_schema),
            "independent": self._publish_native_deployment_record(independent_schema),
        }
        record_hashes = {name: row["recordHash"] for name, row in records.items()}
        scopes = [
            {"kind": "owner", "host": records["owner"]["host"], "scopeKey": str(token)},
            {"kind": "metadata", "host": records["metadata"]["host"], "scopeKey": "1"},
            {"kind": "independent", "host": records["independent"]["host"], "scopeKey": "0"},
        ]
        result = {"registrations": registrations, "records": records,
            "recordHashes": record_hashes, "scopes": scopes,
            "transactions": _transaction_hashes(self.receipts[start:]),
            "actualChainAcceptance": False, "fullObjectDossierConformance": False,
            "qualification": QUALIFICATION}
        # Ensure the evidence itself contains only canonical JSON-compatible values.
        dumps(result)
        self.native_dossier_records = result
        return result
