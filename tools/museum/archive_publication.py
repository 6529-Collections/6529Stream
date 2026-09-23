"""Bounded current-stack publication of a retained semantic-export manifest.

This module is deliberately lane specific.  It uses the selected
``StreamCollectionMetadataV1`` host and its ARCHIVE family grants; it never
routes an export through the permissionless independent-attestation host or
through the collection-snapshot host.
"""

from __future__ import annotations

import jsonschema

from .account_profile import JCS_BYTES
from .canonical import (
    dumps, hex_bytes, keccak256, loads, record_chain, schema_id,
    subject_id as derive_subject_id, uint,
)
from .chain_abi import decode
from .independent_wire import DOCUMENT, RECORD, ZERO, ZERO_ADDRESS, generic_hash, json_values, require
from .semantic_export import NAME as EXPORT_SCHEMA_NAME
from .semantic_export import POLICY_BYTES as EXPORT_POLICY_BYTES
from .semantic_export import POLICY_NAME as EXPORT_POLICY_NAME
from .semantic_export import SCHEMA_BYTES as EXPORT_SCHEMA_BYTES
from .semantic_export import SCHEMA_HASH as EXPORT_SCHEMA_HASH
from .typed_authority_profile import NAMES as TYPED_NAMES


METADATA = "StreamCollectionMetadataV1"
SCHEMAS = "StreamSchemaRegistry"
RECORD_TYPE_NAME = "ARCHIVE_SEMANTIC_EXPORT"
FAMILY_NAME = "6529STREAM_RECORD_FAMILY_ARCHIVE_V1"
RECORD_TYPE = schema_id(RECORD_TYPE_NAME)
FAMILY = schema_id(FAMILY_NAME)
JCS = schema_id("RFC8785_JCS")
ARCHIVE_MASK = (1 << 6) | (1 << 8)
MAX_PAYLOAD_BYTES = 8192
AUTHORITY_NAMES = {6: "PRESERVATION_ADMIN", 8: "GLOBAL_ADMIN"}
RECEIPT = (
    "uint256", "address", "uint8", "uint64", "uint64", "bytes32",
    "bytes32", "bytes32", "bytes32",
)
EVENT_TOPIC = keccak256(
    b"CollectionRecordRecorded(uint256,bytes32,bytes32,"
    b"(bytes32,bytes32,(uint16,bytes,bytes32),string,bytes32,bytes32,"
    b"(uint16,bytes,bytes32),uint64),bytes32,bytes32,address,bytes32,uint16)"
)
_EVENT_DATA = (RECORD, "bytes32", "bytes32", "address", "bytes32", "uint16")


def _address(value, label):
    try:
        raw = hex_bytes(value, 20)
    except Exception as exc:
        raise type(exc)(str(exc)) from exc
    require(raw != bytes(20), label + " address")
    return "0x" + raw.hex()


def _number(value, bits=256):
    if type(value) is int:
        result = value
    elif isinstance(value, str) and value.startswith("0x"):
        require(value == hex(int(value, 16)), "noncanonical quantity")
        result = int(value, 16)
    else:
        result = uint(value, bits)
    require(0 <= result < 1 << bits, "unsigned integer overflow")
    return result


