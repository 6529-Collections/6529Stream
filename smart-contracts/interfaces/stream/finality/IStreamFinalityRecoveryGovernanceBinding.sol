// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Fixed companion bindings used by canonical Governance's recovery classifier.
interface IStreamFinalityRecoveryGovernanceBinding {
    function core() external view returns (address);
    function governanceAuthority() external view returns (address);
}
