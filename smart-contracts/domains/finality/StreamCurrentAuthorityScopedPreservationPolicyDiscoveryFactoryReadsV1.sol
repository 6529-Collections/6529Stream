// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import {
    IStreamScopedPreservationPolicyPublicationEvidenceBindingV1 as Binding
} from "../../interfaces/stream/finality/IStreamScopedPreservationPolicyPublicationEvidenceBindingV1.sol";
import {
    IStreamCurrentAuthorityScopedPreservationPolicyPublicationFactoryV1 as Factory
} from "../../interfaces/stream/finality/IStreamCurrentAuthorityScopedPreservationPolicyPublicationFactoryV1.sol";
import {
    IStreamScopedPreservationPolicyPublicationFactoryV1 as BaseFactory
} from "../../interfaces/stream/finality/IStreamScopedPreservationPolicyPublicationFactoryV1.sol";
import {
    StreamScopedPreservationPolicyPublicationGraphTypesV1 as Graph
} from "../../interfaces/stream/finality/StreamScopedPreservationPolicyPublicationGraphTypesV1.sol";
import {
    StreamFinalityDiscoveryTypes as Discovery
} from "../../interfaces/stream/finality/StreamFinalityDiscoveryTypes.sol";
import {
    IStreamFinalityProfileSources as Profiles
} from "../../interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamScopedPreservationPolicySnapshotDefinitionsV2 as Definitions
} from "../records/StreamScopedPreservationPolicySnapshotDefinitionsV2.sol";
import {
    StreamScopedPreservationPolicyPublicationRecipeV1 as Recipe
} from "./StreamScopedPreservationPolicyPublicationRecipeV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyPublicationGraphReadsV1 as GraphReads
} from "./StreamCurrentAuthorityScopedPreservationPolicyPublicationGraphReadsV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyPublicationTypesV1 as Current
} from "../../interfaces/stream/finality/StreamCurrentAuthorityScopedPreservationPolicyPublicationTypesV1.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../../interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import { StreamFinalityRouterEvidence as Reads } from "./StreamFinalityRouterEvidence.sol";

