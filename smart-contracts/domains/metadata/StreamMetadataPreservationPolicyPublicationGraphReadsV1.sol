// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamCurrentAuthorityPreservationPolicyPublicationFactoryV1 as CurrentFactory
} from "../../interfaces/stream/finality/IStreamCurrentAuthorityPreservationPolicyPublicationFactoryV1.sol";
import {
    StreamCurrentAuthorityPreservationPolicyPublicationTypesV1 as Current
} from "../../interfaces/stream/finality/StreamCurrentAuthorityPreservationPolicyPublicationTypesV1.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../../interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";

import {
    IStreamPreservationPolicyPublicationGraphBindingV1 as Binding
} from "../../interfaces/stream/finality/IStreamPreservationPolicyPublicationGraphBindingV1.sol";
import {
    IStreamPreservationPolicyPublicationFactoryV1 as Factory
} from "../../interfaces/stream/finality/IStreamPreservationPolicyPublicationFactoryV1.sol";
import {
    StreamPreservationPolicyPublicationGraphTypesV1 as Graph
} from "../../interfaces/stream/finality/StreamPreservationPolicyPublicationGraphTypesV1.sol";
import {
    IStreamFinalityEntropySourceFactory as Sources
} from "../../interfaces/stream/finality/IStreamFinalityEntropySourceFactory.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamFinalityRouterEvidence as Reads
} from "../finality/StreamFinalityRouterEvidence.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";

