// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Standing adverse evidence is independent of the latest report's validity/currentness.
interface IStreamC2PAConflicts {
    struct Standing {
        bytes32 conflictId;
        bytes32 chainHash;
        bytes32 recordHash;
        bytes32 selectionHash;
        uint64 revision;
        uint64 unresolvedCount;
    }

    struct Conflict {
        bytes32 conflictId;
        uint256 collectionId;
        bytes32 subjectId;
        bytes32 artistId;
        bytes32 bindingHash;
        uint64 generation;
        bytes32 recordHash;
        bytes32 selectionHash;
        bytes32 previousConflict;
        bytes32 chainHash;
        uint64 revision;
        uint64 recordedAt;
    }

    struct Resolution {
        bytes32 actionId;
        bytes32 disputeRecordHash;
        bytes32 evidenceHash;
        bytes32 narrativeHash;
        uint64 acknowledgedAt;
    }
    error InvalidC2PAConflict();
    error C2PAConflictRead(address target);
    event C2PAConflictRecorded(
        bytes32 indexed conflictId,
        uint256 indexed collectionId,
        bytes32 indexed subjectId,
        Conflict conflict
    );
    event C2PAConflictCleared(
        bytes32 indexed conflictId, bytes32 indexed actionId, Resolution resolution
    );
    function standingConflict(uint256 collectionId, bytes32 subjectId)
        external
        view
        returns (Standing memory);
    function conflictRecord(bytes32 conflictId) external view returns (Conflict memory);
    function conflictResolution(bytes32 conflictId) external view returns (Resolution memory);
    function conflictAt(uint256 collectionId, bytes32 subjectId, uint64 revision)
        external
        view
        returns (bytes32);
    /// @notice Exact covered narrative bytes required by the original op46 evidence document.
    function resolutionNarrative(bytes32 conflictId) external view returns (bytes memory);
    function clearStandingConflict(bytes32 conflictId, bytes32 originalActionId) external;
}

/// @notice Token and collection adverse records are both disclosed, irrespective of report precedence.
interface IStreamStaticC2PAConflicts {
    function attributionC2PAConflicts(uint256 collectionId, uint256 tokenId)
        external
        view
        returns (
            IStreamC2PAConflicts.Standing memory tokenConflict,
            IStreamC2PAConflicts.Standing memory collectionConflict
        );
}
