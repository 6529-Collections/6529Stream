// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Explicit ADR0054 preservation output identity, separate from live tokenURI output.
/// @dev Binding pins are not source-analysis, golden-vector or publication authorization evidence.
library StreamPreservationPolicyOutputTypesV1 {
    /// @dev Exactly nine ABI words. The last six are the canonical producer binding.
    struct Binding {
        address producer;
        bytes32 producerCodeHash;
        bytes32 profile;
        address core;
        address metadataRouter;
        address liveRenderer;
        bytes32 liveRendererCodeHash;
        address attribution;
        bytes32 attributionCodeHash;
    }

    /// @dev Exactly seven ABI words, observed from the governed admission of this row's version.
    /// No caller-supplied source assertion is authoritative. The source roster is retained by registry.
    struct Admission {
        address registry;
        bytes32 registryCodeHash;
        bytes32 versionKey;
        bytes32 registrationHash;
        bytes32 readSetHash;
        bytes32 analysisHash;
        bytes32 goldenHash;
    }

    error InvalidPreservationBinding();
    error PreservationDependencyChanged(address target);
    error PreservationReadFailed(address target, bytes4 selector);
    error PreservationParentGas(uint256 available, uint256 required);
}
