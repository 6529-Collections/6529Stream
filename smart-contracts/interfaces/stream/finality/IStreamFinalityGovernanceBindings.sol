// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Canonical immutable governance identities consumed by finality targets.
interface IStreamFinalityGovernanceBindings {
    function roleRegistry() external view returns (address);
    function owner() external view returns (address);
}