def validate_manifest(
    manifest_bytes,
    schema_bytes,
    *,
    schema_name,
    schema_hash,
    chain_id,
    core,
    collection_id,
    subject_id,
    source_block_number,
    source_block_hash,
):
    """Validate the exact canonical payload and its externally pinned source scope."""
    require(type(manifest_bytes) is bytes and 0 < len(manifest_bytes) <= MAX_PAYLOAD_BYTES,
            "archive semantic-export payload bound")
    require(type(schema_bytes) is bytes and 0 < len(schema_bytes) <= 524288,
            "archive semantic-export schema bound")
    require(schema_name == EXPORT_SCHEMA_NAME and schema_bytes == EXPORT_SCHEMA_BYTES
            and schema_hash == EXPORT_SCHEMA_HASH,
            "archive semantic-export schema pin")
    require(keccak256(schema_bytes) == schema_hash, "archive semantic-export schema hash")
    schema = loads(schema_bytes, maximum=524288, canonical=True)
    require(isinstance(schema, dict) and schema.get("title") == schema_name
            and schema.get("x-stream-schema-id") == schema_id(schema_name),
            "archive semantic-export schema identity")
    value = loads(manifest_bytes, maximum=MAX_PAYLOAD_BYTES, canonical=True)
    try:
        jsonschema.Draft202012Validator(
            schema, format_checker=jsonschema.FormatChecker()
        ).validate(value)
    except jsonschema.ValidationError as exc:
        raise ValueError("archive semantic-export schema rejected") from exc
    require(isinstance(value, dict) and isinstance(value.get("sourceState"), dict),
            "archive semantic-export source state")
    state = value["sourceState"]
    chain = _number(chain_id)
    collection = _number(collection_id)
    block_number = _number(source_block_number)
    core = _address(core, "core")
    hex_bytes(subject_id, 32)
    hex_bytes(source_block_hash, 32)
    require(
        state.get("chainId") == str(chain)
        and state.get("core") == core
        and state.get("collectionId") == str(collection)
        and state.get("blockNumber") == str(block_number)
        and state.get("blockHash") == source_block_hash
        and isinstance(state.get("anchorSubject"), dict)
        and state["anchorSubject"].get("subjectId") == subject_id,
        "archive semantic-export source binding",
    )
    kind = state["anchorSubject"].get("kind")
    token = state.get("tokenId")
    require(kind in ("collection", "token")
            and ((kind == "collection" and token is None)
                 or (kind == "token" and isinstance(token, str) and _number(token) > 0)),
            "archive semantic-export subject type")
    expected_subject = derive_subject_id(
        kind, str(chain), core, str(collection), token_id="0" if token is None else token
    )
    require(subject_id == expected_subject, "archive semantic-export subject preimage")
    require(value.get("exportPolicy") == {
        "path": "definitions/" + EXPORT_POLICY_NAME + ".json",
        "contentHash": {"algorithm": "1", "digest": keccak256(EXPORT_POLICY_BYTES),
                        "canonicalizationId": JCS},
        "byteLength": str(len(EXPORT_POLICY_BYTES)),
        "mediaType": "application/json",
    }, "archive semantic-export policy pin")
    selectors = list(state.get("recordHeads", []))
    selectors += list(value.get("sourceAuthoritySet", []))
    selectors += list(value.get("reviewerAuthoritySet", []))
    require(all(isinstance(row, dict) and row.get("recordType") != RECORD_TYPE for row in selectors),
            "archive record cannot be a semantic-export source")
    return value


def configure_archive_lane(fixture, writer, authorization_class, *, collection_id=1):
    """Govern one fresh type admission and one exact ARCHIVE writer grant."""
    require(authorization_class in AUTHORITY_NAMES, "archive authorization class")
    writer = _address(writer, "archive writer")
    collection = _number(collection_id)
    require(collection > 0, "archive collection")
    admission = (RECORD_TYPE, FAMILY, ARCHIVE_MASK)
    before = len(fixture.receipts)
    transition = fixture.call(METADATA, "recordTypeTransition", admission)
    fixture.governed(METADATA, "admitRecordType", admission, transition)
    admission_transactions = fixture.receipts[before:]
    policy, = fixture.call(METADATA, "recordPolicy", (RECORD_TYPE,))
    require(policy == (FAMILY, ARCHIVE_MASK, True), "archive policy admission differs")

    grant = (collection, FAMILY, authorization_class, writer, True)
    before = len(fixture.receipts)
    transition = fixture.call(METADATA, "familyWriterTransition", grant)
    fixture.governed(METADATA, "setFamilyWriter", grant, transition)
    grant_transactions = fixture.receipts[before:]
    require(fixture.call(METADATA, "familyWriter", grant[:-1]) == (True, 1),
            "archive family grant differs")
    return {
        "recordType": RECORD_TYPE,
        "family": FAMILY,
        "authorizationMask": str(ARCHIVE_MASK),
        "authorizationClass": str(authorization_class),
        "authorizationClassName": AUTHORITY_NAMES[authorization_class],
        "writer": writer,
        "collectionId": str(collection),
        "admissionTransactions": admission_transactions,
        "grantTransactions": grant_transactions,
    }


