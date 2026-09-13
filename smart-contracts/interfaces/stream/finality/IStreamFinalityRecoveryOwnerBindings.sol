// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Fixed OwnerRecords deployment identity for action-bound recovery notice evidence.
/// @dev Both exact address getters must match the companion's immutable Core and Executor.
interface IStreamFinalityRecoveryOwnerBindings {
    function core() external view returns (address);
    function governanceAuthority() external view returns (address);
}
