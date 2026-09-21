// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Additional complete VIEW evidence selection, fixed by the same once-only governed binding.
/// @dev A basic-only source bind never advertises a completed selection. This interface supplies
/// immutable producer identities, not current source evidence, locks, archive coverage or finality.
interface IStreamViewPreservationFinalitySourcesV1 {
    struct Selection {
        address referencePublication;
        bytes32 referencePublicationCodeHash;
        address renderCriticalInventory;
        bytes32 renderCriticalInventoryCodeHash;
        address bundleArchiveCoverage;
        bytes32 bundleArchiveCoverageCodeHash;
    }

    /// @dev Initial exact constructor/dependency values checked at the same original class2 action.
    /// Reference gas values remain governed; this receipt preserves their initial checked values,
    /// while every operative consumer still validates current caps and complete source currentness.
    struct Receipt {
        Selection selection;
        bytes32 referenceDependenciesHash;
        bytes32 inventoryDependenciesHash;
        bytes32 bundleDependenciesHash;
        bytes32 basicBindingRecordHash;
        bytes32 actionId;
        uint64 boundAt;
        bytes32 recordHash;
    }
    function viewFinalitySources() external view returns (Selection memory);
    function viewFinalitySourcesReceipt() external view returns (Receipt memory);
}
