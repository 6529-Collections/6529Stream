// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPreservationInventoryTypes.sol";

interface IStreamBundleArchiveCoverage {
    function core() external view returns (address);
    function metadataHost() external view returns (address);
    function renderCriticalInventory() external view returns (address);
    function artifactCoverage() external view returns (address);
    function externalCoverage() external view returns (address);
    function deploymentChainId() external view returns (uint256);
    function coreCodeHash() external view returns (bytes32);
    function metadataCodeHash() external view returns (bytes32);
    function inventoryCodeHash() external view returns (bytes32);
    function bundleEvidence(bytes32 inventoryPlan)
        external
        view
        returns (StreamPreservationInventoryTypes.BundleEvidence memory);
    /// @notice Exact completed inventory's archive liveness, independently of source currentness.
    /// @dev Compose with inventory.requireCurrent and compare its exact plan/hash. This avoids
    /// recursively recomputing the full current source graph inside an already validated call.
    function requireCoverage(bytes32 inventoryPlan, bytes32 expectedRenderCriticalEvidenceHash)
        external
        view
        returns (StreamPreservationInventoryTypes.BundleEvidence memory);
}