def _event(receipt, host, collection_id, subject_id, record, expected_hash, expected_chain,
           writer, authorization_class):
    matches = [row for row in receipt.get("logs", [])
               if row.get("address") == host and row.get("topics", [None])[0] == EVENT_TOPIC]
    require(len(matches) == 1, "archive publication event")
    event = matches[0]
    topics = event.get("topics", [])
    require(len(topics) == 4
            and decode(("uint256",), hex_bytes(topics[1])) == (collection_id,)
            and topics[2] == RECORD_TYPE and topics[3] == subject_id,
            "archive publication event topics")
    saved_record, record_hash, chain_hash, recorder, auth_word, version = decode(
        _EVENT_DATA, hex_bytes(event.get("data", "0x")), maximum=1048576
    )
    require(saved_record == record and record_hash == expected_hash and chain_hash == expected_chain
            and recorder == writer and int(auth_word, 16) == authorization_class and version == 1,
            "archive publication event data")
    require(event.get("transactionHash") == receipt.get("transactionHash")
            and event.get("transactionIndex") == receipt.get("transactionIndex"),
            "archive publication event transaction")
    return event


def _ancestry(fixture, publication_block, source_block):
    ancestry = []
    current = publication_block
    source_number = _number(source_block["number"])
    while True:
        ancestry.append(current)
        number = _number(current["number"])
        if number == source_number:
            break
        require(number > source_number and len(ancestry) < 65,
                "archive publication ancestry bound")
        parent = fixture.rpc("eth_getBlockByHash", [current["parentHash"], False])
        require(parent is not None and parent.get("hash") == current["parentHash"]
                and _number(parent["number"]) + 1 == number
                and _number(parent["timestamp"]) < _number(current["timestamp"]),
                "archive publication ancestry continuity")
        current = parent
    require(2 <= len(ancestry) <= 65
            and current.get("hash") == source_block.get("hash")
            and current.get("stateRoot") == source_block.get("stateRoot")
            and current.get("timestamp") == source_block.get("timestamp"),
            "archive publication ancestry source")
    return ancestry


