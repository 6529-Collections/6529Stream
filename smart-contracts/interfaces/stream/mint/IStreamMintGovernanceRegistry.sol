// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Immutable governance binding on the canonical module registry.
/// @dev Deployment read only; this caller interface does not add an ERC165 claim.
interface IStreamMintGovernanceRegistry {
    function governanceExecutor() external view returns (address);
}