/// @notice Root-free resolution of explicitly named COLLECTION preservation recipe products.
/// @dev The caller has already authenticated the original provider through actual Finality.
/// No output address, inventory plan or factory is accepted from the publisher. The ordinary
/// root path still independently validates the output, checkpoint, artifact and Artist route.
library StreamMetadataPreservationPolicyPublicationGraphReadsV1 {
    struct Context {
        address provider;
        address core;
        address metadata;
        address router;
        address schemas;
        uint256 collectionId;
        uint256 readGas;
    }

    error PreservationPolicyPublicationGraphUnavailable(address target);

    function output(Context memory c) public view returns (address host, bytes32 codeHash) {
        bytes memory raw = Reads.read(
            c.provider,
            abi.encodeCall(Binding.collectionPreservationPolicyPublicationBinding, ()),
            192,
            c.readGas
        );
        Binding.CollectionFactoryBinding memory b =
            abi.decode(raw, (Binding.CollectionFactoryBinding));
        if (
            keccak256(raw) != keccak256(abi.encode(b)) || b.recipeHash == 0
                || b.sourceFactoryDependenciesHash == 0 || b.configurationHash == 0
                || b.graphGas < 50000 || b.graphGas > type(uint32).max || c.collectionId == 0
        ) revert PreservationPolicyPublicationGraphUnavailable(c.provider);
        _pin(b.factory, b.factoryCodeHash);
        if (
            _word(
                    b.factory,
                    abi.encodeCall(IERC165.supportsInterface, (type(Factory).interfaceId)),
                    c.readGas
                ) != bytes32(uint256(1))
        ) revert PreservationPolicyPublicationGraphUnavailable(b.factory);
        bytes32 profile = _word(
            b.factory,
            abi.encodeCall(Factory.preservationPolicyPublicationFactoryProfile, ()),
            c.readGas
        );
        if (
            (profile != Graph.PROFILE && profile != Current.FACTORY_PROFILE)
                || _word(b.factory, abi.encodeCall(Factory.recipeHash, ()), c.readGas)
                    != b.recipeHash
                || _word(
                        b.factory,
                        abi.encodeCall(Factory.sourceFactoryDependenciesHash, ()),
                        c.readGas
                    ) != b.sourceFactoryDependenciesHash
                || _word(b.factory, abi.encodeCall(Factory.core, ()), c.readGas) != _address(c.core)
                || _word(b.factory, abi.encodeCall(Factory.metadataHost, ()), c.readGas)
                    != _address(c.metadata)
        ) revert PreservationPolicyPublicationGraphUnavailable(b.factory);

        raw = Reads.dynamicRead(b.factory, abi.encodeCall(Factory.recipe, ()), 24576, c.readGas);
        Graph.Recipe memory r = abi.decode(raw, (Graph.Recipe));
        (bytes32 expectedRecipeHash, bytes32 graphDomain) =
            _recipeIdentity(b.factory, profile, r, c.readGas);
        if (
            keccak256(raw) != keccak256(abi.encode(r)) || b.recipeHash != expectedRecipeHash
                || r.inventory.chainId != block.chainid || r.inventory.targets[0] != c.core
                || r.inventory.targets[1] != c.metadata || r.inventory.targets[2] != c.schemas
                || r.inventory.targets[4] != c.router || r.factorySourceGas < 50000
                || r.factorySourceGas > type(uint32).max
        ) revert PreservationPolicyPublicationGraphUnavailable(b.factory);
        for (uint256 i; i < 5; ++i) {
            _pin(r.inventory.targets[i], r.inventory.codeHashes[i]);
        }
        _pin(r.targets[2], r.codeHashes[2]);
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, c.collectionId, 0, 0);
        raw = Reads.read(
            b.factory, abi.encodeCall(Factory.requireCurrentGraph, (scope)), 736, b.graphGas
        );
        Graph.Graph memory g = abi.decode(raw, (Graph.Graph));
        if (
            keccak256(raw) != keccak256(abi.encode(g)) || g.preparedChildren != 7
                || keccak256(abi.encode(g.scope)) != keccak256(abi.encode(scope))
                || g.inventoryPlan == 0
                || g.graphId
                    != keccak256(
                        abi.encode(
                            graphDomain,
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
                || _word(
                        r.targets[2],
                        abi.encodeCall(Sources.currentInventoryPlan, (scope)),
                        r.factorySourceGas
                    ) != g.inventoryPlan
        ) revert PreservationPolicyPublicationGraphUnavailable(b.factory);
        raw = Reads.read(
            r.targets[2],
            abi.encodeCall(Sources.sourceSetForPlan, (g.inventoryPlan)),
            64,
            r.factorySourceGas
        );
        (address source, bytes32 sourceHash) = abi.decode(raw, (address, bytes32));
        if (
            keccak256(raw) != keccak256(abi.encode(source, sourceHash)) || source != g.sourceSet
                || sourceHash != g.sourceSetCodeHash
        ) revert PreservationPolicyPublicationGraphUnavailable(r.targets[2]);
        _pin(source, sourceHash);
        for (uint256 i; i < 7; ++i) {
            _pin(g.children[i], g.codeHashes[i]);
        }
        return (g.children[2], g.codeHashes[2]);
    }

    /// @dev Supplemental selectors are shared with SCOPED factories. Both the base
    /// COLLECTION capability above and this exact closed profile are required.
    function _recipeIdentity(
        address factory,
        bytes32 profile,
        Graph.Recipe memory recipe_,
        uint256 cap
    ) private view returns (bytes32 recipeHash_, bytes32 graphDomain) {
        if (profile == Graph.PROFILE) {
            return (
                keccak256(abi.encode(Graph.PROFILE, block.chainid, recipe_)),
                keccak256("6529STREAM_PRESERVATION_POLICY_PUBLICATION_GRAPH_V1")
            );
        }
        if (
            profile != Current.FACTORY_PROFILE
                || _word(
                        factory,
                        abi.encodeCall(
                            IERC165.supportsInterface, (type(CurrentFactory).interfaceId)
                        ),
                        cap
                    ) != bytes32(uint256(1))
        ) revert PreservationPolicyPublicationGraphUnavailable(factory);
        bytes memory originBytes =
            Reads.read(factory, abi.encodeCall(CurrentFactory.originDependencies, ()), 128, cap);
        bytes memory authorityBytes =
            Reads.read(factory, abi.encodeCall(CurrentFactory.authorityDependencies, ()), 96, cap);
        O.Dependencies memory origin = abi.decode(originBytes, (O.Dependencies));
        D.Dependencies memory authority = abi.decode(authorityBytes, (D.Dependencies));
        if (
            keccak256(originBytes) != keccak256(abi.encode(origin))
                || keccak256(authorityBytes) != keccak256(abi.encode(authority))
        ) {
            revert PreservationPolicyPublicationGraphUnavailable(factory);
        }
        // The genuine factory's requireCurrentGraph below still authenticates all
        // operative resolver/origin capabilities and exact current children.
        return (Current.recipeHash(block.chainid, recipe_, origin, authority), Current.GRAPH_DOMAIN);
    }

    function _word(address target, bytes memory input, uint256 gasLimit)
        private
        view
        returns (bytes32)
    {
        return abi.decode(Reads.read(target, input, 32, gasLimit), (bytes32));
    }

    function _address(address target) private pure returns (bytes32) {
        return bytes32(uint256(uint160(target)));
    }

    function _pin(address target, bytes32 hash) private view {
        if (target.code.length == 0 || hash == 0 || target.codehash != hash) {
            revert PreservationPolicyPublicationGraphUnavailable(target);
        }
    }
}
