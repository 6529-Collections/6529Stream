// SPDX-License-Identifier: LGPL-3.0-only
//
// =============================================================================
// IDependencyRegistry — ELI5
// =============================================================================
// Read-only API: how many script chunks for a dependency key, and fetch one by index.
// =============================================================================

pragma solidity ^0.8.19;

interface IDependencyRegistry {   

    function getDependencyScriptCount(bytes32 dependencyNameAndVersion ) external view returns (uint256);

    function getDependencyScript(bytes32 dependencyNameAndVersion, uint256 index) external view returns (string memory);

}