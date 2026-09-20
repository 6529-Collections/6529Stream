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
    IStreamScopedPreservationPolicyPublicationFactoryV1 as BaseFactory
} from "../../interfaces/stream/finality/IStreamScopedPreservationPolicyPublicationFactoryV1.sol";
import {
    IStreamCurrentAuthorityScopedPreservationPolicyPublicationFactoryV1 as I
} from "../../interfaces/stream/finality/IStreamCurrentAuthorityScopedPreservationPolicyPublicationFactoryV1.sol";
import {
    StreamScopedPreservationPolicyPublicationGraphTypesV1 as T
} from "../../interfaces/stream/finality/StreamScopedPreservationPolicyPublicationGraphTypesV1.sol";
import {
    StreamFinalityScope
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import {
    StreamScopedPreservationPolicyPublicationRecipeV1 as Recipe
} from "./StreamScopedPreservationPolicyPublicationRecipeV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyPublicationGraphReadsV1 as Reads
} from "./StreamCurrentAuthorityScopedPreservationPolicyPublicationGraphReadsV1.sol";
import {
    StreamScopedPreservationPolicyPublicationReadinessDeploymentV1 as Readiness
} from "./StreamScopedPreservationPolicyPublicationReadinessDeploymentV1.sol";
import {
    StreamScopedPreservationPolicyPublicationCheckpointDeploymentV1 as Checkpoint
} from "./StreamScopedPreservationPolicyPublicationCheckpointDeploymentV1.sol";
import {
    StreamScopedPreservationPolicyPublicationOutputDeploymentV1 as Output
} from "./StreamScopedPreservationPolicyPublicationOutputDeploymentV1.sol";
import {
    StreamScopedPreservationPolicyPublicationSnapshotDeploymentV1 as Snapshot
} from "./StreamScopedPreservationPolicyPublicationSnapshotDeploymentV1.sol";
import {
    StreamScopedPreservationPolicyPublicationReferenceDeploymentV1 as Reference
} from "./StreamScopedPreservationPolicyPublicationReferenceDeploymentV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyPublicationInventoryDeploymentV1 as Inventory
} from "./StreamCurrentAuthorityScopedPreservationPolicyPublicationInventoryDeploymentV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyPublicationBundleDeploymentV1 as Bundle
} from "./StreamCurrentAuthorityScopedPreservationPolicyPublicationBundleDeploymentV1.sol";

/// @notice Append-only genuine per-plan children from one constructor-fixed recipe.
/// @dev Can precede the Registry without a minted scope. Preparation grants no publication,
/// Artist, archival or finality authority. The fixed resolver is required at every operative read.
contract StreamCurrentAuthorityScopedPreservationPolicyPublicationFactoryV1 is I {
    address public immutable override core;
    address public immutable override metadataHost;
    address public immutable override entropySourceFactory;
    bytes32 public immutable override recipeHash;
    bytes32 public immutable override sourceFactoryDependenciesHash;
    T.Recipe private _recipe;
    O.Dependencies private _origin;
    D.Dependencies private _authority;
    mapping(bytes32 => T.Graph) private _graphs;
    bool private _entered;

    constructor(T.Recipe memory r, O.Dependencies memory origin, D.Dependencies memory authority) {
        Recipe.validate(r);
        sourceFactoryDependenciesHash = Reads.bindings(r, origin, authority, false);
        _recipe = r;
        _origin = origin;
        _authority = authority;
        core = r.inventory.targets[0];
        metadataHost = r.inventory.targets[1];
        entropySourceFactory = r.targets[2];
        recipeHash = Domains.recipeHash(block.chainid, r, origin, authority);
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IERC165).interfaceId || id == type(BaseFactory).interfaceId
            || id == type(I).interfaceId;
    }

    function scopedPreservationPolicyPublicationFactoryProfile()
        external
        pure
        override
        returns (bytes32)
    {
        return Domains.FACTORY_PROFILE;
    }

    function recipe() external view override returns (T.Recipe memory) {
        return _recipe;
    }

    function originDependencies() external view override returns (O.Dependencies memory) {
        return _origin;
    }

    function authorityDependencies() external view override returns (D.Dependencies memory) {
        return _authority;
    }

    function graphForPlan(bytes32 plan) external view override returns (T.Graph memory) {
        return _graphs[plan];
    }

    function prepareGraph(StreamFinalityScope calldata scope, uint8 maximumChildren)
        external
        override
        returns (T.Graph memory)
    {
        if (_entered || maximumChildren == 0 || maximumChildren > 7) {
            revert T.PublicationRecipeInvalid();
        }
        _entered = true;
        T.Recipe memory r = _recipe;
        T.Graph memory current = _current(r, scope);
        T.Graph storage saved = _graphs[current.inventoryPlan];
        if (saved.graphId == 0) {
            _graphs[current.inventoryPlan] = current;
        } else {
            _same(saved, current);
        }
        Reads.children(r, saved, _origin, _authority);
        for (uint8 n; n < maximumChildren && saved.preparedChildren < 7; ++n) {
            uint8 index = saved.preparedChildren;
            address child = _deploy(r, saved, index);
            if (child.code.length == 0) revert T.PublicationGraphDependency(child);
            saved.children[index] = child;
            saved.codeHashes[index] = child.codehash;
            saved.preparedChildren = index + 1;
            emit ScopedPolicyPublicationChildPrepared(
                1, saved.graphId, saved.inventoryPlan, index, child, child.codehash
            );
        }
        // Constructors cannot make an obsolete source plan eligible during the same transaction.
        _same(saved, _current(r, scope));
        Reads.children(r, saved, _origin, _authority);
        _entered = false;
        return saved;
    }

    function requireCurrentGraph(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (T.Graph memory g)
    {
        T.Recipe memory r = _recipe;
        T.Graph memory current = _current(r, scope);
        g = _graphs[current.inventoryPlan];
        _same(g, current);
        if (g.preparedChildren != 7) revert T.PublicationGraphIncomplete(current.graphId);
        Reads.children(r, g, _origin, _authority);
    }

    function _current(T.Recipe memory r, StreamFinalityScope memory scope)
        private
        view
        returns (T.Graph memory g)
    {
        g = Reads.current(r, _origin, _authority, sourceFactoryDependenciesHash, scope);
        g.graphId = keccak256(
            abi.encode(
                Domains.GRAPH_DOMAIN,
                block.chainid,
                address(this),
                recipeHash,
                sourceFactoryDependenciesHash,
                scope,
                g.inventoryPlan,
                g.sourceSet,
                g.sourceSetCodeHash
            )
        );
    }

    function _same(T.Graph memory saved, T.Graph memory current) private pure {
        if (
            saved.graphId != current.graphId || saved.inventoryPlan != current.inventoryPlan
                || saved.sourceSet != current.sourceSet
                || saved.sourceSetCodeHash != current.sourceSetCodeHash
                || keccak256(abi.encode(saved.scope)) != keccak256(abi.encode(current.scope))
        ) revert T.PublicationGraphChanged(current.graphId);
    }

    function _deploy(T.Recipe memory r, T.Graph memory g, uint8 index) private returns (address) {
        if (index == 0) return Readiness.deploy(r, g);
        if (index == 1) return Checkpoint.deploy(r, g);
        if (index == 2) return Output.deploy(r, g);
        if (index == 3) return Snapshot.deploy(r, g);
        if (index == 4) return Reference.deploy(r, g);
        if (index == 5) return Inventory.deploy(r, g, _origin, _authority);
        if (index == 6) return Bundle.deploy(r, g, _origin, _authority);
        revert T.PublicationRecipeInvalid();
    }
}
