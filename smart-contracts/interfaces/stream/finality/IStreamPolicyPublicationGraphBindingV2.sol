// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Constructor-fixed COLLECTION publication recipe, independent of any minted plan.
interface IStreamPolicyPublicationGraphBindingV2 {
    struct CollectionFactoryBinding {
        address factory;
        bytes32 factoryCodeHash;
        bytes32 recipeHash;
        bytes32 sourceFactoryDependenciesHash;
        uint256 graphGas;
        bytes32 configurationHash;
    }
    function collectionPolicyPublicationBinding()
        external
        view
        returns (CollectionFactoryBinding memory);
}
