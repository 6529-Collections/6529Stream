// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityNativeProviderReads as Original
} from "./StreamFinalityNativeProviderReads.sol";
import {
    IStreamPolicyPublicationGraphBindingV2 as Binding
} from "../../interfaces/stream/finality/IStreamPolicyPublicationGraphBindingV2.sol";
import {
    IStreamPolicyPublicationFactoryV2 as Factory
} from "../../interfaces/stream/finality/IStreamPolicyPublicationFactoryV2.sol";
import {
    StreamPolicyPublicationGraphTypesV2 as Graph
} from "../../interfaces/stream/finality/StreamPolicyPublicationGraphTypesV2.sol";
import { StreamPolicyPublicationRecipeV2 as Recipe } from "./StreamPolicyPublicationRecipeV2.sol";
import {
    IStreamFinalityProfileSources as Profiles
} from "../../interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    StreamPolicySnapshotDefinitionsV2 as Definitions
} from "../records/StreamPolicySnapshotDefinitionsV2.sol";
import {
    IStreamContentRootPublication as Root
} from "../../interfaces/stream/metadata/IStreamContentRootPublication.sol";
import {
    IStreamPolicyContentRootPublicationV2 as RootV2
} from "../../interfaces/stream/metadata/IStreamPolicyContentRootPublicationV2.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import { StreamMetadataSubjects } from "../metadata/StreamMetadataSubjects.sol";
import { StreamFinalityRouterEvidence as Reads } from "./StreamFinalityRouterEvidence.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import {
    IStreamStaticMetadataRouter as Static
} from "../../interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";

