// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityPreservationMigrationRecipe
} from "./StreamCurrentAuthorityPreservationMigrationRecipe.sol";
import {
    StreamCurrentAuthorityNativeAssemblyFixture
} from "./StreamCurrentAuthorityNativeAssemblyFixture.sol";
import {
    StreamCurrentAuthorityFinalityGraph
} from "../../script/current/StreamCurrentAuthorityFinalityGraph.sol";
import {
    StreamCurrentAuthorityPreservationPolicyGraph
} from "../../script/current/StreamCurrentAuthorityPreservationPolicyGraph.sol";
import {
    StreamCurrentAuthorityPreservationPolicyGraphCreation
} from "../../script/current/StreamCurrentAuthorityPreservationPolicyGraphCreation.sol";
import {
    StreamFinalityNativeProviderReads as PreservationNativeConfig
} from "../../smart-contracts/domains/finality/StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityDiscoveryTypes as PreservationDiscoveryConfig
} from "../../smart-contracts/interfaces/stream/finality/StreamFinalityDiscoveryTypes.sol";

/// @notice Actual original full preservation provider and Discovery with the unchanged Safe/Artist fixture.
/// @dev These explicit source-authored budgets are provisional test inputs, not measured gas
/// envelopes. Runtime, EIP170/EIP3860 and the complete STATIC ceremony require separate execution.
abstract contract StreamCurrentAuthorityPreservationPolicyAssemblyFixture is
    StreamCurrentAuthorityPreservationMigrationRecipe,
    StreamCurrentAuthorityPreservationPolicyGraph
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
        return StreamCurrentAuthorityPreservationPolicyGraphCreation.code(name);
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
        override(StreamCurrentAuthorityFinalityGraph, StreamCurrentAuthorityPreservationPolicyGraph)
        returns (uint256)
    {
        return StreamCurrentAuthorityPreservationPolicyGraph._assemblyProviderSourceGas();
    }

    function _assemblyComponentSourceGas()
        internal
        view
        override(StreamCurrentAuthorityFinalityGraph, StreamCurrentAuthorityPreservationPolicyGraph)
        returns (uint256)
    {
        return StreamCurrentAuthorityPreservationPolicyGraph._assemblyComponentSourceGas();
    }

    function _assemblyDiscoveryComponentGas()
        internal
        view
        override(StreamCurrentAuthorityFinalityGraph, StreamCurrentAuthorityPreservationPolicyGraph)
        returns (uint32)
    {
        return StreamCurrentAuthorityPreservationPolicyGraph._assemblyDiscoveryComponentGas();
    }

    function _assemblyFinalityComponentGas()
        internal
        view
        override(StreamCurrentAuthorityFinalityGraph, StreamCurrentAuthorityPreservationPolicyGraph)
        returns (uint256)
    {
        return StreamCurrentAuthorityPreservationPolicyGraph._assemblyFinalityComponentGas();
    }

    function _assemblyProviderTemplate()
        internal
        view
        override(StreamCurrentAuthorityFinalityGraph, StreamCurrentAuthorityPreservationPolicyGraph)
        returns (string memory, string[] memory, bytes memory)
    {
        return StreamCurrentAuthorityPreservationPolicyGraph._assemblyProviderTemplate();
    }

    function _assemblyDiscoveryTemplate()
        internal
        view
        override(StreamCurrentAuthorityFinalityGraph, StreamCurrentAuthorityPreservationPolicyGraph)
        returns (string memory, string[] memory, bytes memory)
    {
        return StreamCurrentAuthorityPreservationPolicyGraph._assemblyDiscoveryTemplate();
    }

    function _assemblyProviderArguments(PreservationNativeConfig.Config memory c)
        internal
        override(StreamCurrentAuthorityFinalityGraph, StreamCurrentAuthorityPreservationPolicyGraph)
        returns (bytes memory)
    {
        return StreamCurrentAuthorityPreservationPolicyGraph._assemblyProviderArguments(c);
    }

    function _assemblyDiscoveryArguments(PreservationDiscoveryConfig.Configuration memory c)
        internal
        override(StreamCurrentAuthorityFinalityGraph, StreamCurrentAuthorityPreservationPolicyGraph)
        returns (bytes memory)
    {
        return StreamCurrentAuthorityPreservationPolicyGraph._assemblyDiscoveryArguments(c);
    }

    function _afterCurrentAuthoritySelectorsDeployment(PreservationNativeConfig.Config memory c)
        internal
        override(StreamCurrentAuthorityFinalityGraph, StreamCurrentAuthorityPreservationPolicyGraph)
    {
        StreamCurrentAuthorityPreservationPolicyGraph._afterCurrentAuthoritySelectorsDeployment(c);
    }
}
