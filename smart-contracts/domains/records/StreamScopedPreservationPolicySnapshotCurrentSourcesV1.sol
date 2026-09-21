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
    StreamScopedPreservationPolicySnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    IStreamFinalityScopeMembership as Membership
} from "../../interfaces/stream/finality/IStreamFinalityScopeMembership.sol";
import {
    IStreamStaticSelectionCheckpoint as Selection
} from "../../interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as Content
} from "../../interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    IStreamPreservationPolicyOutputManifestV1 as Outputs
} from "../../interfaces/stream/finality/IStreamPreservationPolicyOutputManifestV1.sol";
import { StreamMetadataSubjects } from "../metadata/StreamMetadataSubjects.sol";
import {
    StreamFinalityRouterEvidence as Reads
} from "../finality/StreamFinalityRouterEvidence.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as Entropy
} from "../../interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    StreamFinalityCoordinatorPolicyV2
} from "../../interfaces/stream/finality/StreamFinalityCoordinatorPolicyTypesV2.sol";
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
    StreamScopedPreservationPolicySnapshotSourceBindingsV1 as SourceBindings
} from "./StreamScopedPreservationPolicySnapshotSourceBindingsV1.sol";

/// @notice Single fixed current-source entry point; preserves read order and returns the complete typed source.
library StreamScopedPreservationPolicySnapshotCurrentSourcesV1 {
    function current(S.Dependencies memory d, S.Publication memory p, bytes32 family)
        public
        view
        returns (S.Source memory f)
    {
        SourceBindings.bindings(d, family);
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
            608,
            d.sourceGas
        );
        f.outputs = abi.decode(raw, (Outputs.Manifest));
        _canonical(raw, abi.encode(f.outputs));
        if (
            p.outputManifestRecord == 0 || f.outputs.artistId != f.artist.artistId
                || keccak256(abi.encode(f.outputs.scope)) != keccak256(abi.encode(p.scope))
                || f.outputs.tokenCount != f.membership.tokenCount || f.outputs.contentRoot == 0
                || f.outputs.outputRoot == 0 || f.outputs.manifestHash == 0
                || f.outputs.checkpointStateHash == 0 || f.outputs.metadataRouter != d.targets[4]
                || f.outputs.preservationProfile != family
        ) revert S.InvalidScopedPolicySnapshot();
        raw = _read(
            d, 7, abi.encodeCall(Content.checkpoint, (f.outputs.checkpointHash)), 448, d.readGas
        );
        f.content = abi.decode(raw, (Content.Plan));
        _canonical(raw, abi.encode(f.content));
        if (
            keccak256(raw) != f.outputs.checkpointStateHash
                || f.content.tokenCount != f.membership.tokenCount
                || f.content.nextIndex != f.content.tokenCount
                || f.content.contentRoot != f.outputs.contentRoot
                || f.content.outputRoot != f.outputs.outputRoot
                || f.content.preservationProfile != f.outputs.preservationProfile
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
        (f.sourceFactory, f.sourceFactoryCodeHash, f.factoryDependenciesHash) =
            SourceBindings.factory(d);
        _factorySelection(d, p, f.sourceFactory);
        _entropy(d, p, f);
    }

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
}
