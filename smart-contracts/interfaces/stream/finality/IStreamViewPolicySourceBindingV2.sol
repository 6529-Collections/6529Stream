// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Actual selected combined provider's constructor-owned VIEW V2 policy source.
interface IStreamViewPolicySourceBindingV2 {
    function viewPolicySourceFactoryV2() external view returns (address);
    function viewPolicySourceFactoryV2CodeHash() external view returns (bytes32);
}
