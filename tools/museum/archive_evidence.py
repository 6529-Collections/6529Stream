"""Offline consistency checks for externally pinned local archive-publication evidence.

This is retained trusted-RPC evidence, not a receipt-trie, consensus or human
identity proof. Runtime admission and the external evidence hash remain inputs.
"""
from .account_profile import JCS_BYTES
from .archive_publication import (ARCHIVE_MASK, AUTHORITY_NAMES, FAMILY, JCS, RECORD_TYPE,
    _EVENT_DATA, _event, validate_manifest)
from .canonical import dumps, hex_bytes, keccak256, loads, record_chain, schema_id, uint
from .chain_abi import calldata, decode
from .chain_rpc import quantity
from .independent_wire import DOCUMENT, RECORD, ZERO, generic_hash, json_values, require, verify_document
from .semantic_export import NAME, POLICY_BYTES, POLICY_NAME, SCHEMA_BYTES, SCHEMA_HASH
from .typed_authority_profile import NAMES

WRITE = "recordCollectionRecordWithPayload(uint256,(bytes32,bytes32,(uint16,bytes,bytes32),string,bytes32,bytes32,(uint16,bytes,bytes32),uint64),bytes)"


def verify_evidence(raw, expected_hash, manifest_bytes, *, source_anchor_bytes):
    require(type(raw) is bytes and keccak256(raw) == expected_hash, "archive evidence external pin differs")
    value = loads(raw, maximum=8388608, canonical=True)
    manifest = loads(manifest_bytes, canonical=True)
    source = manifest["sourceState"]
    anchor = loads(source_anchor_bytes, maximum=524288, canonical=True)
    host = value["host"]; hex_bytes(host, 20)
    pins = {row["address"]: row["runtimeHash"] for row in anchor["codePins"]}
    require(host in pins and value["metadataRuntimeHash"] == pins[host], "archive host outside admitted source runtime pins")
    require(value["version"] == "1" and value["lane"] == "ARCHIVE_SEMANTIC_EXPORT"
        and value["recordType"] == RECORD_TYPE and value["family"] == FAMILY
        and value["authorizationMask"] == str(ARCHIVE_MASK), "archive evidence lane differs")
    require(value["core"] == source["core"] == anchor["core"] and source["chainId"] == anchor["chainId"]
        and source["blockHash"] == anchor["blockHash"] and source["blockNumber"] == anchor["blockNumber"], "archive source anchor differs")
    require(value["sourceBlockHash"] == source["blockHash"] and value["sourceBlockNumber"] == source["blockNumber"]
        and value["collectionId"] == source["collectionId"] and value["subjectId"] == source["anchorSubject"]["subjectId"], "archive source scope differs")
    cls = uint(value["authorizationClass"], 8)
    require(cls in AUTHORITY_NAMES and value["authorizationClassName"] == AUTHORITY_NAMES[cls]
        and uint(value["grantRevision"], 64) > 0, "archive authority class differs")
    require(value["schemaName"] == NAME and value["schemaId"] == schema_id(NAME)
        and value["schemaHash"] == SCHEMA_HASH and hex_bytes(value["schemaBytesHex"]) == SCHEMA_BYTES
        and value["canonicalizationId"] == JCS, "archive schema identity differs")
    validate_manifest(manifest_bytes, SCHEMA_BYTES, schema_name=NAME, schema_hash=SCHEMA_HASH,
        chain_id=source["chainId"], core=source["core"], collection_id=source["collectionId"],
        subject_id=value["subjectId"], source_block_number=source["blockNumber"], source_block_hash=source["blockHash"])
    require(hex_bytes(value["payloadBytesHex"]) == manifest_bytes and value["payloadHash"] == keccak256(manifest_bytes)
        and value["payloadByteLength"] == str(len(manifest_bytes))
        and value["payloadPointerCode"] == "0x00" + manifest_bytes.hex()
        and any(hex_bytes(value["payloadPointer"], 20)), "archive retained payload differs")
    for key, name, content, kind, predecessor in (("schema", NAME, SCHEMA_BYTES, 0, schema_id(NAMES[2])),
            ("policy", POLICY_NAME, POLICY_BYTES, 2, ZERO)):
        row = value["registeredDocuments"][key]
        require(row["documentId"] == schema_id(name) and hex_bytes(row["bytesHex"]) == content
            and row["viewCalldata"] == calldata("document(bytes32)", ("bytes32",), (schema_id(name),)), "archive registered input differs")
        view = verify_document(schema_id(name), hex_bytes(row["viewResult"]), content, kind, keccak256(content))
        require(json_values(view) == row["view"] and view[1] == 0
            and view[3][3:5] == (JCS, predecessor), "archive registry predecessor or status differs")
        require(view[4] == tuple(keccak256(content[i:i+8192]) for i in range(0, len(content), 8192)), "archive registry chunks differ")
    receipt = value["publicationReceipt"]; block = value["publicationBlock"]
    require(receipt["status"] == "0x1" and receipt["blockHash"] == block["hash"]
        and receipt["blockNumber"] == block["number"] and quantity(block["number"]) > uint(source["blockNumber"])
        and quantity(block["timestamp"]) > uint(anchor["timestamp"]), "archive publication block differs")
    transaction_index = quantity(receipt["transactionIndex"])
    require(isinstance(block["transactions"], list) and transaction_index < len(block["transactions"])
        and block["transactions"][transaction_index] == receipt["transactionHash"], "archive publication block transaction differs")
    ancestry = value["publicationAncestry"]
    require(isinstance(ancestry, list) and 2 <= len(ancestry) <= 65 and ancestry[0] == block,
        "archive publication ancestry bound")
    for child, parent in zip(ancestry, ancestry[1:]):
        require(child["parentHash"] == parent["hash"] and quantity(child["number"]) == quantity(parent["number"]) + 1
            and quantity(child["timestamp"]) > quantity(parent["timestamp"]), "archive publication ancestry differs")
    require(ancestry[-1]["hash"] == source["blockHash"] and quantity(ancestry[-1]["number"]) == uint(source["blockNumber"])
        and quantity(ancestry[-1]["timestamp"]) == uint(anchor["timestamp"])
        and ancestry[-1]["stateRoot"] == anchor["stateRoot"], "archive ancestry source block differs")
    record, event_hash, chain, recorder, _, _ = decode(_EVENT_DATA, hex_bytes(value["publicationEvent"]["data"]), maximum=1048576)
    require(record[0] == RECORD_TYPE and record[1] == value["subjectId"]
        and record[2] == (1, hex_bytes(keccak256(manifest_bytes)), JCS) and record[4] == schema_id(NAME)
        and record[5] == ZERO and record[6] == (0, b"", ZERO) and 0 < record[7] <= quantity(block["timestamp"]), "archive recorded fields differ")
    require(json_values(record) == value["record"] and recorder == value["recorder"]
        and event_hash == value["recordHash"] == generic_hash(uint(source["chainId"]), host, source["core"],
            uint(source["collectionId"]), recorder, record), "archive record preimage differs")
    previous_count = uint(value["previousRecordCount"], 64)
    require(value["recordIndex"] == str(previous_count) and uint(value["recordChainCount"], 64) == previous_count + 1
        and chain == value["recordChainHash"] == record_chain(source["chainId"], host, source["collectionId"], RECORD_TYPE,
            value["previousRecordChainHash"], value["recordHash"], str(previous_count)), "archive chain preimage differs")
    expected_receipt = [source["collectionId"], recorder, str(cls), str(quantity(block["timestamp"])), str(previous_count),
        chain, SCHEMA_HASH, keccak256(JCS_BYTES), ZERO]
    require(value["recordReceipt"] == expected_receipt, "archive historical receipt differs")
    event = _event(receipt, host, uint(source["collectionId"]), value["subjectId"], record, event_hash, chain, recorder, cls)
    require(event == value["publicationEvent"] and not event.get("removed", False)
        and event["blockHash"] == receipt["blockHash"] and event["transactionHash"] == receipt["transactionHash"]
        and event["blockNumber"] == receipt["blockNumber"] and event["transactionIndex"] == receipt["transactionIndex"], "archive publication event position differs")
    require(value["publicationCalldata"] == calldata(WRITE, ("uint256", RECORD, "bytes"),
        (uint(source["collectionId"]), record, manifest_bytes)), "archive publication calldata differs")
    require(any(row["transactionHash"] == receipt["transactionHash"] and row["receipt"] == receipt
        for row in value["publicationTransactions"]), "archive transaction receipt missing")
    require(value["claims"] == {"archiveAuthorityAuthenticated": True, "sourceClaimAuthorshipTransferred": False,
        "collectionSnapshotPublished": False, "independentAttestorLaneUsed": False}, "archive evidence claims differ")
    return {"mode": "externally_pinned_archive_evidence_consistency", "recordHash": value["recordHash"],
        "payloadHash": value["payloadHash"], "evidenceHash": expected_hash,
        "historicalAuthorizationClass": AUTHORITY_NAMES[cls], "consensusProof": False,
        "qualification": "Historical archive authority under the externally admitted runtime and original trusted-RPC evidence. This is not independent chain or human identity proof."}
