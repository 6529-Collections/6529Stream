// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFinalityPreparation.sol";

/// @notice Exact registry-owned record writes and normative events after completed admission.
/// @dev Compiler linkage preserves registry storage, emitter and Executor caller; direct CALL cannot write.
library StreamFinalityRecordState {
    uint16 private constant FINALITY_EVENT_SCHEMA_VERSION = 1;
    event CollectionArtworkFinalized(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed finalityRecordHash,
        address indexed actor,
        bytes32 componentsHash,
        bytes32 manifestContentHash,
        string finalityManifestURI
    );
    event ArtworkScopeFinalized(
        uint16 schemaVersion,
        uint8 indexed scopeType,
        uint256 indexed collectionId,
        bytes32 indexed finalityRecordHash,
        uint256 tokenId,
        bytes32 scopeId,
        bytes32 componentsHash,
        bytes32 manifestContentHash,
        string finalityManifestURI
    );
    event FinalityManifestPointerRecorded(
        uint16 schemaVersion,
        bytes32 indexed finalityRecordHash,
        address manifestPointer,
        bytes32 manifestContentHash
    );
    event ArtworkTerminalFreezeExecuted(
        uint16 schemaVersion,
        bytes32 indexed scopeKey,
        bytes32 indexed finalityRecordHash,
        address executor
    );

    function store(
        mapping(uint256 => StreamCollectionFinalityRecord) storage _collectionRecords,
        mapping(
            uint256 => StreamFinalityComponentExpectation[]
        ) storage _collectionComponents,
        mapping(bytes32 => StreamScopedFinalityRecord) storage _scopedRecords,
        mapping(bytes32 => StreamFinalityComponentExpectation[]) storage _scopedComponents,
        StreamFinalityScope memory scope,
        StreamFinalityPreparation.Prepared memory ctx,
        StreamFinalityComponentExpectation[] calldata components,
        StreamFinalityManifestRef calldata manifest
    ) public {
        uint256 count = components.length;
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            StreamCollectionFinalityRecord storage record = _collectionRecords[scope.collectionId];
            record.finalized = true;
            record.finalityRecordHash = ctx.finalityRecordHash;
            record.manifestContentHash = manifest.contentHash;
            record.manifestURIHash = manifest.uriHash;
            record.finalityManifestURI = manifest.uri;
            record.componentsHash = ctx.componentsHash;
            record.manifestPointer = address(this);
            record.finalizedAt = uint64(block.timestamp);
            StreamFinalityComponentExpectation[] storage stored =
                _collectionComponents[scope.collectionId];
            for (uint256 i = 0; i < count; i++) {
                stored.push(components[i]);
            }
            emit CollectionArtworkFinalized(
                FINALITY_EVENT_SCHEMA_VERSION,
                scope.collectionId,
                ctx.finalityRecordHash,
                msg.sender,
                ctx.componentsHash,
                manifest.contentHash,
                manifest.uri
            );
        } else {
            StreamScopedFinalityRecord storage record = _scopedRecords[ctx.scopeKey];
            record.finalized = true;
            record.scope = scope;
            record.finalityRecordHash = ctx.finalityRecordHash;
            record.manifestContentHash = manifest.contentHash;
            record.manifestURIHash = manifest.uriHash;
            record.componentsHash = ctx.componentsHash;
            record.finalityManifestURI = manifest.uri;
            record.manifestPointer = address(this);
            record.finalizedAt = uint64(block.timestamp);
            StreamFinalityComponentExpectation[] storage stored = _scopedComponents[ctx.scopeKey];
            for (uint256 i = 0; i < count; i++) {
                stored.push(components[i]);
            }
            emit ArtworkScopeFinalized(
                FINALITY_EVENT_SCHEMA_VERSION,
                uint8(scope.scopeType),
                scope.collectionId,
                ctx.finalityRecordHash,
                scope.tokenId,
                scope.scopeId,
                ctx.componentsHash,
                manifest.contentHash,
                manifest.uri
            );
        }
        emit FinalityManifestPointerRecorded(
            FINALITY_EVENT_SCHEMA_VERSION,
            ctx.finalityRecordHash,
            address(this),
            manifest.contentHash
        );
        emit ArtworkTerminalFreezeExecuted(
            FINALITY_EVENT_SCHEMA_VERSION, ctx.scopeKey, ctx.finalityRecordHash, msg.sender
        );
    }
}
