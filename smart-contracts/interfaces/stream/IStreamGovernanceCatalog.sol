// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamGovernanceExecutor.sol";

/// @notice Delayed, append-only extensions of the exact-target governance catalog.
/// @dev The genesis catalog is revision zero. Existing entries cannot be edited
///      or removed. An extension invalidates actions scheduled under older roots.
interface IStreamGovernanceCatalog {
    error GovernanceCatalogRevisionMismatch(uint64 expected, uint64 actual);
    error GovernanceCatalogDuplicateEntry(bytes32 key);
    error GovernanceCatalogExtensionSize(uint256 additions, uint256 total);
    error GovernanceCatalogExtensionComposition();

    event GovernanceActionPolicyExtended(
        uint64 indexed revision,
        bytes32 indexed oldCatalogHash,
        bytes32 indexed newCatalogHash,
        uint256 oldEntryCount,
        uint256 newEntryCount
    );

    /// @notice Append 1–128 entries, with a total catalog limit of 1,024.
    /// @dev Entries sort by keccak256(abi.encode(actionClass,target,selector)).
    ///      Requires a sealed Executor and an ordinary root-proposed class-3
    ///      batch consisting exactly of this call then manifest publication.
    function extendGovernanceActionPolicy(
        uint64 expectedRevision,
        bytes32 expectedOldCatalogHash,
        bytes32 expectedNewCatalogHash,
        GovernanceActionPolicyEntry[] calldata additions
    ) external;

    function governanceActionPolicyState()
        external
        view
        returns (
            bytes32 candidateProfileHash,
            bytes32 catalogHash,
            uint256 entryCount,
            uint64 revision
        );
}
