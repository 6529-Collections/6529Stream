// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyPublicationGraphTypesV1 as T
} from "../../interfaces/stream/finality/StreamPreservationPolicyPublicationGraphTypesV1.sol";
import {
    IStreamFinalityEntropyPolicySourceFactoryV2 as Factory
} from "../../interfaces/stream/finality/IStreamFinalityEntropyPolicySourceFactoryV2.sol";
import {
    IStreamFinalityEntropySourceFactory as FactoryBase
} from "../../interfaces/stream/finality/IStreamFinalityEntropySourceFactory.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as Entropy
} from "../../interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    IStreamFinalityCurrentEntropyRoute,
    StreamFinalityCurrentComponentRoute
} from "../../interfaces/stream/finality/IStreamFinalityCurrentComponentRoutes.sol";
import {
    IStreamArtworkFinalityComponent
} from "../../interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType,
    StreamFinalityDomains
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as Policies
} from "./StreamFinalityCoordinatorPolicyReadsV2.sol";
import { StreamFinalityRouterEvidence as Reads } from "./StreamFinalityRouterEvidence.sol";
import {
    StreamPreservationPolicyPublicationRecipeV1 as Recipe
} from "./StreamPreservationPolicyPublicationRecipeV1.sol";
import {
    StreamPreservationPolicySnapshotTypesV1 as Snapshot
} from "../../interfaces/stream/metadata/StreamPreservationPolicySnapshotTypesV1.sol";
import {
    IStreamPreservationPolicySnapshotPublicationV1 as Snap
} from "../../interfaces/stream/metadata/IStreamPreservationPolicySnapshotPublicationV1.sol";
import {
    StreamPreservationPolicyReferenceTypesV1 as Reference
} from "../../interfaces/stream/preservation/StreamPreservationPolicyReferenceTypesV1.sol";
import {
    IStreamPreservationPolicyReferencePublicationV1 as Ref
} from "../../interfaces/stream/preservation/IStreamPreservationPolicyReferencePublicationV1.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import { StreamMetadataRecoveryRoutes } from "../metadata/StreamMetadataRecoveryRoutes.sol";
import { IStreamMetadataRouter } from "../../interfaces/stream/metadata/IStreamMetadataRouter.sol";
import {
    IStreamCollectionMetadataV1
} from "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";

