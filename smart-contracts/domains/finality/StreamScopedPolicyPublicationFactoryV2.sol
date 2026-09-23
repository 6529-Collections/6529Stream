// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamScopedPolicyPublicationFactoryV2 as I
} from "../../interfaces/stream/finality/IStreamScopedPolicyPublicationFactoryV2.sol";
import {
    StreamScopedPolicyPublicationGraphTypesV2 as T
} from "../../interfaces/stream/finality/StreamScopedPolicyPublicationGraphTypesV2.sol";
import {
    StreamFinalityScope
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import {
    StreamScopedPolicyPublicationRecipeV2 as Recipe
} from "./StreamScopedPolicyPublicationRecipeV2.sol";
import {
    StreamScopedPolicyPublicationGraphReadsV2 as Reads
} from "./StreamScopedPolicyPublicationGraphReadsV2.sol";
import {
    StreamScopedPolicyPublicationReadinessDeploymentV2 as Readiness
} from "./StreamScopedPolicyPublicationReadinessDeploymentV2.sol";
import {
    StreamScopedPolicyPublicationCheckpointDeploymentV2 as Checkpoint
} from "./StreamScopedPolicyPublicationCheckpointDeploymentV2.sol";
import {
    StreamScopedPolicyPublicationOutputDeploymentV2 as Output
} from "./StreamScopedPolicyPublicationOutputDeploymentV2.sol";
import {
    StreamScopedPolicyPublicationSnapshotDeploymentV2 as Snapshot
} from "./StreamScopedPolicyPublicationSnapshotDeploymentV2.sol";
import {
    StreamScopedPolicyPublicationReferenceDeploymentV2 as Reference
} from "./StreamScopedPolicyPublicationReferenceDeploymentV2.sol";
import {
    StreamScopedPolicyPublicationInventoryDeploymentV2 as Inventory
} from "./StreamScopedPolicyPublicationInventoryDeploymentV2.sol";
import {
    StreamScopedPolicyPublicationBundleDeploymentV2 as Bundle
} from "./StreamScopedPolicyPublicationBundleDeploymentV2.sol";

/// @notice Append-only genuine per-plan children from one constructor-fixed recipe.
/// @dev Can precede the Registry without a minted scope. Preparation grants no publication,
/// Artist, archival or finality authority. No mutable host lookup or caller implementation exists.
contract StreamScopedPolicyPublicationFactoryV2 is I {
    address public immutable override core;
    address public immutable override metadataHost;
    address public immutable override entropySourceFactory;
    bytes32 public immutable override recipeHash;
    bytes32 public immutable override sourceFactoryDependenciesHash;
    T.Recipe private _recipe;
    mapping(bytes32 => T.Graph) private _graphs;
    bool private _entered;

    constructor(T.Recipe memory r) {
        Recipe.validate(r);
        sourceFactoryDependenciesHash = Reads.bindings(r, false);
        _recipe = r;
        core = r.inventory.targets[0];
        metadataHost = r.inventory.targets[1];
        entropySourceFactory = r.targets[2];
        recipeHash = keccak256(abi.encode(T.PROFILE, block.chainid, r));
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IERC165).interfaceId || id == type(I).interfaceId;
    }

    function scopedPolicyPublicationFactoryProfile() external pure override returns (bytes32) {
        return T.PROFILE;
    }

    function recipe() external view override returns (T.Recipe memory) {
        return _recipe;
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
        Reads.children(r, saved);
        for (uint8 n; n < maximumChildren && saved.preparedChildren < 7; ++n) {
            uint8 index = saved.preparedChildren;
            address child = _deploy(r, saved, index);
            if (child.code.length == 0) revert T.PublicationGraphDependency(child);
            saved.children[index] = child;
            saved.codeHashes[index] = child.codehash;
            saved.preparedChildren = index + 1;
            emit ScopedPolicyPublicationChildPrepared(
                2, saved.graphId, saved.inventoryPlan, index, child, child.codehash
            );
        }
        // Constructors cannot make an obsolete source plan eligible during the same transaction.
        _same(saved, _current(r, scope));
        Reads.children(r, saved);
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
        Reads.children(r, g);
    }

    function _current(T.Recipe memory r, StreamFinalityScope memory scope)
        private
        view
        returns (T.Graph memory g)
    {
        g = Reads.current(r, sourceFactoryDependenciesHash, scope);
        g.graphId = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_POLICY_PUBLICATION_GRAPH_V2"),
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
        if (index == 5) return Inventory.deploy(r, g);
        if (index == 6) return Bundle.deploy(r, g);
        revert T.PublicationRecipeInvalid();
    }
}