/// @notice Closed Router-profile selection and genuine recipe-factory resolution.
/// @dev Selection never calls reference/inventory/component evidence and cannot authorize it.
library StreamFinalityPolicyGraphSelectionV2 {
    bytes32 private constant ROOT_PROFILE = keccak256("6529STREAM_POLICY_CURRENT_FULL_CONTENT_V2");

    struct Context {
        Original.Config original;
        Binding.CollectionFactoryBinding binding;
        Graph.Recipe recipe;
    }
    error PolicyGraphConfiguration();
    error PolicyGraphSource(address target);

    function initialize(Original.Config memory original, Binding.CollectionFactoryBinding memory b)
        public
        view
        returns (Context memory c)
    {
        if (
            b.factory == address(0) || b.factoryCodeHash == 0 || b.recipeHash == 0
                || b.sourceFactoryDependenciesHash == 0 || b.configurationHash != 0
                || b.graphGas < original.readGas || b.graphGas > type(uint32).max
                || original.componentSourceGas
                    <= b.graphGas + b.graphGas / 63 + original.readGas + 200000
        ) revert PolicyGraphConfiguration();
        c.original = original;
        c.binding = b;
        _factory(c);
        bytes memory raw = Reads.dynamicRead(
            b.factory, abi.encodeCall(Factory.recipe, ()), 24576, original.readGas
        );
        c.recipe = abi.decode(raw, (Graph.Recipe));
        if (
            keccak256(raw) != keccak256(abi.encode(c.recipe))
                || b.recipeHash != keccak256(abi.encode(Graph.PROFILE, original.chainId, c.recipe))
        ) revert PolicyGraphConfiguration();
        Recipe.validate(c.recipe);
        uint256[12] memory indexes = [uint256(0), 1, 4, 5, 2, 8, 9, 15, 16, 17, 20, 21];
        for (uint256 i; i < 12; ++i) {
            if (
                i != 5 && i != 6
                    && (c.recipe.inventory.targets[i] != original.targets[indexes[i]]
                        || c.recipe.inventory.codeHashes[i] != original.codeHashes[indexes[i]])
            ) revert PolicyGraphConfiguration();
        }
        if (
            c.recipe.inventory.chainId != original.chainId
                || c.recipe.targets[0] != original.targets[3]
                || c.recipe.codeHashes[0] != original.codeHashes[3]
                || c.recipe.inventory.artistTargets[0] != original.targets[11]
                || c.recipe.inventory.artistCodeHashes[0] != original.codeHashes[11]
        ) revert PolicyGraphConfiguration();
        c.binding.configurationHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_POLICY_FACTORY_PROVIDER_CONFIGURATION_V2"),
                original.chainId,
                address(this),
                original,
                b.factory,
                b.factoryCodeHash,
                b.recipeHash,
                b.sourceFactoryDependenciesHash,
                b.graphGas
            )
        );
    }

    function isPolicy(Context memory c, StreamFinalityScope memory scope)
        public
        view
        returns (bool)
    {
        if (scope.scopeType != StreamFinalityScopeType.COLLECTION) return false;
        _scope(c, scope);
        address router = c.original.targets[2];
        if (router.code.length == 0 || router.codehash != c.original.codeHashes[2]) {
            revert PolicyGraphSource(router);
        }
        uint256 budget = c.original.readGas;
        if (
            abi.decode(
                    Reads.read(
                        router,
                        abi.encodeCall(IERC165.supportsInterface, (type(RootV2).interfaceId)),
                        32,
                        budget
                    ),
                    (uint256)
                ) != 1
        ) revert PolicyGraphSource(router);
        bytes32 head = abi.decode(
            Reads.read(
                router,
                abi.encodeCall(Root.collectionContentRootHead, (scope.collectionId)),
                32,
                budget
            ),
            (bytes32)
        );
        if (head == 0) return false;
        bytes memory raw = Reads.read(
            router, abi.encodeCall(RootV2.policyContentRootBinding, (head)), 544, budget
        );
        RootV2.Binding memory b = abi.decode(raw, (RootV2.Binding));
        if (keccak256(raw) != keccak256(abi.encode(b))) revert PolicyGraphSource(router);
        if (b.profileId == 0) {
            RootV2.Binding memory empty;
            if (keccak256(raw) != keccak256(abi.encode(empty))) {
                revert PolicyGraphSource(router);
            }
            return false;
        }
        if (b.profileId != ROOT_PROFILE) revert PolicyGraphSource(router);
        bytes memory activation = Reads.read(
            router,
            abi.encodeCall(Static.staticMetadataActivation, (scope.collectionId)),
            96,
            budget
        );
        (bytes32 record, uint64 revision, bytes32 overridesHead) =
            abi.decode(activation, (bytes32, uint64, bytes32));
        if (
            keccak256(activation) != keccak256(abi.encode(record, revision, overridesHead))
                || record == 0 || revision == 0
        ) revert PolicyGraphSource(router);
        return true;
    }

    function current(Context memory c, StreamFinalityScope memory scope)
        public
        view
        returns (Original.Config memory p, Graph.Graph memory g)
    {
        _scope(c, scope);
        _factory(c);
        bytes memory raw = Reads.read(
            c.binding.factory,
            abi.encodeCall(Factory.requireCurrentGraph, (scope)),
            736,
            c.binding.graphGas
        );
        g = abi.decode(raw, (Graph.Graph));
        if (
            keccak256(raw) != keccak256(abi.encode(g)) || g.preparedChildren != 7
                || keccak256(abi.encode(g.scope)) != keccak256(abi.encode(scope))
                || g.inventoryPlan == 0
                || g.graphId
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_POLICY_PUBLICATION_GRAPH_V2"),
                            c.original.chainId,
                            c.binding.factory,
                            c.binding.recipeHash,
                            c.binding.sourceFactoryDependenciesHash,
                            scope,
                            g.inventoryPlan,
                            g.sourceSet,
                            g.sourceSetCodeHash
                        )
                    )
        ) revert PolicyGraphSource(c.binding.factory);
        for (uint256 i; i < 7; ++i) {
            if (g.children[i].code.length == 0 || g.children[i].codehash != g.codeHashes[i]) {
                revert PolicyGraphSource(g.children[i]);
            }
        }
        for (uint256 i; i < 22; ++i) {
            p.targets[i] = c.original.targets[i];
            p.codeHashes[i] = c.original.codeHashes[i];
        }
        uint256[4] memory roles = [uint256(8), 9, 18, 19];
        uint256[4] memory children = [uint256(3), 4, 5, 6];
        for (uint256 i; i < 4; ++i) {
            p.targets[roles[i]] = g.children[children[i]];
            p.codeHashes[roles[i]] = g.codeHashes[children[i]];
        }
        p.targets[10] = c.recipe.targets[2];
        p.codeHashes[10] = c.recipe.codeHashes[2];
        p.chainId = c.original.chainId;
        p.readGas = c.original.readGas;
        p.sourceGas = c.original.sourceGas;
        p.componentSourceGas = c.original.componentSourceGas;
        p.inventoryDependencyHash = keccak256(abi.encode(Recipe.inventory(c.recipe, g)));
    }

    function sources(Context memory c, StreamFinalityScope memory scope)
        public
        view
        returns (Profiles.Sources memory s)
    {
        (, Graph.Graph memory g) = current(c, scope);
        // An actual V2 root cannot elect another same-shaped graph or supplied producer.
        bytes32 head = abi.decode(
            Reads.read(
                c.original.targets[2],
                abi.encodeCall(Root.collectionContentRootHead, (scope.collectionId)),
                32,
                c.original.readGas
            ),
            (bytes32)
        );
        bytes memory raw = Reads.read(
            c.original.targets[2],
            abi.encodeCall(RootV2.policyContentRootBinding, (head)),
            544,
            c.original.readGas
        );
        RootV2.Binding memory b = abi.decode(raw, (RootV2.Binding));
        if (
            head == 0 || keccak256(raw) != keccak256(abi.encode(b)) || b.profileId != ROOT_PROFILE
                || b.outputManifest != g.children[2] || b.outputManifestCodeHash != g.codeHashes[2]
                || b.checkpoint != g.children[1] || b.checkpointCodeHash != g.codeHashes[1]
                || b.entropySourceSet != g.sourceSet
                || b.entropySourceSetCodeHash != g.sourceSetCodeHash || b.checkpointHash == 0
                || b.checkpointStateHash == 0 || b.outputRoot == 0 || b.inventoryHash == 0
                || b.policyChainHash == 0 || b.outputSchemaHash == 0
                || b.outputCanonicalizationHash == 0 || b.leafSchemaHash == 0
                || b.rootSchemaHash == 0 || b.rootCanonicalizationHash == 0
        ) revert PolicyGraphSource(c.original.targets[2]);
        s.scope = scope;
        s.profile = Profiles.Profile(
            Definitions.PROFILE_HASH,
            g.children[4],
            g.codeHashes[4],
            g.children[3],
            g.codeHashes[3],
            c.recipe.targets[2],
            c.recipe.codeHashes[2],
            c.binding.configurationHash
        );
    }

    function _factory(Context memory c) private view {
        address factory = c.binding.factory;
        if (
            c.original.chainId != block.chainid || factory.code.length == 0
                || factory.codehash != c.binding.factoryCodeHash
        ) revert PolicyGraphSource(factory);
        uint256 budget = c.original.readGas;
        if (
            abi.decode(
                        Reads.read(
                            factory,
                            abi.encodeCall(IERC165.supportsInterface, (type(Factory).interfaceId)),
                            32,
                            budget
                        ),
                        (uint256)
                    ) != 1
                || abi.decode(
                        Reads.read(
                            factory,
                            abi.encodeCall(Factory.policyPublicationFactoryProfile, ()),
                            32,
                            budget
                        ),
                        (bytes32)
                    ) != Graph.PROFILE
                || abi.decode(
                        Reads.read(factory, abi.encodeCall(Factory.recipeHash, ()), 32, budget),
                        (bytes32)
                    ) != c.binding.recipeHash
                || abi.decode(
                        Reads.read(
                            factory,
                            abi.encodeCall(Factory.sourceFactoryDependenciesHash, ()),
                            32,
                            budget
                        ),
                        (bytes32)
                    ) != c.binding.sourceFactoryDependenciesHash
                || abi.decode(
                        Reads.read(factory, abi.encodeCall(Factory.core, ()), 32, budget), (address)
                    ) != c.original.targets[0]
                || abi.decode(
                        Reads.read(factory, abi.encodeCall(Factory.metadataHost, ()), 32, budget),
                        (address)
                    ) != c.original.targets[1]
        ) revert PolicyGraphSource(factory);
    }

    function _scope(Context memory c, StreamFinalityScope memory scope) private pure {
        if (
            scope.scopeType != StreamFinalityScopeType.COLLECTION || scope.collectionId == 0
                || scope.tokenId != 0 || scope.scopeId != 0
        ) revert PolicyGraphConfiguration();
        StreamMetadataSubjects.scopeSubject(c.original.chainId, c.original.targets[0], scope);
    }
}
