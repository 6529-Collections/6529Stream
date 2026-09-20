// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Fixed late publication-factory binding, independent of any minted scope or child.
interface IStreamScopedPreservationPolicyPublicationEvidenceBindingV1 {
    struct FactoryBinding {
        address factory;
        bytes32 factoryCodeHash;
        bytes32 recipeHash;
        bytes32 sourceFactoryDependenciesHash;
        uint256 graphGas;
        bytes32 configurationHash;
    }
    function scopedPreservationPolicyPublicationBinding()
        external
        view
        returns (FactoryBinding memory);
}
