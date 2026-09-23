// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Additive immutable preservation output-manifest binding on the selected evidence provider.
/// @dev The original V1 provider bindings remain separate and retain their original meaning.
interface IStreamPreservationPolicyOutputEvidenceBindingV1 {
    function preservationPolicyOutputManifest() external view returns (address);
    function preservationPolicyOutputManifestCodeHash() external view returns (bytes32);
}
