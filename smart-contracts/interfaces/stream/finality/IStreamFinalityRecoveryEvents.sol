// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Executed recovery and bounded refresh events retained by ADR0020.
interface IStreamFinalityRecoveryEvents {
    event FinalityRecoveryExecuted(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed recoveryId,
        bytes32 recoveryManifestContentHash,
        bytes32 recoveryRouteHash,
        bool artworkBytesChanged,
        bytes32 reasonHash,
        string reasonURI
    );
    event ScopedFinalityRecoveryExecuted(
        uint16 schemaVersion,
        uint8 indexed scopeType,
        uint256 indexed collectionId,
        bytes32 indexed recoveryId,
        uint256 tokenId,
        bytes32 scopeId,
        bytes32 recoveryManifestContentHash,
        bytes32 recoveryRouteHash,
        bool artworkBytesChanged,
        bytes32 reasonHash,
        string reasonURI
    );
    event FinalityRecoveryRefreshPlanCreated(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed recoveryId,
        bytes32 indexed manifestContentHash,
        uint256 lastAllocatedTokenIdAtExecution,
        uint256 rangeStart,
        uint256 rangeEnd,
        bool complete
    );
    event FinalityRecoveryRefreshProgress(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed recoveryId,
        bytes32 indexed manifestContentHash,
        uint256 fromTokenId,
        uint256 toTokenId,
        uint256 processedThrough,
        uint256 chunksEmitted,
        bool complete
    );
    event FinalityRecoveryRefreshPlanSuperseded(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed recoveryId,
        bytes32 indexed supersededByRecoveryId,
        bytes32 manifestContentHash,
        uint256 processedThrough,
        uint256 rangeEnd
    );
    event ScopedFinalityRecoveryRefreshPlanCreated(
        uint16 schemaVersion,
        uint8 indexed scopeType,
        uint256 indexed collectionId,
        bytes32 indexed recoveryId,
        uint256 tokenId,
        bytes32 scopeId,
        bytes32 manifestContentHash,
        uint256 lastAllocatedTokenIdAtExecution,
        uint256 rangeStart,
        uint256 rangeEnd,
        bool complete
    );
    event ScopedFinalityRecoveryRefreshProgress(
        uint16 schemaVersion,
        uint8 indexed scopeType,
        uint256 indexed collectionId,
        bytes32 indexed recoveryId,
        uint256 tokenId,
        bytes32 scopeId,
        bytes32 manifestContentHash,
        uint256 fromTokenId,
        uint256 toTokenId,
        uint256 processedThrough,
        uint256 chunksEmitted,
        bool complete
    );
    event ScopedFinalityRecoveryRefreshPlanSuperseded(
        uint16 schemaVersion,
        uint8 indexed scopeType,
        uint256 indexed collectionId,
        bytes32 indexed recoveryId,
        uint256 tokenId,
        bytes32 scopeId,
        bytes32 supersededByRecoveryId,
        bytes32 manifestContentHash,
        uint256 processedThrough,
        uint256 rangeEnd
    );
    event FinalityRecoveryLineageRecorded(
        uint16 schemaVersion,
        bytes32 indexed recoveryId,
        bytes32 indexed predecessorRecoveryId,
        bytes32 indexed originalFinalityRecordHash,
        uint64 generation,
        bytes32 oldRouteHash,
        bytes32 recoveryRouteHash
    );
    event FinalityRecoveryEvidenceSnapshotted(
        uint16 schemaVersion,
        bytes32 indexed recoveryId,
        uint8 artistEvidenceKind,
        bytes32 artistEvidenceHash,
        address artistSigner,
        bytes32 artistId,
        uint8 artistAuthorityClass,
        uint64 artistNoticeEndsAt,
        bytes32 ownerEvidenceHash,
        uint64 ownerEvidenceRevision,
        uint64 ownerNoticeEndsAt,
        uint32 ownerAcknowledgementCount,
        uint32 ownerObjectionCount
    );
}