/// @notice Fixed current-authority publication-factory joins for scoped-policy discovery.
/// @dev Constructor validation never asks for a scope, graph, publication or component state.
library StreamCurrentAuthorityScopedPreservationPolicyDiscoveryFactoryReadsV1 {
    error DiscoveryConfiguration(address target);
    error DiscoveryDependency(address target);
    error DiscoveryUnsupportedProfile();

    function validate(Discovery.Configuration memory c, Binding.FactoryBinding memory b)
        public
        view
        returns (address entropyFactory, bytes32 entropyCodeHash)
    {
        if (
            b.graphGas < 50000 || b.graphGas > type(uint32).max || b.recipeHash == 0
                || b.sourceFactoryDependenciesHash == 0 || b.configurationHash == 0
        ) {
            revert DiscoveryConfiguration(b.factory);
        }
        _pin(b.factory, b.factoryCodeHash);
        _supports(b.factory, type(Factory).interfaceId, c.readGas);
        _supports(b.factory, type(BaseFactory).interfaceId, c.readGas);
        _supports(c.provider, type(Binding).interfaceId, c.readGas);
        bytes memory raw = Reads.read(
            c.provider,
            abi.encodeCall(Binding.scopedPreservationPolicyPublicationBinding, ()),
            192,
            c.readGas
        );
        Binding.FactoryBinding memory actual = abi.decode(raw, (Binding.FactoryBinding));
        if (
            keccak256(raw) != keccak256(abi.encode(actual))
                || keccak256(raw) != keccak256(abi.encode(b))
        ) {
            revert DiscoveryConfiguration(c.provider);
        }
        if (
            _word(
                        b.factory,
                        abi.encodeCall(
                            BaseFactory.scopedPreservationPolicyPublicationFactoryProfile, ()
                        ),
                        c.readGas
                    ) != Current.FACTORY_PROFILE
                || _word(b.factory, abi.encodeCall(BaseFactory.recipeHash, ()), c.readGas)
                    != b.recipeHash
                || _word(
                        b.factory,
                        abi.encodeCall(BaseFactory.sourceFactoryDependenciesHash, ()),
                        c.readGas
                    ) != b.sourceFactoryDependenciesHash
        ) {
            revert DiscoveryConfiguration(b.factory);
        }
        raw = Reads.read(b.factory, abi.encodeCall(Factory.originDependencies, ()), 128, c.readGas);
        O.Dependencies memory od = abi.decode(raw, (O.Dependencies));
        if (keccak256(raw) != keccak256(abi.encode(od))) revert DiscoveryConfiguration(b.factory);
        raw =
            Reads.read(b.factory, abi.encodeCall(Factory.authorityDependencies, ()), 96, c.readGas);
        D.Dependencies memory ad = abi.decode(raw, (D.Dependencies));
        if (keccak256(raw) != keccak256(abi.encode(ad))) revert DiscoveryConfiguration(b.factory);
        raw =
            Reads.dynamicRead(b.factory, abi.encodeCall(BaseFactory.recipe, ()), 16384, b.graphGas);
        Graph.Recipe memory r = abi.decode(raw, (Graph.Recipe));
        if (
            keccak256(raw) != keccak256(abi.encode(r))
                || Current.recipeHash(block.chainid, r, od, ad) != b.recipeHash
                || r.inventory.chainId != block.chainid || r.inventory.targets[0] != c.core
                || r.inventory.codeHashes[0] != c.core.codehash
                || r.inventory.targets[1] != c.metadata
                || r.inventory.codeHashes[1] != c.metadata.codehash
                || r.inventory.targets[4] != c.router
                || r.inventory.codeHashes[4] != c.router.codehash || r.targets[0] != c.membership
                || r.codeHashes[0] != c.membership.codehash
                || r.inventory.artistTargets[0] != c.artist
                || r.inventory.artistCodeHashes[0] != c.artist.codehash
        ) {
            revert DiscoveryConfiguration(b.factory);
        }
        Recipe.validate(r);
        if (
            GraphReads.bindings(r, od, ad, false) != b.sourceFactoryDependenciesHash
                || _word(b.factory, abi.encodeCall(BaseFactory.core, ()), c.readGas)
                    != bytes32(uint256(uint160(c.core)))
                || _word(b.factory, abi.encodeCall(BaseFactory.metadataHost, ()), c.readGas)
                    != bytes32(uint256(uint160(c.metadata)))
                || _word(b.factory, abi.encodeCall(BaseFactory.entropySourceFactory, ()), c.readGas)
                    != bytes32(uint256(uint160(r.targets[2])))
        ) {
            revert DiscoveryConfiguration(b.factory);
        }
        return (r.targets[2], r.codeHashes[2]);
    }

    /// @dev The actual fixed factory validates all seven children and current original source
    /// plan. This method authenticates identities only; no reference/inventory evidence is read.
    function current(
        Binding.FactoryBinding memory b,
        address entropyFactory,
        bytes32 entropyCodeHash,
        StreamFinalityScope memory scope
    ) public view returns (Profiles.Profile memory p) {
        if (
            scope.collectionId == 0
                || (scope.scopeType == StreamFinalityScopeType.TOKEN
                        ? scope.tokenId == 0 || scope.scopeId != 0
                        : (scope.scopeType != StreamFinalityScopeType.RELEASE
                            && scope.scopeType != StreamFinalityScopeType.SEASON)
                        || scope.tokenId != 0 || scope.scopeId == 0)
        ) {
            revert DiscoveryUnsupportedProfile();
        }
        _pin(b.factory, b.factoryCodeHash);
        _pin(entropyFactory, entropyCodeHash);
        bytes memory raw = Reads.read(
            b.factory, abi.encodeCall(BaseFactory.requireCurrentGraph, (scope)), 736, b.graphGas
        );
        Graph.Graph memory g = abi.decode(raw, (Graph.Graph));
        if (
            keccak256(raw) != keccak256(abi.encode(g))
                || keccak256(abi.encode(g.scope)) != keccak256(abi.encode(scope))
                || g.preparedChildren != 7 || g.inventoryPlan == 0
                || g.graphId
                    != keccak256(
                        abi.encode(
                            Current.GRAPH_DOMAIN,
                            block.chainid,
                            b.factory,
                            b.recipeHash,
                            b.sourceFactoryDependenciesHash,
                            scope,
                            g.inventoryPlan,
                            g.sourceSet,
                            g.sourceSetCodeHash
                        )
                    )
        ) {
            revert DiscoveryUnsupportedProfile();
        }
        _pin(g.sourceSet, g.sourceSetCodeHash);
        _pin(g.children[3], g.codeHashes[3]);
        _pin(g.children[4], g.codeHashes[4]);
        p = Profiles.Profile(
            Definitions.PROFILE_HASH,
            g.children[4],
            g.codeHashes[4],
            g.children[3],
            g.codeHashes[3],
            entropyFactory,
            entropyCodeHash,
            b.configurationHash
        );
    }

    function _word(address target, bytes memory input, uint256 cap) private view returns (bytes32) {
        return abi.decode(Reads.read(target, input, 32, cap), (bytes32));
    }

    function _pin(address target, bytes32 hash) private view {
        if (hash == 0 || target.code.length == 0 || target.codehash != hash) {
            revert DiscoveryDependency(target);
        }
    }

    function _supports(address target, bytes4 id, uint256 cap) private view {
        if (
            _word(
                        target,
                        abi.encodeCall(IERC165.supportsInterface, (type(IERC165).interfaceId)),
                        cap
                    ) != bytes32(uint256(1))
                || _word(target, abi.encodeCall(IERC165.supportsInterface, (id)), cap)
                    != bytes32(uint256(1))
                || _word(
                        target, abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))), cap
                    ) != 0
        ) {
            revert DiscoveryConfiguration(target);
        }
    }
}
