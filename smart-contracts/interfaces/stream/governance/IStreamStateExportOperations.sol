// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Append-only state-export operations on the active governance-hosted publisher.
/// @dev Every write is rejected during a governance batch or after publisher replacement.
interface IStreamStateExportOperations {
    error StateExportDuringGovernanceExecution();
    error StateExportPublisherInactive();
    error StateExportPublisherUnauthorized(address caller);
    error StateExportInvalidHash();
    error StateExportInvalidAnchor(uint256 blockNumber, bytes32 blockHash);
    error StateExportAnchorNotIncreasing(uint256 previousBlock, uint256 proposedBlock);
    error StateExportAlreadyPublished(bytes32 exportHash);
    error StateExportUnknown(bytes32 exportHash);
    error StateExportInvalidURI();
    error StateExportChallengeAlreadyRecorded(bytes32 exportHash, bytes32 challengeHash);
    error StateExportInvalidSupersession(bytes32 oldExportHash, bytes32 newExportHash);
    error StateExportIndexOutOfBounds(uint256 index);

    /// @notice A live ROLE_EXPORT_PUBLISHER holder appends a unique canonical recent-block claim.
    /// @dev The past block must be within the EVM's 256-block hash window. Heights
    ///      increase; equal height is allowed only for a different canonical reorg hash.
    ///      All hashes are nonzero. URI is nonempty strict UTF-8, at most 2,048 bytes.
    function publishStateExport(
        uint256 blockNumber,
        bytes32 blockHash,
        bytes32 exportHash,
        bytes32 manifestHash,
        string calldata manifestURI
    ) external;

    /// @notice Anyone may append one challenge per (known export, nonzero challenge hash).
    /// @dev Challenges do not alter the latest export or supersession lineage.
    function challengeStateExport(
        bytes32 exportHash,
        bytes32 challengeHash,
        string calldata challengeURI
    ) external;

    /// @notice A live publisher links an older claim once to a previously published newer claim.
    /// @dev Both claims must exist on this publisher. Forward-only sequence links
    ///      prevent cycles. The latest publication and all historical data are retained.
    function supersedeStateExport(
        bytes32 oldExportHash,
        bytes32 newExportHash,
        bytes32 reasonHash,
        string calldata reasonURI
    ) external;
}
