// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/metadata/IStreamOwnerRecords.sol";
import "../metadata/StreamOwnerRecordReads.sol";
import "../metadata/StreamSchemaDocumentStore.sol";
import "../metadata/StreamMetadataRenderer.sol";
import "./StreamCollectionRecordHashes.sol";

/// @notice Original OwnerRecords append and immutable reads, using explicit existing map roots.
/// @dev Caller retains signature verification, nonce writes and the shared reentrancy guard.
library StreamOwnerRecordBook {
    struct Stored {
        IStreamOwnerRecords.OwnerRecord record;
        IStreamOwnerRecords.Receipt receipt;
        address payloadPointer;
        address signaturePointer;
        bytes32 payloadHash;
    }

    struct Configuration {
        address core;
        bytes32 coreCodeHash;
        address schemas;
        bytes32 schemasCodeHash;
        address store;
        bytes32 storeCodeHash;
        uint256 readGas;
    }

    struct Input {
        uint256 tokenId;
        IStreamOwnerRecords.OwnerRecord record;
        IStreamOwnerRecords.Receipt receipt;
        bytes bundle;
        bool knownType;
    }
    event OwnerRecordRecorded(
        uint256 indexed tokenId,
        bytes32 indexed recordType,
        address indexed owner,
        IStreamOwnerRecords.OwnerRecord record,
        bytes32 recordHash,
        bytes32 recordChainHash,
        bool relayed,
        uint16 schemaVersion
    );
    bytes32 private constant TOKEN =
        0x1e576f27850d12bc1ec9255ca277dbecfbc84fb3a9a34c474640dfca89811d7e;

    function append(
        mapping(bytes32 => Stored) storage records,
        mapping(uint256 => mapping(bytes32 => bytes32[])) storage history,
        mapping(uint256 => mapping(bytes32 => bytes32)) storage chains,
        mapping(bytes32 => bytes32) storage latest,
        Configuration memory c,
        Input memory i
    ) public returns (bytes32 hash) {
        uint256 cap = c.readGas;
        if (i.receipt.owner != StreamOwnerRecordReads.owner(c.core, c.coreCodeHash, i.tokenId, cap))
        {
            revert IStreamOwnerRecords.OwnerRecordAuthorityRequired(i.receipt.owner);
        }
        _validate(c, i);
        StreamOwnerRecordReads.requireCode(c.schemas, c.schemasCodeHash);
        i.receipt.schemaDefinitionHash = StreamOwnerRecordReads.definition(
            c.schemas, i.record.schemaId, IStreamSchemaRegistry.DocumentKind.SCHEMA, cap
        );
        i.receipt.canonicalizationDefinitionHash = StreamOwnerRecordReads.definition(
            c.schemas,
            i.record.contentHash.canonicalizationId,
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            cap
        );
        i.receipt.tokenId = i.tokenId;
        i.receipt.recordedAt = uint64(block.timestamp);
        i.receipt.signatureBundleHash = keccak256(i.bundle);
        IStreamPreservationRecords.CollectionRecord memory genericRecord =
            IStreamPreservationRecords.CollectionRecord(
                i.record.recordType,
                i.record.subjectId,
                i.record.contentHash,
                i.record.uri,
                i.record.schemaId,
                i.receipt.signatureScheme,
                IStreamPreservationRecords.HashRef(
                    1, abi.encode(i.receipt.signatureBundleHash), keccak256("RAW_BYTES")
                ),
                i.record.effectiveAt
            );
        hash = StreamCollectionRecordHashes.recordHash(
            c.core, i.receipt.owner, i.tokenId, genericRecord
        );
        if (records[hash].receipt.owner != address(0)) {
            revert IStreamOwnerRecords.OwnerRecordExists(hash);
        }
        uint256 count = history[i.tokenId][i.record.recordType].length;
        if (count == type(uint64).max) revert IStreamOwnerRecords.InvalidOwnerRecord();
        i.receipt.recordIndex = uint64(count);
        i.receipt.recordChainHash = StreamCollectionRecordHashes.nextChain(
            i.tokenId,
            i.record.recordType,
            chains[i.tokenId][i.record.recordType],
            hash,
            uint64(count)
        );
        Stored storage stored = records[hash];
        stored.signaturePointer = _publish(c, i.bundle);
        if (i.record.payload.length != 0) stored.payloadPointer = _publish(c, i.record.payload);
        stored.payloadHash = keccak256(i.record.payload);
        stored.record.recordType = i.record.recordType;
        stored.record.subjectId = i.record.subjectId;
        stored.record.schemaId = i.record.schemaId;
        stored.record.contentHash = i.record.contentHash;
        stored.record.uri = i.record.uri;
        stored.record.effectiveAt = i.record.effectiveAt;
        stored.receipt = i.receipt;
        history[i.tokenId][i.record.recordType].push(hash);
        chains[i.tokenId][i.record.recordType] = i.receipt.recordChainHash;
        latest[keccak256(abi.encode(i.tokenId, i.record.recordType, i.receipt.owner))] = hash;
        emit OwnerRecordRecorded(
            i.tokenId,
            i.record.recordType,
            i.receipt.owner,
            i.record,
            hash,
            i.receipt.recordChainHash,
            i.receipt.relayed,
            1
        );
    }

    function _validate(Configuration memory c, Input memory i) private view {
        if (
            i.tokenId == 0 || !i.knownType
                || i.record.subjectId
                    != keccak256(abi.encode(TOKEN, block.chainid, c.core, i.tokenId))
                || i.record.schemaId == 0 || i.record.contentHash.canonicalizationId == 0
                || i.record.payload.length > 8192 || i.record.effectiveAt == 0
                || block.timestamp > type(uint64).max
        ) revert IStreamOwnerRecords.InvalidOwnerRecord();
        uint16 algorithm = i.record.contentHash.algorithm;
        uint256 size = i.record.contentHash.digest.length;
        if (algorithm == 1 || algorithm == 2 || algorithm == 3 || algorithm == 6) {
            if (size != 32) revert IStreamOwnerRecords.InvalidOwnerRecord();
        } else if (algorithm == 4 || algorithm == 5) {
            if (size == 0 || size > 128) revert IStreamOwnerRecords.InvalidOwnerRecord();
        } else {
            revert IStreamOwnerRecords.InvalidOwnerRecord();
        }
        // Algorithms without an onchain implementation remain explicit opaque commitments.
        if (i.record.payload.length != 0) {
            if (
                algorithm == 1
                    && bytes32(i.record.contentHash.digest) != keccak256(i.record.payload)
            ) {
                revert IStreamOwnerRecords.InvalidOwnerRecord();
            }
            if (algorithm == 2 && bytes32(i.record.contentHash.digest) != sha256(i.record.payload))
            {
                revert IStreamOwnerRecords.InvalidOwnerRecord();
            }
        }
        StreamMetadataRenderer.requireValidUtf8ContentUri("recordURI", i.record.uri, 2048, true);
    }

    function _publish(Configuration memory c, bytes memory payload)
        private
        returns (address pointer)
    {
        StreamOwnerRecordReads.requireCode(c.store, c.storeCodeHash);
        bytes32 hash;
        (hash, pointer) = StreamSchemaDocumentStore(c.store).publishChunk(payload);
        if (hash != keccak256(payload) || pointer.code.length != payload.length + 1) {
            revert IStreamOwnerRecords.InvalidOwnerRecord();
        }
    }

    function _payload(address pointer, bytes32 hash) private view returns (bytes memory payload) {
        if (pointer == address(0)) {
            if (hash != keccak256(bytes(""))) revert IStreamOwnerRecords.InvalidOwnerRecord();
            return bytes("");
        }
        if (pointer.code.length == 0 || pointer.code.length > 8193) {
            revert IStreamOwnerRecords.OwnerRecordDependencyChanged(pointer);
        }
        payload = SSTORE2.read(pointer);
        if (keccak256(payload) != hash) {
            revert IStreamOwnerRecords.OwnerRecordDependencyChanged(pointer);
        }
    }

    function record(mapping(bytes32 => Stored) storage records, bytes32 hash)
        public
        view
        returns (
            IStreamOwnerRecords.OwnerRecord memory r,
            IStreamOwnerRecords.Receipt memory receipt
        )
    {
        Stored storage s = records[hash];
        if (s.receipt.owner == address(0)) revert IStreamOwnerRecords.OwnerRecordUnknown(hash);
        r = s.record;
        r.payload = _payload(s.payloadPointer, s.payloadHash);
        return (r, s.receipt);
    }

    function signature(mapping(bytes32 => Stored) storage records, bytes32 hash)
        public
        view
        returns (address, bytes memory)
    {
        Stored storage s = records[hash];
        if (s.receipt.owner == address(0)) revert IStreamOwnerRecords.OwnerRecordUnknown(hash);
        return (s.signaturePointer, _payload(s.signaturePointer, s.receipt.signatureBundleHash));
    }
}
