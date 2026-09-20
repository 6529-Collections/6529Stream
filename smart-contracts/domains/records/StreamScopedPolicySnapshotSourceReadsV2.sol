// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamScopeMembershipFacts
} from "../../interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import {
    IStreamMetadataServingFacts
} from "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";

import {
    StreamScopedPolicySnapshotTypesV2 as S
} from "../../interfaces/stream/metadata/StreamScopedPolicySnapshotTypesV2.sol";
import {
    IStreamCollectionMetadataV1 as Metadata
} from "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import { IStreamMetadataRouter } from "../../interfaces/stream/metadata/IStreamMetadataRouter.sol";
import {
    IStreamFinalityScopeMembership as Membership
} from "../../interfaces/stream/finality/IStreamFinalityScopeMembership.sol";
import {
    IStreamStaticSelectionCheckpoint as Selection
} from "../../interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";
import {
    IStreamScopedPolicyContentCheckpointV2 as Content
} from "../../interfaces/stream/finality/IStreamScopedPolicyContentCheckpointV2.sol";
import {
    IStreamScopedPolicyOutputManifestV2 as Outputs
} from "../../interfaces/stream/finality/IStreamScopedPolicyOutputManifestV2.sol";
import { StreamMetadataSubjects } from "../metadata/StreamMetadataSubjects.sol";
import { StreamMetadataRecoveryRoutes } from "../metadata/StreamMetadataRecoveryRoutes.sol";
import {
    StreamFinalityRouterEvidence as Reads
} from "../finality/StreamFinalityRouterEvidence.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as Entropy
} from "../../interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    StreamFinalityCoordinatorPolicyV2
} from "../../interfaces/stream/finality/StreamFinalityCoordinatorPolicyTypesV2.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import {
    IStreamFinalityScopedEntropyPolicySourceFactoryV2 as Factory
} from "../../interfaces/stream/finality/IStreamFinalityScopedEntropyPolicySourceFactoryV2.sol";
import {
    IStreamFinalityEntropySourceFactory as FactoryBase
} from "../../interfaces/stream/finality/IStreamFinalityEntropySourceFactory.sol";
import {
    IStreamFinalityCurrentEntropyRoute,
    StreamFinalityCurrentComponentRoute
} from "../../interfaces/stream/finality/IStreamFinalityCurrentComponentRoutes.sol";
import {
    IStreamArtworkScopedFinalityComponent
} from "../../interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";
import {
    StreamFinalityDomains
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as Policies
} from "../finality/StreamFinalityCoordinatorPolicyReadsV2.sol";

