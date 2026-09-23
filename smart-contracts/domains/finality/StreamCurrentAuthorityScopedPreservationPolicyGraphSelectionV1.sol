// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../../interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyPublicationTypesV1 as Domains
} from "../../interfaces/stream/finality/StreamCurrentAuthorityScopedPreservationPolicyPublicationTypesV1.sol";

import {
    IStreamCurrentAuthorityScopedPreservationPolicyPublicationFactoryV1 as Factory
} from "../../interfaces/stream/finality/IStreamCurrentAuthorityScopedPreservationPolicyPublicationFactoryV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyPublicationGraphReadsV1 as GraphReads
} from "./StreamCurrentAuthorityScopedPreservationPolicyPublicationGraphReadsV1.sol";

import {
    StreamFinalityNativeProviderReads as Original
} from "./StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityScopedPreservationPolicyProviderReadsV1 as Provider
} from "./StreamFinalityScopedPreservationPolicyProviderReadsV1.sol";
import {
    IStreamScopedPreservationPolicyPublicationEvidenceBindingV1 as Binding
} from "../../interfaces/stream/finality/IStreamScopedPreservationPolicyPublicationEvidenceBindingV1.sol";
import {
    IStreamScopedPreservationPolicyPublicationFactoryV1 as BaseFactory
} from "../../interfaces/stream/finality/IStreamScopedPreservationPolicyPublicationFactoryV1.sol";
import {
    StreamScopedPreservationPolicyPublicationGraphTypesV1 as Graph
} from "../../interfaces/stream/finality/StreamScopedPreservationPolicyPublicationGraphTypesV1.sol";
import {
    StreamScopedPreservationPolicyPublicationRecipeV1 as Recipe
} from "./StreamScopedPreservationPolicyPublicationRecipeV1.sol";
import {
    IStreamFinalityProfileSources as Profiles
} from "../../interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    StreamScopedPreservationPolicySnapshotDefinitionsV2 as Definitions
} from "../records/StreamScopedPreservationPolicySnapshotDefinitionsV2.sol";
import {
    IStreamScopedContentRootPublication as Root
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamScopedPreservationPolicyContentRootPublicationV1 as PreservationRoot
} from "../../interfaces/stream/metadata/IStreamScopedPreservationPolicyContentRootPublicationV1.sol";
import {
    StreamScopedPreservationPolicyContentRootSchemasV2 as RootSchemas
} from "./StreamScopedPreservationPolicyContentRootSchemasV2.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import { StreamMetadataSubjects } from "../metadata/StreamMetadataSubjects.sol";
import { StreamFinalityRouterEvidence as Reads } from "./StreamFinalityRouterEvidence.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";