def publish_archive_export(
    fixture,
    manifest_bytes,
    schema_bytes,
    *,
    schema_name,
    schema_hash,
    source_block_number,
    source_block_hash,
    subject_id,
    writer,
    authorization_class,
    collection_id=1,
    uri="",
    effective_at,
):
    """Publish and read back one already-built semantic-export manifest.

    The fixture must already have selected ``StreamCollectionMetadataV1``,
    registered the exact schema and JCS definitions, and completed
    :func:`configure_archive_lane` for ``writer``.
    """
    require(authorization_class in AUTHORITY_NAMES, "archive authorization class")
    writer = _address(writer, "archive writer")
    host = _address(fixture.addresses[METADATA], "metadata host")
    core = _address(fixture.addresses["StreamCore"], "core")
    collection = _number(collection_id)
    effective = _number(effective_at, 64)
    block_number = _number(source_block_number)
    require(collection > 0 and effective > 0, "archive publication numeric fields")
    require(type(uri) is str and len(uri.encode("utf-8")) <= 2048,
            "archive publication URI bound")
    value = validate_manifest(
        manifest_bytes,
        schema_bytes,
        schema_name=schema_name,
        schema_hash=schema_hash,
        chain_id=fixture.rpc("eth_chainId", []),
        core=core,
        collection_id=collection,
        subject_id=subject_id,
        source_block_number=block_number,
        source_block_hash=source_block_hash,
    )
    source_block = fixture.rpc("eth_getBlockByNumber", [hex(block_number), False])
    require(source_block is not None and source_block.get("hash") == source_block_hash,
            "archive source block differs")
    schema_id_ = schema_id(schema_name)
    policy_id = schema_id(EXPORT_POLICY_NAME)
    actual_schema, = fixture.call(SCHEMAS, "documentBytes", (schema_id_,))
    actual_policy, = fixture.call(SCHEMAS, "documentBytes", (policy_id,))
    actual_jcs, = fixture.call(SCHEMAS, "documentBytes", (JCS,))
    schema_view, = fixture.call(SCHEMAS, "document", (schema_id_,))
    policy_view, = fixture.call(SCHEMAS, "document", (policy_id,))
    schema_view_call = fixture.data(SCHEMAS, "document", (schema_id_,))
    policy_view_call = fixture.data(SCHEMAS, "document", (policy_id,))
    schema_view_raw = fixture.rpc("eth_call", [{"to": fixture.addresses[SCHEMAS],
        "data": schema_view_call}, "latest"])
    policy_view_raw = fixture.rpc("eth_call", [{"to": fixture.addresses[SCHEMAS],
        "data": policy_view_call}, "latest"])
    require(decode((DOCUMENT,), hex_bytes(schema_view_raw), maximum=1048576) == (schema_view,)
            and decode((DOCUMENT,), hex_bytes(policy_view_raw), maximum=1048576) == (policy_view,),
            "archive registered definition raw view differs")
    schema_spec = (schema_name, 0, schema_hash, JCS, schema_id(TYPED_NAMES[2]), "",
                   len(schema_bytes))
    policy_spec = (EXPORT_POLICY_NAME, 2, keccak256(EXPORT_POLICY_BYTES), JCS, ZERO, "",
                   len(EXPORT_POLICY_BYTES))
    require(actual_schema == schema_bytes and actual_policy == EXPORT_POLICY_BYTES
            and actual_jcs == JCS_BYTES,
            "archive registered definition bytes differ")
    require(schema_view[0:2] == (True, 0) and schema_view[3] == schema_spec
            and policy_view[0:2] == (True, 0) and policy_view[3] == policy_spec,
            "archive registered definition view differs")
    policy, = fixture.call(METADATA, "recordPolicy", (RECORD_TYPE,))
    require(policy == (FAMILY, ARCHIVE_MASK, True),
            "archive policy differs at publication")
    enabled, grant_revision = fixture.call(
        METADATA, "familyWriter", (collection, FAMILY, authorization_class, writer)
    )
    require(enabled and grant_revision > 0, "archive writer grant unavailable")

    record = (
        RECORD_TYPE,
        subject_id,
        (1, hex_bytes(keccak256(manifest_bytes), 32), JCS),
        uri,
        schema_id(schema_name),
        ZERO,
        (0, b"", ZERO),
        effective,
    )
    expected_hash, = fixture.call(
        METADATA, "deriveCollectionRecordHashFor", (writer, collection, record)
    )
    require(expected_hash == generic_hash(
        _number(fixture.rpc("eth_chainId", [])), host, core, collection, writer, record
    ), "archive record hash preimage differs")
    previous_chain, previous_count = fixture.call(
        METADATA, "recordChainHash", (collection, RECORD_TYPE)
    )
    data = fixture.data(METADATA, "recordCollectionRecordWithPayload",
                        (collection, record, manifest_bytes))
    before = len(fixture.receipts)
    receipt = fixture.safe_call(writer, host, data)
    transactions = fixture.receipts[before:]
    require(receipt.get("status") == "0x1" and _number(receipt["blockNumber"]) > block_number,
            "archive publication did not follow source block")
    publication_block = fixture.rpc("eth_getBlockByNumber", [receipt["blockNumber"], False])
    require(publication_block is not None and publication_block.get("hash") == receipt.get("blockHash"),
            "archive publication block differs")
    transaction_index = _number(receipt.get("transactionIndex"))
    require(isinstance(publication_block.get("transactions"), list)
            and transaction_index < len(publication_block["transactions"])
            and publication_block["transactions"][transaction_index] == receipt.get("transactionHash"),
            "archive publication transaction inclusion")
    ancestry = _ancestry(fixture, publication_block, source_block)
    source_recheck = fixture.rpc("eth_getBlockByHash", [source_block_hash, False])
    require(source_recheck == ancestry[-1] and source_recheck == source_block,
            "archive source block changed after publication")

    saved_record, saved_receipt = fixture.call(METADATA, "collectionRecord", (expected_hash,))
    pointer, saved_payload = fixture.call(METADATA, "recordPayload", (expected_hash,))
    latest, = fixture.call(
        METADATA, "latestCollectionRecordHashFor",
        (collection, RECORD_TYPE, subject_id, writer),
    )
    indexed, = fixture.call(
        METADATA, "recordHashAt", (collection, RECORD_TYPE, saved_receipt[4])
    )
    chain_head, chain_count = fixture.call(METADATA, "recordChainHash", (collection, RECORD_TYPE))
    require(saved_record == record and saved_payload == manifest_bytes and pointer != ZERO_ADDRESS,
            "archive record payload readback differs")
    expected_chain = record_chain(str(_number(fixture.rpc("eth_chainId", []))), host,
        str(collection), RECORD_TYPE, previous_chain, expected_hash, str(previous_count))
    require(saved_receipt[0] == collection and saved_receipt[1] == writer
            and saved_receipt[2] == authorization_class and saved_receipt[4] == previous_count
            and saved_receipt[4] + 1 == chain_count
            and saved_receipt[5] == chain_head and saved_receipt[6] == schema_hash
            and saved_receipt[7] == keccak256(JCS_BYTES) and saved_receipt[8] == ZERO,
            "archive record receipt differs")
    require(saved_receipt[5] == expected_chain
            and _number(publication_block["timestamp"]) == saved_receipt[3],
            "archive chain or publication time differs")
    require(latest == expected_hash and indexed == expected_hash,
            "archive record index differs")
    event = _event(receipt, host, collection, subject_id, record, expected_hash,
                   saved_receipt[5], writer, authorization_class)
    selectors = list(value["sourceState"].get("recordHeads", []))
    selectors += list(value.get("sourceAuthoritySet", []))
    selectors += list(value.get("reviewerAuthoritySet", []))
    require(all(row.get("recordHash") != expected_hash for row in selectors),
            "archive record cannot commit to itself")
    pointer_code = fixture.rpc("eth_getCode", [pointer, "latest"])
    metadata_code = hex_bytes(fixture.rpc("eth_getCode", [host, "latest"]))
    require(pointer_code == "0x00" + manifest_bytes.hex() and metadata_code,
            "archive retained pointer or metadata runtime differs")
    return {
        "version": "1",
        "lane": "ARCHIVE_SEMANTIC_EXPORT",
        "host": host,
        "core": core,
        "collectionId": str(collection),
        "subjectId": subject_id,
        "recordType": RECORD_TYPE,
        "family": FAMILY,
        "authorizationMask": str(ARCHIVE_MASK),
        "authorizationClass": str(authorization_class),
        "authorizationClassName": AUTHORITY_NAMES[authorization_class],
        "grantRevision": str(grant_revision),
        "recorder": writer,
        "schemaName": schema_name,
        "schemaId": schema_id_,
        "schemaHash": schema_hash,
        "schemaBytesHex": "0x" + schema_bytes.hex(),
        "canonicalizationId": JCS,
        "payloadHash": keccak256(manifest_bytes),
        "payloadByteLength": str(len(manifest_bytes)),
        "payloadBytesHex": "0x" + manifest_bytes.hex(),
        "sourceBlockNumber": str(block_number),
        "sourceBlockHash": source_block_hash,
        "recordHash": expected_hash,
        "record": json_values(record),
        "recordReceipt": json_values(saved_receipt),
        "recordChainHash": saved_receipt[5],
        "previousRecordChainHash": previous_chain,
        "previousRecordCount": str(previous_count),
        "recordIndex": str(saved_receipt[4]),
        "recordChainCount": str(chain_count),
        "payloadPointer": pointer,
        "payloadPointerCode": pointer_code,
        "metadataRuntimeHash": keccak256(metadata_code),
        "registeredDocuments": {
            "schema": {"documentId": schema_id_, "view": json_values(schema_view),
                       "viewCalldata": schema_view_call, "viewResult": schema_view_raw,
                       "bytesHex": "0x" + actual_schema.hex()},
            "policy": {"documentId": policy_id, "view": json_values(policy_view),
                       "viewCalldata": policy_view_call, "viewResult": policy_view_raw,
                       "bytesHex": "0x" + actual_policy.hex()},
        },
        "publicationCalldata": data,
        "publicationTransactions": transactions,
        "publicationReceipt": receipt,
        "publicationEvent": event,
        "publicationBlock": publication_block,
        "publicationAncestry": ancestry,
        "claims": {
            "archiveAuthorityAuthenticated": True,
            "sourceClaimAuthorshipTransferred": False,
            "collectionSnapshotPublished": False,
            "independentAttestorLaneUsed": False,
        },
    }


def evidence_bytes(value):
    """Return a canonical retained evidence document."""
    require(isinstance(value, dict) and value.get("lane") == "ARCHIVE_SEMANTIC_EXPORT",
            "archive evidence")
    return dumps(value)
