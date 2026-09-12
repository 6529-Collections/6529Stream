// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Fixed construction joins checked by the last-deployed artist Coordinator.
interface IStreamFinalityDeploymentBindings {
    function coreReads() external view returns (address);
    function metadataReads() external view returns (address);
    function scopeEvidenceProvider() external view returns (address);
    function sanctionReads() external view returns (address);
    function artifactCoverage() external view returns (address);
    function finalityRoleRegistry() external view returns (address);
}