/// @notice Closed Router-profile selection and genuine recipe-factory resolution.
/// @dev Selection never calls reference/inventory/component evidence and cannot authorize it.
library StreamCurrentAuthorityScopedPreservationPolicyGraphSelectionV1 {
    struct Context {
        Original.Config original;
        Binding.FactoryBinding binding;
        Graph.Recipe recipe;
        O.Dependencies origin;
        D.Dependencies authority;
    }
    error ScopedPolicyGraphConfiguration();
    error ScopedPolicyGraphSource(address target);

    function initialize(Original.Config memory original, Binding.FactoryBinding memory b)
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
        ) revert ScopedPolicyGraphConfiguration();
        c.original = original;
        c.binding = b;
        _factory(c);
        bytes memory raw = Reads.dynamicRead(
            b.factory, abi.encodeCall(BaseFactory.recipe, ()), 24576, original.readGas
        );
        c.recipe = abi.decode(raw, (Graph.Recipe));
        (c.origin, c.authority) = _capabilities(c);
        if (
            keccak256(raw) != keccak256(abi.encode(c.recipe))
                || b.recipeHash
                    != Domains.recipeHash(original.chainId, c.recipe, c.origin, c.authority)
        ) revert ScopedPolicyGraphConfiguration();
        Recipe.validate(c.recipe);
        if (
            GraphReads.bindings(c.recipe, c.origin, c.authority, false)
                != b.sourceFactoryDependenciesHash
        ) revert ScopedPolicyGraphConfiguration();
        uint256[12] memory indexes = [uint256(0), 1, 4, 5, 2, 8, 9, 15, 16, 17, 20, 21];
        for (uint256 i; i < 12; ++i) {
            if (
                i != 5 && i != 6
                    && (c.recipe.inventory.targets[i] != original.targets[indexes[i]]
                        || c.recipe.inventory.codeHashes[i] != original.codeHashes[indexes[i]])
            ) revert ScopedPolicyGraphConfiguration();
        }
        if (
            c.recipe.inventory.chainId != original.chainId
                || c.recipe.targets[0] != original.targets[3]
                || c.recipe.codeHashes[0] != original.codeHashes[3]
                || c.recipe.inventory.artistTargets[0] != original.targets[11]
                || c.recipe.inventory.artistCodeHashes[0] != original.codeHashes[11]
        ) revert ScopedPolicyGraphConfiguration();
        c.binding.configurationHash = keccak256(
            abi.encode(
                Domains.PROVIDER_CONFIGURATION_DOMAIN,
                original.chainId,
                address(this),
                original,
                b.factory,
                b.factoryCodeHash,
                b.recipeHash,
                b.sourceFactoryDependenciesHash,
                b.graphGas,
                c.origin,
                c.authority
            )
        );
    }

    function isPolicy(Context memory c, StreamFinalityScope memory scope)
        public
        view
        returns (bool)
    {
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) return false;
        _scope(c, scope);
        address router = c.original.targets[2];
        if (router.code.length == 0 || router.codehash != c.original.codeHashes[2]) {
            revert ScopedPolicyGraphSource(router);
        }
        uint256 budget = c.original.readGas;
        if (
            abi.decode(
                    Reads.read(
                        router,
                        abi.encodeCall(
                            IERC165.supportsInterface, (type(PreservationRoot).interfaceId)
                        ),
                        32,
                        budget
                    ),
                    (uint256)
                ) != 1
        ) revert ScopedPolicyGraphSource(router);
        bytes32 head = abi.decode(
            Reads.read(router, abi.encodeCall(Root.scopedContentRootHead, (scope)), 32, budget),
            (bytes32)
        );
        if (head == 0) return false;
        bytes memory raw = Reads.read(
            router,
            abi.encodeCall(PreservationRoot.scopedPreservationPolicyContentRootBinding, (head)),
            800,
            budget
        );
        PreservationRoot.Binding memory b = abi.decode(raw, (PreservationRoot.Binding));
        if (keccak256(raw) != keccak256(abi.encode(b))) revert ScopedPolicyGraphSource(router);
        if (b.profileId == 0) {
            PreservationRoot.Binding memory empty;
            if (keccak256(raw) != keccak256(abi.encode(empty))) {
                revert ScopedPolicyGraphSource(router);
            }
            return false;
        }
        if (
            b.profileId != RootSchemas.PROFILE || b.metadataRouter != router
                || b.preservationOutputProfile
                    != keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2")
        ) revert ScopedPolicyGraphSource(router);
        return true;
    }

    function current(Context memory c, StreamFinalityScope memory scope)
        public
        view
        returns (Provider.Config memory p, Graph.Graph memory g)
    {
        _scope(c, scope);
        _factory(c);
        (O.Dependencies memory origin, D.Dependencies memory authority) = _capabilities(c);
        if (
            keccak256(abi.encode(origin, authority)) != keccak256(abi.encode(c.origin, c.authority))
        ) revert ScopedPolicyGraphSource(c.binding.factory);
        bytes memory raw = Reads.read(
            c.binding.factory,
            abi.encodeCall(BaseFactory.requireCurrentGraph, (scope)),
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
                            Domains.GRAPH_DOMAIN,
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
        ) revert ScopedPolicyGraphSource(c.binding.factory);
        for (uint256 i; i < 7; ++i) {
            if (g.children[i].code.length == 0 || g.children[i].codehash != g.codeHashes[i]) {
                revert ScopedPolicyGraphSource(g.children[i]);
            }
        }
        for (uint256 i; i < 22; ++i) {
            p.targets[i] = c.original.targets[i];
            p.codeHashes[i] = c.original.codeHashes[i];
        }
        uint256[6] memory roles = [uint256(6), 7, 8, 9, 18, 19];
        uint256[6] memory children = [uint256(2), 1, 3, 4, 5, 6];
        for (uint256 i; i < 6; ++i) {
            p.targets[roles[i]] = g.children[children[i]];
            p.codeHashes[roles[i]] = g.codeHashes[children[i]];
        }
        p.targets[10] = c.recipe.targets[2];
        p.codeHashes[10] = c.recipe.codeHashes[2];
        p.chainId = c.original.chainId;
        p.readGas = c.original.readGas;
        p.sourceGas = c.original.sourceGas;
        p.componentSourceGas = c.original.componentSourceGas;
        p.inventoryDependencyHash = D.dependencyHash(
            D.SCOPED_PRESERVATION_POLICY_INVENTORY_PROFILE,
            Recipe.inventory(c.recipe, g),
            c.origin,
            c.authority
        );
    }

    function sources(Context memory c, StreamFinalityScope memory scope)
        public
        view
        returns (Profiles.Sources memory s)
    {
        (, Graph.Graph memory g) = current(c, scope);
        // An actual preservation root cannot elect another same-shaped graph or supplied producer.
        bytes32 head = abi.decode(
            Reads.read(
                c.original.targets[2],
                abi.encodeCall(Root.scopedContentRootHead, (scope)),
                32,
                c.original.readGas
            ),
            (bytes32)
        );
        bytes memory raw = Reads.read(
            c.original.targets[2],
            abi.encodeCall(PreservationRoot.scopedPreservationPolicyContentRootBinding, (head)),
            800,
            c.original.readGas
        );
        PreservationRoot.Binding memory b = abi.decode(raw, (PreservationRoot.Binding));
        if (
            head == 0 || keccak256(raw) != keccak256(abi.encode(b))
                || b.profileId != RootSchemas.PROFILE || b.metadataRouter != c.original.targets[2]
                || b.preservationOutputProfile
                    != keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2")
                || b.outputManifest != g.children[2] || b.outputManifestCodeHash != g.codeHashes[2]
                || b.checkpoint != g.children[1] || b.checkpointCodeHash != g.codeHashes[1]
                || b.entropySourceSet != g.sourceSet
                || b.entropySourceSetCodeHash != g.sourceSetCodeHash
                || b.sourceFactory != c.recipe.targets[2]
                || b.sourceFactoryCodeHash != c.recipe.codeHashes[2]
                || b.factoryDependenciesHash != c.binding.sourceFactoryDependenciesHash
                || b.snapshotProfileHash != Definitions.PROFILE_HASH
        ) revert ScopedPolicyGraphSource(c.original.targets[2]);
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
        ) revert ScopedPolicyGraphSource(factory);
        uint256 budget = c.original.readGas;
        if (
            _support(factory, type(IERC165).interfaceId, budget) != 1
                || _support(factory, type(Factory).interfaceId, budget) != 1
                || _support(factory, 0xffffffff, budget) != 0
        ) revert ScopedPolicyGraphSource(factory);
        if (
            abi.decode(
                        Reads.read(
                            factory,
                            abi.encodeCall(
                                IERC165.supportsInterface, (type(BaseFactory).interfaceId)
                            ),
                            32,
                            budget
                        ),
                        (uint256)
                    ) != 1
                || abi.decode(
                        Reads.read(
                            factory,
                            abi.encodeCall(
                                BaseFactory.scopedPreservationPolicyPublicationFactoryProfile, ()
                            ),
                            32,
                            budget
                        ),
                        (bytes32)
                    ) != Domains.FACTORY_PROFILE
                || abi.decode(
                        Reads.read(factory, abi.encodeCall(BaseFactory.recipeHash, ()), 32, budget),
                        (bytes32)
                    ) != c.binding.recipeHash
                || abi.decode(
                        Reads.read(
                            factory,
                            abi.encodeCall(BaseFactory.sourceFactoryDependenciesHash, ()),
                            32,
                            budget
                        ),
                        (bytes32)
                    ) != c.binding.sourceFactoryDependenciesHash
                || abi.decode(
                        Reads.read(factory, abi.encodeCall(BaseFactory.core, ()), 32, budget),
                        (address)
                    ) != c.original.targets[0]
                || abi.decode(
                        Reads.read(
                            factory, abi.encodeCall(BaseFactory.metadataHost, ()), 32, budget
                        ),
                        (address)
                    ) != c.original.targets[1]
        ) revert ScopedPolicyGraphSource(factory);
    }

    function _capabilities(Context memory c)
        private
        view
        returns (O.Dependencies memory origin, D.Dependencies memory authority)
    {
        bytes memory raw = Reads.read(
            c.binding.factory,
            abi.encodeCall(Factory.originDependencies, ()),
            128,
            c.original.readGas
        );
        origin = abi.decode(raw, (O.Dependencies));
        if (keccak256(raw) != keccak256(abi.encode(origin))) {
            revert ScopedPolicyGraphSource(c.binding.factory);
        }
        raw = Reads.read(
            c.binding.factory,
            abi.encodeCall(Factory.authorityDependencies, ()),
            96,
            c.original.readGas
        );
        authority = abi.decode(raw, (D.Dependencies));
        if (keccak256(raw) != keccak256(abi.encode(authority))) {
            revert ScopedPolicyGraphSource(c.binding.factory);
        }
    }

    function _support(address target, bytes4 id, uint256 budget) private view returns (uint256) {
        return abi.decode(
            Reads.read(target, abi.encodeCall(IERC165.supportsInterface, (id)), 32, budget),
            (uint256)
        );
    }

    function _scope(Context memory c, StreamFinalityScope memory scope) private pure {
        if (
            scope.scopeType != StreamFinalityScopeType.TOKEN
                && scope.scopeType != StreamFinalityScopeType.RELEASE
                && scope.scopeType != StreamFinalityScopeType.SEASON
        ) revert ScopedPolicyGraphConfiguration();
        StreamMetadataSubjects.scopeSubject(c.original.chainId, c.original.targets[0], scope);
    }
}
