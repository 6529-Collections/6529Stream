// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Permanent seal of one authoritative WORK or RIGHTS selected head.
/// @dev Original record publication and original selector authority remain separate history.
interface IStreamRecordSelectionLock is IERC165 {
    struct SelectionLock {
        bool locked;
        bytes32 recordHash;
        uint64 revision;
        bytes32 selectionHash;
        address executor;
        bytes32 executorCodeHash;
        address moduleRegistry;
        bytes32 moduleRegistryCodeHash;
        bytes32 modulePointerHash;
        address governanceRoot;
        bytes32 governanceRootCodeHash;
        uint64 governanceRootRevision;
        bytes32 actionId;
        bytes32 scopeHash;
        bytes32 oldValueHash;
        bytes32 newValueHash;
        uint64 lockedAt;
        bytes32 lockHash;
    }

    error RecordSelectionLocked(uint256 collectionId, bytes32 subjectId);
    error RecordSelectionLockConflict(uint256 collectionId, bytes32 subjectId);
    error RecordSelectionLockAuthorityRequired();
    error RecordSelectionLockDependencyChanged(address target);
    error RecordSelectionLockReadFailed(address target);

    event RecordSelectionLockedPermanently(
        uint256 indexed collectionId,
        bytes32 indexed subjectId,
        bytes32 indexed recordHash,
        SelectionLock seal
    );

    /// @notice Schedule the exact current head under the live canonical root and Executor.
    function selectionLockTransition(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 expectedRecord,
        uint64 expectedRevision
    ) external view returns (bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash);

    /// @notice Seal once through the canonical Executor's exact TERMINAL_FREEZE action.
    function lockSelection(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 expectedRecord,
        uint64 expectedRevision
    ) external;

    /// @notice Immutable original seal; no current grant, definition or Executor liveness gate.
    /// @dev Unknown keys return the canonical empty tuple with locked=false.
    function selectionLock(uint256 collectionId, bytes32 subjectId)
        external view returns (SelectionLock memory);
}
