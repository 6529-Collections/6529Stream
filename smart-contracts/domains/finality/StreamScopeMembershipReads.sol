// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamScopeMembershipEncoding.sol";
import "../../interfaces/stream/finality/IStreamFinalityScopeMembership.sol";
import "../../interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol";
import "../metadata/StreamMetadataSubjects.sol";
import "../metadata/StreamSchemaDocumentStore.sol";
import "../records/StreamCollectionRecordHashes.sol";
import "../records/StreamRecordFamilies.sol";

/// @notice Bounded original publication and native-byte reads for the fixed membership host.
/// @dev The host supplies only constructor-derived targets. This library is not an authority route.
library StreamScopeMembershipReads {
    bytes32 internal constant RECORD_TYPE = keccak256("SCOPE_MEMBERSHIP");
    bytes32 internal constant SCHEMA_HASH =
        0x70c79fbabc4dc32259b4f3958da52f8c9d27814e9202e1ab2b1c0b75acd3d2cb;
    bytes32 internal constant CANON_HASH =
        0x3a8f6aa2c183ea43dff145064f8175f2a7c4bc7c2b65633d0fdfdc36fdeaab5e;

    struct Inputs {
        uint256 chainId;
        address core;
        address metadataHost;
        address schemaRegistry;
        address chunkStore;
        uint256 readGas;
    }

    function publication(Inputs memory b, bytes32 recordHash)
        public
        view
        returns (
            StreamScopeMembershipManifest memory m,
            IStreamFinalityScopeMembership.Publication memory p
        )
    {
        bytes memory raw = read(
            b.metadataHost,
            abi.encodeCall(IStreamCollectionMetadataV1.collectionRecord, (recordHash)),
            4096,
            b.readGas,
            false
        );
        (
            IStreamPreservationRecords.CollectionRecord memory record,
            IStreamCollectionMetadataV1.RecordReceipt memory receipt
        ) = abi.decode(
            raw,
            (IStreamPreservationRecords.CollectionRecord, IStreamCollectionMetadataV1.RecordReceipt)
        );
        if (
            keccak256(raw) != keccak256(abi.encode(record, receipt))
                || receipt.recorder == address(0)
                || (receipt.authorizationClass != 7 && receipt.authorizationClass != 8)
                || receipt.recordedAt == 0 || receipt.recordChainHash == 0
                || receipt.artistAuthorization != 0 || record.recordType != RECORD_TYPE
                || record.schemaId != StreamScopeMembershipEncoding.SCHEMA_ID
                || record.contentHash.algorithm != 1 || record.contentHash.digest.length != 32
                || record.contentHash.canonicalizationId
                    != StreamScopeMembershipEncoding.CANONICALIZATION_ID
                || record.signatureScheme != 0 || record.signatureHash.algorithm != 0
                || record.signatureHash.digest.length != 0
                || record.signatureHash.canonicalizationId != 0 || record.effectiveAt == 0
                || receipt.schemaDefinitionHash != SCHEMA_HASH
                || receipt.canonicalizationDefinitionHash != CANON_HASH
                || _recordHash(b, record, receipt) != recordHash
        ) revert IStreamFinalityScopeMembership.InvalidScopeMembershipRecord(recordHash);
        _policyAndIndex(b, receipt, recordHash);
        _definitions(b);
        raw = read(
            b.metadataHost,
            abi.encodeCall(IStreamCollectionMetadataV1.recordPayload, (recordHash)),
            8352,
            b.readGas,
            false
        );
        (address pointer, bytes memory payload) = abi.decode(raw, (address, bytes));
        bytes32 manifestHash = bytes32(record.contentHash.digest);
        if (
            keccak256(raw) != keccak256(abi.encode(pointer, payload))
                || keccak256(payload) != manifestHash
        ) {
            revert IStreamFinalityScopeMembership.InvalidScopeMembershipRecord(recordHash);
        }
        (address nativePointer, uint256 nativeLength) =
            chunkPointer(b.chunkStore, manifestHash, b.readGas);
        if (pointer != nativePointer || payload.length != nativeLength) {
            revert IStreamFinalityScopeMembership.InvalidScopeMembershipRecord(recordHash);
        }
        m = StreamScopeMembershipEncoding.decode(payload);
        if (
            m.chainId != b.chainId || m.core != b.core || m.collectionId != receipt.collectionId
                || record.subjectId
                    != StreamMetadataSubjects.scopeSubject(
                        b.chainId,
                        b.core,
                        StreamFinalityScope(
                            StreamFinalityScopeType.COLLECTION, m.collectionId, 0, 0
                        )
                    )
        ) revert IStreamFinalityScopeMembership.InvalidScopeMembershipRecord(recordHash);
        p = IStreamFinalityScopeMembership.Publication(
            recordHash,
            manifestHash,
            record.schemaId,
            record.contentHash.canonicalizationId,
            pointer,
            pointer.codehash,
            record.effectiveAt,
            receipt
        );
    }

    function _recordHash(
        Inputs memory b,
        IStreamPreservationRecords.CollectionRecord memory r,
        IStreamCollectionMetadataV1.RecordReceipt memory receipt
    ) private pure returns (bytes32) {
        StreamCollectionRecordHashes.Preimage memory p;
        p.domain = keccak256("6529stream.preservation-record.v2");
        p.chainId = b.chainId;
        p.host = b.metadataHost;
        p.core = b.core;
        p.recorder = receipt.recorder;
        p.collectionId = receipt.collectionId;
        p.recordType = r.recordType;
        p.subjectId = r.subjectId;
        p.contentHash = StreamCollectionRecordHashes.hashRef(
            r.contentHash.algorithm, r.contentHash.digest, r.contentHash.canonicalizationId
        );
        p.uriHash = keccak256(bytes(r.uri));
        p.schemaId = r.schemaId;
        p.signatureScheme = r.signatureScheme;
        p.signatureHash = StreamCollectionRecordHashes.hashRef(
            r.signatureHash.algorithm, r.signatureHash.digest, r.signatureHash.canonicalizationId
        );
        p.effectiveAt = r.effectiveAt;
        return keccak256(abi.encode(p));
    }

    function _policyAndIndex(
        Inputs memory b,
        IStreamCollectionMetadataV1.RecordReceipt memory receipt,
        bytes32 recordHash
    ) private view {
        IStreamCollectionMetadataV1.RecordPolicy memory
            policy =
            abi.decode(
                read(
                    b.metadataHost,
                    abi.encodeCall(IStreamCollectionMetadataV1.recordPolicy, (RECORD_TYPE)),
                    96,
                    b.readGas,
                    true
                ),
                (IStreamCollectionMetadataV1.RecordPolicy)
            );
        if (
            !policy.admitted || policy.family != StreamRecordFamilies.IDENTITY
                || (policy.authorizationMask & StreamRecordFamilies.bit(receipt.authorizationClass))
                    == 0
                || (policy.authorizationMask
                            & ~(StreamRecordFamilies.bit(7) | StreamRecordFamilies.bit(8))) != 0
                || abi.decode(
                        read(
                            b.metadataHost,
                            abi.encodeCall(
                                IStreamCollectionMetadataV1.recordHashAt,
                                (receipt.collectionId, RECORD_TYPE, uint256(receipt.recordIndex))
                            ),
                            32,
                            b.readGas,
                            true
                        ),
                        (bytes32)
                    ) != recordHash
        ) revert IStreamFinalityScopeMembership.InvalidScopeMembershipRecord(recordHash);
    }

    function _definitions(Inputs memory b) private view {
        _definition(
            b,
            StreamScopeMembershipEncoding.SCHEMA_ID,
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            SCHEMA_HASH,
            2047
        );
        _definition(
            b,
            StreamScopeMembershipEncoding.CANONICALIZATION_ID,
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            CANON_HASH,
            1309
        );
    }

    function _definition(
        Inputs memory b,
        bytes32 id,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes32 hash,
        uint32 size
    ) private view {
        IStreamSchemaDocumentFacts.DocumentFacts memory f =
            abi.decode(
                read(
                    b.schemaRegistry,
                    abi.encodeCall(IStreamSchemaDocumentFacts.documentFacts, (id)),
                    288,
                    b.readGas,
                    true
                ),
                (IStreamSchemaDocumentFacts.DocumentFacts)
            );
        if (
            !f.exists || f.kind != kind || f.contentHash != hash || f.totalBytes != size
                || f.canonicalizationId != keccak256("RAW_BYTES") || f.chunkCount != 1
                || f.declarationHash == 0
        ) revert IStreamFinalityScopeMembership.InvalidScopeMembershipRecord(id);
        bytes memory raw = read(
            b.schemaRegistry,
            abi.encodeCall(IStreamSchemaRegistry.documentBytes, (id)),
            64 + ((uint256(size) + 31) / 32) * 32,
            b.readGas,
            true
        );
        bytes memory payload = abi.decode(raw, (bytes));
        if (
            payload.length != size || keccak256(payload) != hash
                || keccak256(raw) != keccak256(abi.encode(payload))
        ) {
            revert IStreamFinalityScopeMembership.InvalidScopeMembershipRecord(id);
        }
        // Retirement changes new-writing policy, never the interpretation of an original record.
    }

    function chunkPointer(address store, bytes32 hash, uint256 cap)
        public
        view
        returns (address pointer, uint256 length)
    {
        (pointer, length) = abi.decode(
            read(store, abi.encodeWithSignature("chunk(bytes32)", hash), 64, cap, true),
            (address, uint256)
        );
        if (
            pointer == address(0) || length == 0 || length > 8192
                || pointer.code.length != length + 1
        ) {
            revert IStreamFinalityScopeMembership.ScopeMembershipDependencyChanged(pointer);
        }
    }

    function part(
        address store,
        bytes32 hash,
        address expectedPointer,
        bytes32 codeHash,
        uint256 length,
        uint256 cap
    ) public view returns (bytes memory payload) {
        (address pointer, uint256 actualLength) = chunkPointer(store, hash, cap);
        if (pointer != expectedPointer || pointer.codehash != codeHash || actualLength != length) {
            revert IStreamFinalityScopeMembership.ScopeMembershipDependencyChanged(pointer);
        }
        bytes memory raw = read(
            store,
            abi.encodeCall(StreamSchemaDocumentStore.readChunk, (hash)),
            64 + length,
            cap,
            true
        );
        payload = abi.decode(raw, (bytes));
        if (
            payload.length != length || keccak256(payload) != hash
                || keccak256(raw) != keccak256(abi.encode(payload))
        ) {
            revert IStreamFinalityScopeMembership.ScopeMembershipDependencyChanged(pointer);
        }
    }

    function read(address target, bytes memory input, uint256 maximum, uint256 cap, bool exact)
        public
        view
        returns (bytes memory output)
    {
        output = new bytes(maximum);
        if (cap == 0 || cap > type(uint256).max / 64) {
            revert IStreamFinalityScopeMembership.InvalidScopeMembershipConfiguration();
        }
        uint256 required = cap + cap / 63 + 100000;
        if (gasleft() <= required) {
            revert IStreamFinalityScopeMembership.ScopeMembershipParentGas(gasleft(), required);
        }
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(output, 32), maximum)
            size := returndatasize()
        }
        if (!ok || size > maximum || (exact && size != maximum)) {
            revert IStreamFinalityScopeMembership.ScopeMembershipReadFailed(target, bytes4(input));
        }
        assembly ("memory-safe") { mstore(output, size) }
    }
}
