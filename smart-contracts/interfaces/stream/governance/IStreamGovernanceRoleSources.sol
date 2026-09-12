// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Read of the actual Executor's immutable bootstrap role-registry binding.
interface IStreamGovernanceRoleSource {
    function roleRegistry() external view returns (address);
}

/// @notice Deployment ownership check on the pinned RoleRegistry.
interface IStreamRoleRegistryOwnership {
    function owner() external view returns (address);
}
