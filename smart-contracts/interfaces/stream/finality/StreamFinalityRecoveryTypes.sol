// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamFinalityScope,
    StreamFinalityComponentExpectation,
    StreamFinalityManifestRef
} from "./StreamArtworkFinalityTypes.sol";

/// @notice Exact auxiliary recovery tuples defined by ADR0020.
/// @dev These types describe successful append history, not a second local scheduling lifecycle.
struct StreamFinalityRecoveryRequest {
    StreamFinalityScope scope;
    bytes32 expectedOriginalFinalityRecordHash;
    bytes32 expectedPredecessorRecoveryId;
    bytes32 expectedOldRouteHash;
    StreamFinalityComponentExpectation replacementRoute;
    StreamFinalityManifestRef recoveryManifest;
    bytes32 reasonHash;
    string reasonURI;
}

/// @notice Permanent numeric evidence kinds: NONE=0, APPROVAL=1, UNAVAILABILITY=2.
enum StreamFinalityRecoveryArtistEvidenceKind {
    NONE,
    APPROVAL,
    UNAVAILABILITY
}

struct StreamFinalityRecoveryEvidenceSnapshot {
    StreamFinalityRecoveryArtistEvidenceKind artistEvidenceKind;
    bytes32 artistEvidenceHash;
    address artistSigner;
    bytes32 artistId;
    uint8 artistAuthorityClass;
    uint64 artistNoticeEndsAt;
    bytes32 ownerEvidenceHash;
    uint64 ownerEvidenceRevision;
    uint64 ownerNoticeEndsAt;
    uint32 ownerAcknowledgementCount;
    uint32 ownerObjectionCount;
}

/// @notice Immutable facts of one executed canonical Governance action.
struct StreamFinalityRecoveryRecord {
    bool executed;
    bytes32 recoveryId;
    StreamFinalityScope scope;
    bytes32 originalFinalityRecordHash;
    bytes32 predecessorRecoveryId;
    uint64 generation;
    bytes32 oldRouteHash;
    bytes32 recoveryRouteHash;
    bool artworkBytesChanged;
    StreamFinalityComponentExpectation replacementRoute;
    StreamFinalityManifestRef recoveryManifest;
    StreamFinalityRecoveryEvidenceSnapshot evidence;
    bytes32 reasonHash;
    string reasonURI;
    uint64 executedAt;
}

struct StreamFinalityRecoveryRefreshPlan {
    bool exists;
    bool complete;
    bool superseded;
    bytes32 manifestContentHash;
    bytes32 supersededByRecoveryId;
    uint256 lastAllocatedTokenIdAtExecution;
    uint256 rangeStart;
    uint256 rangeEnd;
    uint256 processedThrough;
    uint256 chunksEmitted;
}
