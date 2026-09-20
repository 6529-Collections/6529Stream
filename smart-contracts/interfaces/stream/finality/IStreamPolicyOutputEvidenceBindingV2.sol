// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Additive immutable V2 output-manifest binding on the selected evidence provider.
/// @dev The original V1 provider bindings remain separate and retain their original meaning.
interface IStreamPolicyOutputEvidenceBindingV2 {
    function policyOutputManifestV2() external view returns (address);
    function policyOutputManifestV2CodeHash() external view returns (bytes32);
}