/// @notice Complete scoped-policy output, original factory/source and full frozen policy joins.
/// @dev A complete output-row archive authenticates hashes, not full rendered byte preservation or
/// Artist root-publication authority. The consumer must retain those separate finality obligations.
library StreamScopedPolicySnapshotSourceReadsV2 {
    function scopeSubject(S.Dependencies memory d, StreamFinalityScope memory scope)
        internal
        pure
        returns (bytes32)
    {
        if (
            scope.scopeType != StreamFinalityScopeType.TOKEN
                && scope.scopeType != StreamFinalityScopeType.RELEASE
                && scope.scopeType != StreamFinalityScopeType.SEASON
        ) revert S.InvalidScopedPolicySnapshot();
        return StreamMetadataSubjects.scopeSubject(d.chainId, d.targets[0], scope);
    }

    function bindings(S.Dependencies memory d) public view {
        if (
            d.chainId != block.chainid || d.readGas < 50000 || d.sourceGas < d.readGas
                || d.inventoryGas < d.readGas || d.readGas > type(uint32).max
                || d.inventoryGas > type(uint32).max || d.sourceGas > type(uint32).max
        ) revert S.InvalidScopedPolicySnapshot();
        for (uint256 i; i < d.targets.length; ++i) {
            if (d.targets[i].code.length == 0 || d.targets[i].codehash != d.codeHashes[i]) {
                revert S.ScopedPolicySnapshotDependency(d.targets[i]);
            }
        }
        StreamMetadataRecoveryRoutes.requireCurrentHost(
            d.targets[0],
            keccak256("COLLECTION_METADATA"),
            d.targets[1],
            keccak256("COLLECTION_METADATA"),
            type(Metadata).interfaceId
        );
        StreamMetadataRecoveryRoutes.requireCurrentHost(
            d.targets[0],
            keccak256("METADATA_ROUTER"),
            d.targets[4],
            keccak256("METADATA_ROUTER"),
            type(IStreamMetadataRouter).interfaceId
        );
        _address(d, 1, "core()", 0);
        _address(d, 1, "schemaRegistry()", 2);
        _address(d, 1, "chunkStore()", 3);
        _address(d, 2, "chunkStore()", 3);
        _address(d, 4, "core()", 0);
        _address(d, 5, "core()", 0);
        _address(d, 5, "metadataHost()", 1);
        _address(d, 6, "core()", 0);
        _address(d, 6, "metadataHost()", 1);
        _address(d, 6, "metadataRouter()", 4);
        _address(d, 6, "scopeMembership()", 5);
        _address(d, 7, "core()", 0);
        _address(d, 7, "metadataRouter()", 4);
        _address(d, 7, "selectionCheckpoint()", 6);
        _address(d, 8, "core()", 0);
        _address(d, 8, "contentCheckpoint()", 7);
        _address(d, 8, "artifactCoverage()", 9);
        _address(d, 8, "schemaRegistry()", 2);
        _address(d, 9, "core()", 0);
        _address(d, 9, "schemaRegistry()", 2);
        _address(d, 9, "chunkStore()", 3);
        if (
            _word(d, 1, "coreCodeHash()") != d.codeHashes[0]
                || _word(d, 1, "schemaRegistryCodeHash()") != d.codeHashes[2]
                || _word(d, 1, "chunkStoreCodeHash()") != d.codeHashes[3]
        ) revert S.ScopedPolicySnapshotDependency(d.targets[1]);
        _address(d, 7, "entropySourceSet()", 10);
        _address(d, 10, "core()", 0);
        if (_word(d, 10, "coreCodeHash()") != d.codeHashes[0]) {
            revert S.InvalidScopedPolicySnapshot();
        }
        _supports(d.targets[7], type(Content).interfaceId, d.readGas);
        _supports(d.targets[8], type(Outputs).interfaceId, d.readGas);
        _supports(d.targets[10], type(Entropy).interfaceId, d.readGas);
        if (
            _word(d, 7, "scopedPolicyProfile()")
                    != keccak256("6529STREAM_SCOPED_POLICY_CURRENT_FULL_CONTENT_V2")
                || _word(d, 8, "scopedOutputProfile()")
                    != keccak256("6529STREAM_SCOPED_POLICY_CURRENT_FULL_CONTENT_V2")
                || _word(d, 10, "SOURCE_SET_PROFILE()")
                    != keccak256("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2")
                || _word(d, 7, "entropySourceSetCodeHash()") != d.codeHashes[10]
        ) revert S.InvalidScopedPolicySnapshot();
        _factory(d);
    }

    function current(S.Dependencies memory d, S.Publication memory p)
        public
        view
        returns (S.Source memory f)
    {
        bindings(d);
        f.scope = p.scope;
        bytes32 subject = scopeSubject(d, p.scope);
        bytes memory raw = _read(
            d, 5, abi.encodeCall(Membership.requireScopeMembership, (p.scope)), 256, d.inventoryGas
        );
        f.membership = abi.decode(raw, (StreamScopeMembershipFacts));
        _canonical(raw, abi.encode(f.membership));
        if (
            f.membership.scopeSubject != subject || f.membership.membershipHash == 0
                || f.membership.tokenCount == 0 || f.membership.tokenCount > type(uint64).max
        ) revert S.InvalidScopedPolicySnapshot();
        raw = _read(
            d,
            4,
            abi.encodeCall(IStreamMetadataServingFacts.artistPresentation, (p.scope.collectionId)),
            384,
            d.readGas
        );
        f.artist = abi.decode(raw, (IStreamMetadataServingFacts.ArtistPresentation));
        _canonical(raw, abi.encode(f.artist));
        if (
            !f.artist.locked || f.artist.artistId == 0 || f.artist.snapshotHash == 0
                || f.artist.registry == address(0) || f.artist.registryCodeHash == 0
                || f.artist.bindingGeneration == 0 || f.artist.bindingHash == 0
                || f.artist.identityRecordHash == 0 || f.artist.acceptanceRecordHash == 0
                || f.artist.nominatedArtist == address(0) || f.artist.acceptedAt == 0
                || f.artist.lockedAt == 0
        ) revert S.InvalidScopedPolicySnapshot();
        // This exact immutable producer rerenders the complete original checkpoint and validates
        // current archival coverage. Read its retained checkpoint below; do not rerender twice.
        raw = _read(
            d,
            8,
            abi.encodeCall(
                Outputs.requireCurrentManifest, (p.outputManifestRecord, f.artist.artistId)
            ),
            544,
            d.sourceGas
        );
        f.outputs = abi.decode(raw, (Outputs.Manifest));
        _canonical(raw, abi.encode(f.outputs));
        if (
            p.outputManifestRecord == 0 || f.outputs.artistId != f.artist.artistId
                || keccak256(abi.encode(f.outputs.scope)) != keccak256(abi.encode(p.scope))
                || f.outputs.tokenCount != f.membership.tokenCount || f.outputs.contentRoot == 0
                || f.outputs.outputRoot == 0 || f.outputs.manifestHash == 0
                || f.outputs.checkpointStateHash == 0
        ) revert S.InvalidScopedPolicySnapshot();
        raw = _read(
            d, 7, abi.encodeCall(Content.checkpoint, (f.outputs.checkpointHash)), 416, d.readGas
        );
        f.content = abi.decode(raw, (Content.Plan));
        _canonical(raw, abi.encode(f.content));
        if (
            keccak256(raw) != f.outputs.checkpointStateHash
                || f.content.tokenCount != f.membership.tokenCount
                || f.content.nextIndex != f.content.tokenCount
                || f.content.contentRoot != f.outputs.contentRoot
                || f.content.outputRoot != f.outputs.outputRoot
                || keccak256(abi.encode(f.content.scope)) != keccak256(abi.encode(p.scope))
        ) revert S.InvalidScopedPolicySnapshot();
        raw = _read(
            d, 6, abi.encodeCall(Selection.checkpoint, (f.content.selectionId)), 288, d.readGas
        );
        f.selection = abi.decode(raw, (Selection.Plan));
        _canonical(raw, abi.encode(f.selection));
        if (
            keccak256(raw) != f.content.selectionHash
                || f.selection.tokenCount != f.membership.tokenCount
                || f.selection.nextIndex != f.selection.tokenCount || f.selection.selectionRoot == 0
                || f.selection.membershipHash != f.membership.membershipHash
                || keccak256(abi.encode(f.selection.scope)) != keccak256(abi.encode(p.scope))
        ) revert S.InvalidScopedPolicySnapshot();
        (f.sourceFactory, f.sourceFactoryCodeHash, f.factoryDependenciesHash) = _factory(d);
        _factorySelection(d, p, f.sourceFactory);
        _entropy(d, p, f);
    }

    function sourceHash(S.Dependencies memory d, S.Source memory f)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_SOURCES_V2"),
                d.chainId,
                address(this),
                d.targets,
                d.codeHashes,
                f
            )
        );
    }

    function _entropy(S.Dependencies memory d, S.Publication memory p, S.Source memory f)
        private
        view
    {
        // Exact immutable source set revalidates the complete inventory and every retained policy.
        _read(d, 10, abi.encodeCall(Entropy.requireCurrentSourceSet, ()), 0, d.inventoryGas);
        bytes memory raw = _read(d, 10, abi.encodeCall(Entropy.sourceScope, ()), 128, d.readGas);
        if (keccak256(raw) != keccak256(abi.encode(p.scope))) {
            revert S.InvalidScopedPolicySnapshot();
        }
        raw = _read(d, 10, abi.encodeCall(Entropy.scopeMembershipFacts, ()), 256, d.readGas);
        if (keccak256(raw) != keccak256(abi.encode(f.membership))) {
            revert S.InvalidScopedPolicySnapshot();
        }
        f.entropy.planId = _word(d, 10, "inventoryPlan()");
        f.entropy.inventoryHash = _word(d, 10, "originalInventoryHash()");
        f.entropy.policyChainHash = _word(d, 10, "originalPolicyChainHash()");
        f.entropy.policyCount = uint256(_word(d, 10, "sourceCount()"));
        if (
            p.coordinatorInventoryPlan == 0 || f.entropy.planId != p.coordinatorInventoryPlan
                || f.entropy.inventoryHash == 0 || f.entropy.policyChainHash == 0
                || f.entropy.policyCount == 0 || f.entropy.policyCount > f.membership.tokenCount
                || f.entropy.policyCount > 630 || f.outputs.entropySourceSet != d.targets[10]
                || f.outputs.inventoryHash != f.entropy.inventoryHash
                || f.outputs.policyChainHash != f.entropy.policyChainHash
                || f.content.inventoryHash != f.entropy.inventoryHash
                || f.content.policyChainHash != f.entropy.policyChainHash
        ) revert S.InvalidScopedPolicySnapshot();
        // This finite profile's full payload limit is 524288; fail before allocating unbounded rows.
        f.entropy.policies = new StreamFinalityCoordinatorPolicyV2[](f.entropy.policyCount);
        f.entropy.allFrozen = true;
        for (uint256 i; i < f.entropy.policyCount; ++i) {
            raw = _read(d, 10, abi.encodeCall(Entropy.sourcePolicyAt, (i)), 832, d.readGas);
            StreamFinalityCoordinatorPolicyV2 memory row =
                abi.decode(raw, (StreamFinalityCoordinatorPolicyV2));
            _canonical(raw, abi.encode(row));
            if (
                !row.frozen || row.coordinator == address(0) || row.indexedCodeHash == 0
                    || row.policyHash == 0 || row.componentDataHash == 0
            ) revert S.InvalidScopedPolicySnapshot();
            f.entropy.policies[i] = row;
        }
    }

    function _factory(S.Dependencies memory d)
        private
        view
        returns (address factory, bytes32 runtime, bytes32 dependenciesHash)
    {
        factory = abi.decode(
            _read(d, 10, abi.encodeCall(Entropy.factory, ()), 32, d.readGas), (address)
        );
        if (factory.code.length == 0) revert S.ScopedPolicySnapshotDependency(factory);
        runtime = factory.codehash;
        if (
            _word(d, 7, "sourceFactory()") != bytes32(uint256(uint160(factory)))
                || _word(d, 7, "sourceFactoryCodeHash()") != runtime
        ) revert S.ScopedPolicySnapshotDependency(factory);
        _supports(factory, type(Factory).interfaceId, d.readGas);
        _supports(factory, type(IStreamFinalityCurrentEntropyRoute).interfaceId, d.readGas);
        if (
            abi.decode(
                    Reads.read(
                        factory,
                        abi.encodeCall(Factory.scopedPolicyFactoryProfile, ()),
                        32,
                        d.readGas
                    ),
                    (bytes32)
                ) != keccak256("6529STREAM_SCOPED_ENTROPY_POLICY_SOURCE_FACTORY_V2")
        ) {
            revert S.ScopedPolicySnapshotDependency(factory);
        }
        bytes memory raw =
            Reads.read(factory, abi.encodeCall(Factory.dependencies, ()), 352, d.readGas);
        Policies.Dependencies memory original = abi.decode(raw, (Policies.Dependencies));
        _canonical(raw, abi.encode(original));
        dependenciesHash = keccak256(raw);
        if (
            dependenciesHash != _word(d, 7, "factoryDependenciesHash()")
                || original.chainId != d.chainId || original.targets[0] != d.targets[0]
                || original.codeHashes[0] != d.codeHashes[0] || original.targets[1] != d.targets[1]
                || original.codeHashes[1] != d.codeHashes[1] || original.targets[2] != d.targets[5]
                || original.codeHashes[2] != d.codeHashes[5]
        ) revert S.ScopedPolicySnapshotDependency(factory);
        Policies.validateDependencies(original);
        bytes4[4] memory getters = [
            FactoryBase.core.selector,
            FactoryBase.metadataHost.selector,
            FactoryBase.scopeMembershipHost.selector,
            FactoryBase.coordinatorInventory.selector
        ];
        for (uint256 i; i < getters.length; ++i) {
            if (
                abi.decode(
                        Reads.read(factory, abi.encodeWithSelector(getters[i]), 32, d.readGas),
                        (address)
                    ) != original.targets[i]
            ) revert S.ScopedPolicySnapshotDependency(factory);
        }
    }

    function _factorySelection(S.Dependencies memory d, S.Publication memory p, address factory)
        private
        view
    {
        bytes32 plan = abi.decode(
            Reads.read(
                factory,
                abi.encodeCall(FactoryBase.currentInventoryPlan, (p.scope)),
                32,
                d.inventoryGas
            ),
            (bytes32)
        );
        if (
            plan == 0 || plan != p.coordinatorInventoryPlan
                || plan != _word(d, 10, "inventoryPlan()")
        ) {
            revert S.InvalidScopedPolicySnapshot();
        }
        bytes memory raw = Reads.read(
            factory, abi.encodeCall(FactoryBase.sourceSetForPlan, (plan)), 64, d.readGas
        );
        (address saved, bytes32 runtime) = abi.decode(raw, (address, bytes32));
        _canonical(raw, abi.encode(saved, runtime));
        if (saved != d.targets[10] || runtime != d.codeHashes[10]) {
            revert S.InvalidScopedPolicySnapshot();
        }
        raw = Reads.read(
            factory,
            abi.encodeCall(IStreamFinalityCurrentEntropyRoute.requireCurrentRoute, (p.scope)),
            128,
            d.inventoryGas
        );
        StreamFinalityCurrentComponentRoute memory route =
            abi.decode(raw, (StreamFinalityCurrentComponentRoute));
        _canonical(raw, abi.encode(route));
        if (
            route.componentType != StreamFinalityDomains.COMPONENT_ENTROPY_COORDINATOR
                || route.component != saved || route.codeHash != runtime
                || route.interfaceId != type(IStreamArtworkScopedFinalityComponent).interfaceId
        ) {
            revert S.InvalidScopedPolicySnapshot();
        }
    }

    function _supports(address target, bytes4 capability, uint256 cap) private view {
        bytes memory raw =
            Reads.read(target, abi.encodeCall(IERC165.supportsInterface, (capability)), 32, cap);
        if (keccak256(raw) != keccak256(abi.encode(true))) {
            revert S.ScopedPolicySnapshotDependency(target);
        }
    }

    function _address(S.Dependencies memory d, uint256 at, string memory selector, uint256 expected)
        private
        view
    {
        if (uint256(_word(d, at, selector)) != uint256(uint160(d.targets[expected]))) {
            revert S.ScopedPolicySnapshotDependency(d.targets[at]);
        }
    }

    function _word(S.Dependencies memory d, uint256 at, string memory selector)
        private
        view
        returns (bytes32)
    {
        return abi.decode(_read(d, at, abi.encodeWithSignature(selector), 32, d.readGas), (bytes32));
    }

    function _read(
        S.Dependencies memory d,
        uint256 at,
        bytes memory input,
        uint256 size,
        uint256 cap
    ) private view returns (bytes memory) {
        return Reads.read(d.targets[at], input, size, cap);
    }

    function _canonical(bytes memory raw, bytes memory encoded) private pure {
        if (keccak256(raw) != keccak256(encoded)) revert S.InvalidScopedPolicySnapshot();
    }
}
