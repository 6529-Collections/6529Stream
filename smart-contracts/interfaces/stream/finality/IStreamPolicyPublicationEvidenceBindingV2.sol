// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Immutable bindings on the actual selected combined evidence provider.
/// @dev These getters do not themselves admit records. The provider must use the V2 readers only
/// for the exact V2 canonical Router root and preserve original V1 reads for original roots.
interface IStreamPolicyPublicationEvidenceBindingV2 {
    struct Configuration {
        address snapshotPublication;
        bytes32 snapshotPublicationCodeHash;
        address referencePublication;
        bytes32 referencePublicationCodeHash;
    }
    function policySnapshotPublicationV2() external view returns (address);
    function policySnapshotPublicationV2CodeHash() external view returns (bytes32);
    function policyReferencePublicationV2() external view returns (address);
    function policyReferencePublicationV2CodeHash() external view returns (bytes32);
}
