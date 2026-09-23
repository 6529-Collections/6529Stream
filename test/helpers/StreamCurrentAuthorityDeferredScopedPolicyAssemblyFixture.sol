// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamCurrentAuthorityMigrationRecipe } from "./StreamCurrentAuthorityMigrationRecipe.sol";
import {
    StreamCurrentAuthorityNativeAssemblyFixture
} from "./StreamCurrentAuthorityNativeAssemblyFixture.sol";
import {
    StreamCurrentAuthorityFinalityGraph
} from "../../script/current/StreamCurrentAuthorityFinalityGraph.sol";
import {
    StreamCurrentAuthorityDeferredScopedPolicyGraph
} from "../../script/current/StreamCurrentAuthorityDeferredScopedPolicyGraph.sol";
import {
    StreamCurrentAuthorityScopedPolicyGraphCreation
} from "../../script/current/StreamCurrentAuthorityScopedPolicyGraphCreation.sol";
import {
    StreamFinalityNativeProviderReads as DeferredNativeConfig
} from "../../smart-contracts/domains/finality/StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityDiscoveryTypes as DeferredDiscoveryConfig
} from "../../smart-contracts/interfaces/stream/finality/StreamFinalityDiscoveryTypes.sol";

/// @notice Actual original deferred provider and Discovery with the unchanged Safe/Artist fixture.
/// @dev These explicit source-authored budgets are provisional test inputs, not measured gas
/// envelopes. Runtime, EIP170/EIP3860 and the complete STATIC ceremony require separate execution.
abstract contract StreamCurrentAuthorityDeferredScopedPolicyAssemblyFixture is
    StreamCurrentAuthorityMigrationRecipe,
    StreamCurrentAuthorityDeferredScopedPolicyGraph
{
    function _afterCurrentAuthorityCoordinatorDeployment()
        internal
        override(StreamCurrentAuthorityFinalityGraph, StreamCurrentAuthorityNativeAssemblyFixture)
    {
        StreamCurrentAuthorityNativeAssemblyFixture._afterCurrentAuthorityCoordinatorDeployment();
    }

    function _scopedPolicyCreation(string memory name)
        internal
        pure
        override
        returns (bytes memory)
    {
        return StreamCurrentAuthorityScopedPolicyGraphCreation.code(name);
    }

    function _scopedPolicySourceGas() internal pure override returns (SourceGas memory) {
        return SourceGas({
            readGas: 500000,
            selectionGas: 4000000,
            renderGas: 16000000,
            sourceGas: 8000000,
            inventoryGas: 6000000,
            snapshotGas: 16000000,
            archiveGas: 2000000
        });
    }

    function _scopedPolicyGraphGas() internal pure override returns (GraphGas memory) {
        return GraphGas({
            graphGas: 8000000,
            componentSourceGas: 12000000,
            providerSourceGas: 24000000,
            discoveryComponentGas: 12000000,
            finalityComponentGas: 30000000
        });
    }

    function _assemblyProviderSourceGas()
        internal
        view
        override(
            StreamCurrentAuthorityFinalityGraph,
            StreamCurrentAuthorityDeferredScopedPolicyGraph
        )
        returns (uint256)
    {
        return StreamCurrentAuthorityDeferredScopedPolicyGraph._assemblyProviderSourceGas();
    }

    function _assemblyComponentSourceGas()
        internal
        view
        override(
            StreamCurrentAuthorityFinalityGraph,
            StreamCurrentAuthorityDeferredScopedPolicyGraph
        )
        returns (uint256)
    {
        return StreamCurrentAuthorityDeferredScopedPolicyGraph._assemblyComponentSourceGas();
    }

    function _assemblyDiscoveryComponentGas()
        internal
        view
        override(
            StreamCurrentAuthorityFinalityGraph,
            StreamCurrentAuthorityDeferredScopedPolicyGraph
        )
        returns (uint32)
    {
        return StreamCurrentAuthorityDeferredScopedPolicyGraph._assemblyDiscoveryComponentGas();
    }

    function _assemblyFinalityComponentGas()
        internal
        view
        override(
            StreamCurrentAuthorityFinalityGraph,
            StreamCurrentAuthorityDeferredScopedPolicyGraph
        )
        returns (uint256)
    {
        return StreamCurrentAuthorityDeferredScopedPolicyGraph._assemblyFinalityComponentGas();
    }

    function _assemblyProviderTemplate()
        internal
        view
        override(
            StreamCurrentAuthorityFinalityGraph,
            StreamCurrentAuthorityDeferredScopedPolicyGraph
        )
        returns (string memory, string[] memory, bytes memory)
    {
        return StreamCurrentAuthorityDeferredScopedPolicyGraph._assemblyProviderTemplate();
    }

    function _assemblyDiscoveryTemplate()
        internal
        view
        override(
            StreamCurrentAuthorityFinalityGraph,
            StreamCurrentAuthorityDeferredScopedPolicyGraph
        )
        returns (string memory, string[] memory, bytes memory)
    {
        return StreamCurrentAuthorityDeferredScopedPolicyGraph._assemblyDiscoveryTemplate();
    }

    function _assemblyProviderArguments(DeferredNativeConfig.Config memory c)
        internal
        override(
            StreamCurrentAuthorityFinalityGraph,
            StreamCurrentAuthorityDeferredScopedPolicyGraph
        )
        returns (bytes memory)
    {
        return StreamCurrentAuthorityDeferredScopedPolicyGraph._assemblyProviderArguments(c);
    }

    function _assemblyDiscoveryArguments(DeferredDiscoveryConfig.Configuration memory c)
        internal
        override(
            StreamCurrentAuthorityFinalityGraph,
            StreamCurrentAuthorityDeferredScopedPolicyGraph
        )
        returns (bytes memory)
    {
        return StreamCurrentAuthorityDeferredScopedPolicyGraph._assemblyDiscoveryArguments(c);
    }

    function _afterCurrentAuthoritySelectorsDeployment(DeferredNativeConfig.Config memory c)
        internal
        override(
            StreamCurrentAuthorityFinalityGraph,
            StreamCurrentAuthorityDeferredScopedPolicyGraph
        )
    {
        StreamCurrentAuthorityDeferredScopedPolicyGraph._afterCurrentAuthoritySelectorsDeployment(c);
    }
}
