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
    StreamScopedSnapshotTypes as S
} from "../../interfaces/stream/metadata/StreamScopedSnapshotTypes.sol";
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
    IStreamStaticContentCheckpoint as Content
} from "../../interfaces/stream/finality/IStreamStaticContentCheckpoint.sol";
import {
    IStreamStaticOutputManifest as Outputs
} from "../../interfaces/stream/finality/IStreamStaticOutputManifest.sol";
import { StreamMetadataSubjects } from "../metadata/StreamMetadataSubjects.sol";
import { StreamMetadataRecoveryRoutes } from "../metadata/StreamMetadataRecoveryRoutes.sol";
import {
    StreamFinalityRouterEvidence as Reads
} from "../finality/StreamFinalityRouterEvidence.sol";
import {
    StreamFinalityCoordinatorPolicyReads as Policies
} from "../finality/StreamFinalityCoordinatorPolicyReads.sol";

/// @notice Exact original scoped membership, selected STATIC output and original entropy policy joins.
/// @dev A complete output-row archive authenticates hashes, not full rendered byte preservation or
/// Artist root-publication authority. The consumer must retain those separate finality obligations.
library StreamScopedSnapshotSourceReads {
    function scopeSubject(S.Dependencies memory d, StreamFinalityScope memory scope)
        internal
        pure
        returns (bytes32)
    {
        if (
            scope.scopeType != StreamFinalityScopeType.TOKEN
                && scope.scopeType != StreamFinalityScopeType.RELEASE
                && scope.scopeType != StreamFinalityScopeType.SEASON
        ) revert S.InvalidScopedSnapshot();
        return StreamMetadataSubjects.scopeSubject(d.chainId, d.targets[0], scope);
    }

    function bindings(S.Dependencies memory d) public view {
        if (
            d.chainId != block.chainid || d.readGas < 50000 || d.sourceGas < d.readGas
                || d.inventoryGas < d.readGas || d.readGas > type(uint32).max
                || d.inventoryGas > type(uint32).max
        ) revert S.InvalidScopedSnapshot();
        for (uint256 i; i < d.targets.length; ++i) {
            if (d.targets[i].code.length == 0 || d.targets[i].codehash != d.codeHashes[i]) {
                revert S.ScopedSnapshotDependency(d.targets[i]);
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
        ) revert S.ScopedSnapshotDependency(d.targets[1]);
        Policies.validateDependencies(_policies(d));
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
        ) revert S.InvalidScopedSnapshot();
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
        ) revert S.InvalidScopedSnapshot();
        // This exact immutable producer rerenders the complete original checkpoint and validates
        // current archival coverage. Read its retained checkpoint below; do not rerender twice.
        raw = _read(
            d,
            8,
            abi.encodeCall(
                Outputs.requireCurrentManifest, (p.outputManifestRecord, f.artist.artistId)
            ),
            448,
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
        ) revert S.InvalidScopedSnapshot();
        raw = _read(
            d, 7, abi.encodeCall(Content.checkpoint, (f.outputs.checkpointHash)), 352, d.readGas
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
        ) revert S.InvalidScopedSnapshot();
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
        ) revert S.InvalidScopedSnapshot();
        f.entropy = Policies.requireCurrent(_policies(d), p.scope, p.coordinatorInventoryPlan);
        if (!f.entropy.allFrozen || f.entropy.policyCount == 0) revert S.InvalidScopedSnapshot();
    }

    function sourceHash(S.Dependencies memory d, S.Source memory f)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_STATIC_SNAPSHOT_SOURCES_V1"),
                d.chainId,
                address(this),
                d.targets,
                d.codeHashes,
                f
            )
        );
    }

    function _policies(S.Dependencies memory d)
        private
        pure
        returns (Policies.Dependencies memory p)
    {
        uint256[4] memory at = [uint256(0), 1, 5, 10];
        for (uint256 i; i < at.length; ++i) {
            p.targets[i] = d.targets[at[i]];
            p.codeHashes[i] = d.codeHashes[at[i]];
        }
        p.chainId = d.chainId;
        p.readGas = uint32(d.readGas);
        p.inventoryGas = uint32(d.inventoryGas);
    }

    function _address(S.Dependencies memory d, uint256 at, string memory selector, uint256 expected)
        private
        view
    {
        if (uint256(_word(d, at, selector)) != uint256(uint160(d.targets[expected]))) {
            revert S.ScopedSnapshotDependency(d.targets[at]);
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
        if (keccak256(raw) != keccak256(encoded)) revert S.InvalidScopedSnapshot();
    }
}
