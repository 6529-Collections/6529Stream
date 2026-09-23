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
    StreamPolicySnapshotTypesV2 as S
} from "../../interfaces/stream/metadata/StreamPolicySnapshotTypesV2.sol";
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
    IStreamPolicyContentCheckpointV2 as Content
} from "../../interfaces/stream/finality/IStreamPolicyContentCheckpointV2.sol";
import {
    IStreamPolicyOutputManifestV2 as Outputs
} from "../../interfaces/stream/finality/IStreamPolicyOutputManifestV2.sol";
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
import {
    IStreamContentRootPublication as Root
} from "../../interfaces/stream/metadata/IStreamContentRootPublication.sol";
import {
    IStreamPolicyContentRootPublicationV2 as RootV2
} from "../../interfaces/stream/metadata/IStreamPolicyContentRootPublicationV2.sol";
import {
    StreamPolicyContentRootSchemasV2 as RootSchemas
} from "../finality/StreamPolicyContentRootSchemasV2.sol";
import {
    StreamPolicyOutputSchemasV2 as OutputSchemas
} from "../finality/StreamPolicyOutputSchemasV2.sol";

/// @notice Complete COLLECTION V2 output, canonical Router root and original-source policy joins.
/// @dev A complete output-row archive authenticates hashes, not full rendered byte preservation or
/// Artist root-publication authority. The consumer must retain those separate finality obligations.
library StreamPolicySnapshotSourceReadsV2 {
    function scopeSubject(S.Dependencies memory d, StreamFinalityScope memory scope)
        internal
        pure
        returns (bytes32)
    {
        if (
            scope.scopeType != StreamFinalityScopeType.COLLECTION || scope.collectionId == 0
                || scope.tokenId != 0 || scope.scopeId != 0
        ) revert S.InvalidPolicySnapshot();
        return StreamMetadataSubjects.scopeSubject(d.chainId, d.targets[0], scope);
    }

    function bindings(S.Dependencies memory d) public view {
        if (
            d.chainId != block.chainid || d.readGas < 50000 || d.sourceGas < d.readGas
                || d.inventoryGas < d.readGas || d.readGas > type(uint32).max
                || d.inventoryGas > type(uint32).max
        ) revert S.InvalidPolicySnapshot();
        for (uint256 i; i < d.targets.length; ++i) {
            if (d.targets[i].code.length == 0 || d.targets[i].codehash != d.codeHashes[i]) {
                revert S.PolicySnapshotDependency(d.targets[i]);
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
        ) revert S.PolicySnapshotDependency(d.targets[1]);
        _address(d, 7, "entropySourceSet()", 10);
        _address(d, 10, "core()", 0);
        if (_word(d, 10, "coreCodeHash()") != d.codeHashes[0]) revert S.InvalidPolicySnapshot();
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
        ) revert S.InvalidPolicySnapshot();
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
        ) revert S.InvalidPolicySnapshot();
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
        ) revert S.InvalidPolicySnapshot();
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
        ) revert S.InvalidPolicySnapshot();
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
        ) revert S.InvalidPolicySnapshot();
        _entropy(d, p, f);
        _root(d, p, f);
    }

    function sourceHash(S.Dependencies memory d, S.Source memory f)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_POLICY_SNAPSHOT_SOURCES_V2"),
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
        if (keccak256(raw) != keccak256(abi.encode(p.scope))) revert S.InvalidPolicySnapshot();
        raw = _read(d, 10, abi.encodeCall(Entropy.scopeMembershipFacts, ()), 256, d.readGas);
        if (keccak256(raw) != keccak256(abi.encode(f.membership))) {
            revert S.InvalidPolicySnapshot();
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
        ) revert S.InvalidPolicySnapshot();
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
            ) revert S.InvalidPolicySnapshot();
            f.entropy.policies[i] = row;
        }
    }

    function _root(S.Dependencies memory d, S.Publication memory p, S.Source memory f)
        private
        view
    {
        if (p.contentRootRecord == 0) revert S.InvalidPolicySnapshot();
        bytes memory raw = _read(
            d,
            4,
            abi.encodeCall(Root.collectionContentRootHead, (p.scope.collectionId)),
            32,
            d.readGas
        );
        if (abi.decode(raw, (bytes32)) != p.contentRootRecord) revert S.InvalidPolicySnapshot();
        raw = Reads.dynamicRead(
            d.targets[4],
            abi.encodeCall(Root.contentRootRecord, (p.contentRootRecord)),
            4096,
            d.readGas
        );
        f.root = abi.decode(raw, (Root.Record));
        _canonical(raw, abi.encode(f.root));
        raw = _read(
            d,
            4,
            abi.encodeCall(RootV2.policyContentRootBinding, (p.contentRootRecord)),
            544,
            d.readGas
        );
        f.rootBinding = abi.decode(raw, (RootV2.Binding));
        _canonical(raw, abi.encode(f.rootBinding));
        RootV2.Binding memory b = f.rootBinding;
        if (
            b.profileId != keccak256("6529STREAM_POLICY_CURRENT_FULL_CONTENT_V2")
                || b.outputManifest != d.targets[8] || b.outputManifestCodeHash != d.codeHashes[8]
                || b.checkpoint != d.targets[7] || b.checkpointCodeHash != d.codeHashes[7]
                || b.checkpointHash != f.outputs.checkpointHash
                || b.checkpointStateHash != f.outputs.checkpointStateHash
                || b.entropySourceSet != d.targets[10]
                || b.entropySourceSetCodeHash != d.codeHashes[10]
                || b.inventoryHash != f.entropy.inventoryHash
                || b.policyChainHash != f.entropy.policyChainHash
                || b.outputRoot != f.outputs.outputRoot
                || b.outputSchemaHash != RootSchemas.definitionHash(OutputSchemas.SCHEMA)
                || b.outputCanonicalizationHash != RootSchemas.definitionHash(OutputSchemas.CANON)
                || b.leafSchemaHash != RootSchemas.definitionHash(OutputSchemas.LEAF_SCHEMA)
                || b.rootSchemaHash != RootSchemas.definitionHash(RootSchemas.ROOT_SCHEMA)
                || b.rootCanonicalizationHash != RootSchemas.definitionHash(RootSchemas.ROOT_CANON)
        ) revert S.InvalidPolicySnapshot();
        Root.Record memory r = f.root;
        if (
            r.publication.collectionId != p.scope.collectionId
                || r.publication.verifiedManifestRecordHash != p.outputManifestRecord
                || r.contentRoot != f.outputs.contentRoot || r.leafCount != f.outputs.tokenCount
                || r.manifestHash != f.outputs.manifestHash || r.artistId != f.artist.artistId
                || r.bindingGeneration != f.artist.bindingGeneration
                || r.bindingHash != f.artist.bindingHash || r.publisher == address(0)
                || (r.authorizationClass != 7 && r.authorizationClass != 8) || r.grantRevision == 0
                || r.artistConsent == 0 || r.publishedAt == 0 || r.routeHash == 0
                || keccak256(
                        abi.encode(
                            keccak256("6529STREAM_POLICY_CONTENT_ROOT_RECORD_V2"),
                            d.chainId,
                            d.targets[4],
                            r,
                            b
                        )
                    ) != p.contentRootRecord
        ) revert S.InvalidPolicySnapshot();
    }

    function _address(S.Dependencies memory d, uint256 at, string memory selector, uint256 expected)
        private
        view
    {
        if (uint256(_word(d, at, selector)) != uint256(uint160(d.targets[expected]))) {
            revert S.PolicySnapshotDependency(d.targets[at]);
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
        if (keccak256(raw) != keccak256(encoded)) revert S.InvalidPolicySnapshot();
    }
}
