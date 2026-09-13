// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamRightsRecordDefinitions.sol";
import "./StreamRightsRecordJson.sol";
import "./StreamCollectionRecordHashes.sol";
import "./StreamRecordFamilies.sol";
import "../../interfaces/stream/metadata/IStreamRightsRecordSelection.sol";
import "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import "../metadata/StreamSchemaDocumentStore.sol";

/// @notice Exact rights interpretation, original receipt and current deployment checks.
/// @dev The immutable consuming auxiliary supplies dependencies, never the field witness.
library StreamRightsRecordReads {
    bytes32 internal constant RECORD_TYPE = keccak256("RIGHTS_STATEMENT");
    bytes32 private constant RAW_BYTES = keccak256("RAW_BYTES");
    bytes32 private constant METADATA_TYPE = keccak256("COLLECTION_METADATA");
    bytes32 private constant READ_GAS = keccak256("6529STREAM_GGP_METADATA_DEPENDENCY_READ_GAS");

    struct Dependencies {
        // Core, generic metadata, definition registry, immutable byte store.
        address[4] targets;
        bytes32[4] codeHashes;
        uint256 chainId;
        uint256 readGas;
    }

    function currentContext(Dependencies memory d) public view returns (Dependencies memory) {
        if (block.chainid != d.chainId) {
            revert IStreamRightsRecordSelection.RightsDependencyChanged(d.targets[0]);
        }
        for (uint256 i; i < 4; ++i) {
            if (d.targets[i].code.length == 0 || d.targets[i].codehash != d.codeHashes[i]) {
                revert IStreamRightsRecordSelection.RightsDependencyChanged(d.targets[i]);
            }
        }
        // This getter belongs to the already pinned metadata runtime and has no external calls.
        d.readGas = IStreamGasParameterHost(d.targets[1]).gasParameter(READ_GAS);
        if (d.readGas == 0 || d.readGas > type(uint64).max) {
            revert IStreamRightsRecordSelection.InvalidRightsConfiguration();
        }
        if (
            _hashRead(d, d.targets[1], "coreCodeHash()") != d.codeHashes[0]
                || _hashRead(d, d.targets[1], "schemaRegistryCodeHash()") != d.codeHashes[2]
                || _hashRead(d, d.targets[1], "chunkStoreCodeHash()") != d.codeHashes[3]
        ) {
            revert IStreamRightsRecordSelection.InvalidRightsConfiguration();
        }
        if (
            _addressRead(d, d.targets[1], IStreamCollectionMetadataV1.core.selector) != d.targets[0]
                || _addressRead(
                        d, d.targets[1], IStreamCollectionMetadataV1.schemaRegistry.selector
                    ) != d.targets[2]
                || _addressRead(d, d.targets[1], IStreamCollectionMetadataV1.chunkStore.selector)
                    != d.targets[3]
                || _addressRead(d, d.targets[2], IStreamSchemaRegistry.chunkStore.selector)
                    != d.targets[3]
        ) revert IStreamRightsRecordSelection.InvalidRightsConfiguration();
        bytes memory pointer = _read(
            d,
            d.targets[0],
            abi.encodeWithSignature("getSatellitePointer(bytes32)", METADATA_TYPE),
            320
        );
        if (
            pointer.length != 320 || _word(pointer, 0) != bytes32(uint256(uint160(d.targets[1])))
                || _word(pointer, 1) != d.codeHashes[1] || _word(pointer, 3) != METADATA_TYPE
                || _word(pointer, 6) != bytes32(uint256(1))
        ) revert IStreamRightsRecordSelection.RightsHostNotSelected();
        return d;
    }

    function definitions(Dependencies memory d) public view {
        _definition(
            d,
            StreamRightsRecordDefinitions.SCHEMA_ID,
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            StreamRightsRecordDefinitions.SCHEMA_HASH,
            StreamRightsRecordDefinitions.SCHEMA_BYTES
        );
        _definition(
            d,
            StreamRightsRecordDefinitions.PROFILE_ID,
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            StreamRightsRecordDefinitions.PROFILE_HASH,
            StreamRightsRecordDefinitions.PROFILE_BYTES
        );
        _definition(
            d,
            StreamRightsRecordDefinitions.CANON_ID,
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            StreamRightsRecordDefinitions.CANON_HASH,
            StreamRightsRecordDefinitions.CANON_BYTES
        );
    }

    function authority(Dependencies memory d, uint256 collectionId, address caller)
        public
        view
        returns (uint8 authClass, uint256 grantScope, uint64 revision)
    {
        IStreamCollectionMetadataV1.RecordPolicy memory policy = abi.decode(
            _read(
                d,
                d.targets[1],
                abi.encodeCall(IStreamCollectionMetadataV1.recordPolicy, (RECORD_TYPE)),
                96
            ),
            (IStreamCollectionMetadataV1.RecordPolicy)
        );
        if (!policy.admitted || policy.family != StreamRecordFamilies.RIGHTS) {
            revert IStreamRightsRecordSelection.RightsSelectionAuthorityRequired();
        }
        for (uint8 c = 7; c <= 8; ++c) {
            if ((policy.authorizationMask & StreamRecordFamilies.bit(c)) == 0) continue;
            for (uint256 i; i < 2; ++i) {
                uint256 scope = i == 0 ? collectionId : 0;
                (bool enabled, uint64 rev) = abi.decode(
                    _read(
                        d,
                        d.targets[1],
                        abi.encodeCall(
                            IStreamCollectionMetadataV1.familyWriter,
                            (scope, StreamRecordFamilies.RIGHTS, c, caller)
                        ),
                        64
                    ),
                    (bool, uint64)
                );
                if (enabled && rev != 0) return (c, scope, rev);
            }
        }
        revert IStreamRightsRecordSelection.RightsSelectionAuthorityRequired();
    }

    function recorded(
        Dependencies memory d,
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 recordHash,
        StreamRightsRecordTypes.Statement memory witness
    )
        public
        view
        returns (bytes32 payloadHash, IStreamCollectionMetadataV1.RecordReceipt memory receipt)
    {
        IStreamPreservationRecords.CollectionRecord memory record;
        (record, receipt) = abi.decode(
            _read(
                d,
                d.targets[1],
                abi.encodeCall(IStreamCollectionMetadataV1.collectionRecord, (recordHash)),
                8192
            ),
            (IStreamPreservationRecords.CollectionRecord, IStreamCollectionMetadataV1.RecordReceipt)
        );
        if (
            collectionId == 0 || subjectId == 0 || recordHash == 0
                || receipt.collectionId != collectionId || receipt.recorder == address(0)
                || (receipt.authorizationClass != 7 && receipt.authorizationClass != 8)
                || receipt.recordedAt == 0 || receipt.artistAuthorization != 0
                || receipt.schemaDefinitionHash != StreamRightsRecordDefinitions.SCHEMA_HASH
                || receipt.canonicalizationDefinitionHash
                    != StreamRightsRecordDefinitions.CANON_HASH || record.recordType != RECORD_TYPE
                || record.subjectId != subjectId
                || record.schemaId != StreamRightsRecordDefinitions.SCHEMA_ID
                || record.contentHash.algorithm != 1 || record.contentHash.digest.length != 32
                || record.contentHash.canonicalizationId != StreamRightsRecordDefinitions.CANON_ID
                || record.signatureScheme != 0 || record.signatureHash.algorithm != 0
                || record.signatureHash.digest.length != 0
                || record.signatureHash.canonicalizationId != 0 || record.effectiveAt == 0
                || witness.subjectId != subjectId
                || witness.profileHash != StreamRightsRecordDefinitions.PROFILE_HASH
                || _recordHash(d, collectionId, receipt.recorder, record) != recordHash
        ) revert IStreamRightsRecordSelection.InvalidRightsRecord(recordHash);
        bytes32 indexedHash = abi.decode(
            _read(
                d,
                d.targets[1],
                abi.encodeCall(
                    IStreamCollectionMetadataV1.recordHashAt,
                    (collectionId, RECORD_TYPE, receipt.recordIndex)
                ),
                32
            ),
            (bytes32)
        );
        if (indexedHash != recordHash) {
            revert IStreamRightsRecordSelection.InvalidRightsRecord(recordHash);
        }
        payloadHash = bytes32(record.contentHash.digest);
        _payload(d, recordHash, payloadHash, witness);
    }

    function _payload(
        Dependencies memory d,
        bytes32 recordHash,
        bytes32 payloadHash,
        StreamRightsRecordTypes.Statement memory witness
    ) private view {
        // The authenticated metadata record commits the digest, and its fixed Store owns bytes.
        // Avoid wrapping Store reads inside another host with the same governed child budget.
        (address storedPointer, uint32 storedBytes) = abi.decode(
            _read(d, d.targets[3], abi.encodeWithSignature("chunk(bytes32)", payloadHash), 64),
            (address, uint32)
        );
        bytes memory original = abi.decode(
            _read(
                d,
                d.targets[3],
                abi.encodeCall(StreamSchemaDocumentStore.readChunk, (payloadHash)),
                8256
            ),
            (bytes)
        );
        if (
            storedPointer == address(0) || original.length != storedBytes
                || keccak256(original) != payloadHash
        ) {
            revert IStreamRightsRecordSelection.InvalidRightsRecord(recordHash);
        }
        StreamRecordJson.requirePayload(StreamRightsRecordJson.serialize(witness), original);
    }

    function _recordHash(
        Dependencies memory d,
        uint256 collectionId,
        address recorder,
        IStreamPreservationRecords.CollectionRecord memory record
    ) private pure returns (bytes32) {
        StreamCollectionRecordHashes.Preimage memory p;
        p.domain = keccak256("6529stream.preservation-record.v2");
        p.chainId = d.chainId;
        p.host = d.targets[1];
        p.core = d.targets[0];
        p.recorder = recorder;
        p.collectionId = collectionId;
        p.recordType = record.recordType;
        p.subjectId = record.subjectId;
        p.contentHash = StreamCollectionRecordHashes.hashRef(
            record.contentHash.algorithm,
            record.contentHash.digest,
            record.contentHash.canonicalizationId
        );
        p.uriHash = keccak256(bytes(record.uri));
        p.schemaId = record.schemaId;
        p.signatureScheme = record.signatureScheme;
        p.signatureHash = StreamCollectionRecordHashes.hashRef(
            record.signatureHash.algorithm,
            record.signatureHash.digest,
            record.signatureHash.canonicalizationId
        );
        p.effectiveAt = record.effectiveAt;
        return keccak256(abi.encode(p));
    }

    function _definition(
        Dependencies memory d,
        bytes32 id,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes32 hash,
        uint256 byteLength
    ) private view {
        IStreamSchemaRegistry.DocumentView memory row =
            abi.decode(
                _read(d, d.targets[2], abi.encodeCall(IStreamSchemaRegistry.document, (id)), 8192),
                (IStreamSchemaRegistry.DocumentView)
            );
        if (
            !row.exists || row.status != IStreamSchemaRegistry.DocumentStatus.ACTIVE
                || keccak256(bytes(row.specification.name)) != id || row.specification.kind != kind
                || row.specification.canonicalizationId != RAW_BYTES
                || row.specification.supersedesId != 0 || row.specification.totalBytes != byteLength
                || row.specification.contentHash != hash
                || row.declarationHash != keccak256(abi.encode(row.specification, row.chunkHashes))
        ) {
            revert IStreamRightsRecordSelection.RightsDefinitionUnavailable(id);
        }
        // Reconstruct the complete registered document through individually bounded reads.
        // The semantic schema exceeds one chunk; do not silently truncate it or raise a cap.
        bytes memory payload;
        if (row.chunkHashes.length == 0 || row.chunkHashes.length > 64) {
            revert IStreamRightsRecordSelection.RightsDefinitionUnavailable(id);
        }
        for (uint256 i; i < row.chunkHashes.length; ++i) {
            bytes memory chunk = abi.decode(
                _read(
                    d,
                    d.targets[3],
                    abi.encodeCall(StreamSchemaDocumentStore.readChunk, (row.chunkHashes[i])),
                    8256
                ),
                (bytes)
            );
            if (
                chunk.length == 0 || chunk.length > 8192 || keccak256(chunk) != row.chunkHashes[i]
                    || (i + 1 < row.chunkHashes.length && chunk.length != 8192)
                    || payload.length + chunk.length > byteLength
            ) {
                revert IStreamRightsRecordSelection.RightsDefinitionUnavailable(id);
            }
            payload = bytes.concat(payload, chunk);
        }
        if (payload.length != byteLength || keccak256(payload) != hash) {
            revert IStreamRightsRecordSelection.RightsDefinitionUnavailable(id);
        }
    }

    function _addressRead(Dependencies memory d, address target, bytes4 selector)
        private
        view
        returns (address)
    {
        bytes memory data = _read(d, target, abi.encodeWithSelector(selector), 32);
        if (data.length != 32) {
            revert IStreamRightsRecordSelection.RightsDependencyReadFailed(target);
        }
        return abi.decode(data, (address));
    }

    function _hashRead(Dependencies memory d, address target, string memory signature)
        private
        view
        returns (bytes32)
    {
        bytes memory data = _read(d, target, abi.encodeWithSignature(signature), 32);
        if (data.length != 32) {
            revert IStreamRightsRecordSelection.RightsDependencyReadFailed(target);
        }
        return abi.decode(data, (bytes32));
    }

    function _word(bytes memory data, uint256 index) private pure returns (bytes32 result) {
        assembly ("memory-safe") { result := mload(add(add(data, 32), mul(index, 32))) }
    }

    function _read(Dependencies memory d, address target, bytes memory input, uint256 maximum)
        private
        view
        returns (bytes memory data)
    {
        uint256 cap = d.readGas;
        data = new bytes(maximum);
        if (gasleft() <= cap + cap / 63 + 10000) {
            revert IStreamRightsRecordSelection.RightsDependencyReadFailed(target);
        }
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(data, 32), maximum)
            size := returndatasize()
        }
        if (!ok || size > maximum) {
            revert IStreamRightsRecordSelection.RightsDependencyReadFailed(target);
        }
        assembly ("memory-safe") { mstore(data, size) }
    }
}