/// @notice Genuine immutable deployment graph checks, deliberately independent of publications.
library StreamPreservationPolicyPublicationGraphReadsV1 {
    function bindings(T.Recipe memory r, bool operative)
        public
        view
        returns (bytes32 dependenciesHash)
    {
        if (r.inventory.chainId != block.chainid) revert T.PublicationRecipeInvalid();
        for (uint256 i; i < 4; ++i) {
            _pin(r.targets[i], r.codeHashes[i]);
        }
        for (uint256 i; i < 12; ++i) {
            if (i != 5 && i != 6 && (operative || i < 5)) {
                _pin(r.inventory.targets[i], r.inventory.codeHashes[i]);
            }
        }
        if (operative) {
            for (uint256 i; i < 5; ++i) {
                _pin(r.inventory.artistTargets[i], r.inventory.artistCodeHashes[i]);
            }
            _pin(r.inventory.artistContentOwner, r.inventory.artistContentOwnerCodeHash);
            StreamMetadataRecoveryRoutes.requireCurrentHost(
                r.inventory.targets[0],
                keccak256("COLLECTION_METADATA"),
                r.inventory.targets[1],
                keccak256("COLLECTION_METADATA"),
                type(IStreamCollectionMetadataV1).interfaceId
            );
            StreamMetadataRecoveryRoutes.requireCurrentHost(
                r.inventory.targets[0],
                keccak256("METADATA_ROUTER"),
                r.inventory.targets[4],
                keccak256("METADATA_ROUTER"),
                type(IStreamMetadataRouter).interfaceId
            );
        }
        address factory = r.targets[2];
        uint256 gasLimit = r.inventory.readGas;
        _address(r.inventory.targets[1], "core()", r.inventory.targets[0], gasLimit);
        _address(r.inventory.targets[1], "schemaRegistry()", r.inventory.targets[2], gasLimit);
        _address(r.inventory.targets[1], "chunkStore()", r.inventory.targets[3], gasLimit);
        _address(r.inventory.targets[1], "governanceAuthority()", r.targets[3], gasLimit);
        if (_word(r.inventory.targets[1], "executorCodeHash()", gasLimit) != r.codeHashes[3]) {
            revert T.PublicationGraphDependency(r.targets[3]);
        }
        _address(r.inventory.targets[4], "core()", r.inventory.targets[0], gasLimit);
        _address(r.targets[0], "core()", r.inventory.targets[0], gasLimit);
        _address(r.targets[0], "metadataHost()", r.inventory.targets[1], gasLimit);
        _address(r.targets[1], "core()", r.inventory.targets[0], gasLimit);
        _address(r.targets[1], "metadataHost()", r.inventory.targets[1], gasLimit);
        _address(r.targets[1], "metadataRouter()", r.inventory.targets[4], gasLimit);
        _address(r.targets[1], "scopeMembership()", r.targets[0], gasLimit);
        if (
            abi.decode(
                        Reads.read(
                            factory,
                            abi.encodeCall(IERC165.supportsInterface, (type(Factory).interfaceId)),
                            32,
                            gasLimit
                        ),
                        (uint256)
                    ) != 1
                || abi.decode(
                        Reads.read(
                            factory, abi.encodeCall(Factory.policyFactoryProfile, ()), 32, gasLimit
                        ),
                        (bytes32)
                    ) != keccak256("6529STREAM_ENTROPY_POLICY_SOURCE_FACTORY_V2")
        ) revert T.PublicationGraphDependency(factory);
        bytes memory raw =
            Reads.read(factory, abi.encodeCall(Factory.dependencies, ()), 352, gasLimit);
        Policies.Dependencies memory d = abi.decode(raw, (Policies.Dependencies));
        dependenciesHash = keccak256(raw);
        if (
            dependenciesHash != keccak256(abi.encode(d)) || d.chainId != r.inventory.chainId
                || d.targets[0] != r.inventory.targets[0]
                || d.codeHashes[0] != r.inventory.codeHashes[0]
                || d.targets[1] != r.inventory.targets[1]
                || d.codeHashes[1] != r.inventory.codeHashes[1] || d.targets[2] != r.targets[0]
                || d.codeHashes[2] != r.codeHashes[0]
        ) revert T.PublicationGraphDependency(factory);
        _pin(d.targets[3], d.codeHashes[3]);
    }

    function current(T.Recipe memory r, bytes32 dependenciesHash, StreamFinalityScope memory scope)
        public
        view
        returns (T.Graph memory g)
    {
        if (
            scope.scopeType != StreamFinalityScopeType.COLLECTION || scope.collectionId == 0
                || scope.tokenId != 0 || scope.scopeId != 0
        ) revert T.PublicationRecipeInvalid();
        if (bindings(r, true) != dependenciesHash) {
            revert T.PublicationGraphDependency(r.targets[2]);
        }
        address factory = r.targets[2];
        uint256 budget = r.factorySourceGas;
        g.scope = scope;
        g.inventoryPlan = abi.decode(
            Reads.read(
                factory, abi.encodeCall(FactoryBase.currentInventoryPlan, (scope)), 32, budget
            ),
            (bytes32)
        );
        (g.sourceSet, g.sourceSetCodeHash) = abi.decode(
            Reads.read(
                factory, abi.encodeCall(FactoryBase.sourceSetForPlan, (g.inventoryPlan)), 64, budget
            ),
            (address, bytes32)
        );
        if (g.inventoryPlan == 0) revert T.PublicationRecipeInvalid();
        _pin(g.sourceSet, g.sourceSetCodeHash);
        bytes memory raw = Reads.read(
            factory,
            abi.encodeCall(IStreamFinalityCurrentEntropyRoute.requireCurrentRoute, (scope)),
            128,
            budget
        );
        StreamFinalityCurrentComponentRoute memory route =
            abi.decode(raw, (StreamFinalityCurrentComponentRoute));
        if (
            keccak256(raw) != keccak256(abi.encode(route)) || route.component != g.sourceSet
                || route.codeHash != g.sourceSetCodeHash
                || route.componentType != StreamFinalityDomains.COMPONENT_ENTROPY_COORDINATOR
                || route.interfaceId != type(IStreamArtworkFinalityComponent).interfaceId
                || _word(g.sourceSet, "factory()", budget) != bytes32(uint256(uint160(factory)))
                || _word(g.sourceSet, "inventoryPlan()", budget) != g.inventoryPlan
                || _word(g.sourceSet, "core()", budget)
                    != bytes32(uint256(uint160(r.inventory.targets[0])))
        ) revert T.PublicationGraphDependency(g.sourceSet);
        Reads.read(g.sourceSet, abi.encodeCall(Entropy.requireCurrentSourceSet, ()), 0, budget);
    }

    /// @dev Fixed deployment workers and recorded runtime hashes authenticate the exact creation.
    /// Constructor storage dependencies are rechecked; legitimate monotonic gas raises are allowed.
    function children(T.Recipe memory r, T.Graph memory g) public view {
        if (g.preparedChildren > 7) revert T.PublicationGraphChanged(g.graphId);
        for (uint256 i; i < g.preparedChildren; ++i) {
            _pin(g.children[i], g.codeHashes[i]);
        }
        uint256 budget = r.inventory.readGas;
        // Runtime pins identify exact factory children; their distinct profiles prohibit a
        // selector-compatible old full/live-output interpretation at every current graph read.
        if (
            g.preparedChildren > 1
                && _word(g.children[1], "preservationPolicyProfile()", budget)
                    != keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_V1")
        ) revert T.PublicationGraphChanged(g.graphId);
        if (
            g.preparedChildren > 2
                && _word(g.children[2], "outputProfile()", budget)
                    != keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_V1")
        ) revert T.PublicationGraphChanged(g.graphId);
        if (
            g.preparedChildren > 3
                && _word(g.children[3], "preservationPolicySnapshotProfile()", budget)
                    != keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_V1")
        ) revert T.PublicationGraphChanged(g.graphId);
        if (
            g.preparedChildren > 4
                && _word(g.children[4], "preservationPolicyReferenceProfile()", budget)
                    != keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_V1")
        ) revert T.PublicationGraphChanged(g.graphId);
        if (
            g.preparedChildren > 5
                && _word(g.children[5], "preservationPolicyInventoryProfile()", budget)
                    != keccak256("6529STREAM_PRESERVATION_POLICY_COLLECTION_RENDER_CRITICAL_V1")
        ) revert T.PublicationGraphChanged(g.graphId);
        if (g.preparedChildren > 3) {
            Snapshot.Dependencies memory expected = Recipe.snapshot(r, g);
            bytes memory raw =
                Reads.read(g.children[3], abi.encodeCall(Snap.dependencies, ()), 832, budget);
            Snapshot.Dependencies memory actual = abi.decode(raw, (Snapshot.Dependencies));
            if (
                keccak256(raw) != keccak256(abi.encode(actual)) || actual.readGas < expected.readGas
                    || actual.sourceGas < expected.sourceGas
                    || actual.inventoryGas < expected.inventoryGas
            ) revert T.PublicationGraphChanged(g.graphId);
            actual.readGas = expected.readGas;
            actual.sourceGas = expected.sourceGas;
            actual.inventoryGas = expected.inventoryGas;
            if (keccak256(abi.encode(actual)) != keccak256(abi.encode(expected))) {
                revert T.PublicationGraphChanged(g.graphId);
            }
        }
        if (g.preparedChildren > 4) {
            Reference.Dependencies memory expected = Recipe.referenceDependencies(r, g);
            bytes memory raw =
                Reads.read(g.children[4], abi.encodeCall(Ref.dependencies, ()), 608, budget);
            Reference.Dependencies memory actual = abi.decode(raw, (Reference.Dependencies));
            if (
                keccak256(raw) != keccak256(abi.encode(actual)) || actual.readGas < expected.readGas
                    || actual.sourceGas < expected.sourceGas
                    || actual.snapshotGas < expected.snapshotGas
                    || actual.archiveGas < expected.archiveGas
            ) revert T.PublicationGraphChanged(g.graphId);
            actual.readGas = expected.readGas;
            actual.sourceGas = expected.sourceGas;
            actual.snapshotGas = expected.snapshotGas;
            actual.archiveGas = expected.archiveGas;
            if (keccak256(abi.encode(actual)) != keccak256(abi.encode(expected))) {
                revert T.PublicationGraphChanged(g.graphId);
            }
        }
        if (
            g.preparedChildren > 5
                && _word(g.children[5], "dependencyHash()", budget)
                    != keccak256(abi.encode(Recipe.inventory(r, g)))
        ) revert T.PublicationGraphChanged(g.graphId);
        if (
            g.preparedChildren > 6
                && _word(g.children[6], "dependencyHash()", budget)
                    != keccak256(abi.encode(Recipe.bundle(r, g)))
        ) revert T.PublicationGraphChanged(g.graphId);
    }

    function _word(address target, string memory selector, uint256 budget)
        private
        view
        returns (bytes32)
    {
        return abi.decode(
            Reads.read(target, abi.encodeWithSignature(selector), 32, budget), (bytes32)
        );
    }

    function _pin(address target, bytes32 codeHash) private view {
        if (target.code.length == 0 || codeHash == 0 || target.codehash != codeHash) {
            revert T.PublicationGraphDependency(target);
        }
    }

    function _address(address target, string memory selector, address expected, uint256 budget)
        private
        view
    {
        if (_word(target, selector, budget) != bytes32(uint256(uint160(expected)))) {
            revert T.PublicationGraphDependency(target);
        }
    }
}
