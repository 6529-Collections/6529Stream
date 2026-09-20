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
    StreamPreservationPolicySnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamPreservationPolicySnapshotTypesV1.sol";
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
    IStreamPreservationPolicyContentCheckpointV1 as Content
} from "../../interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    IStreamPreservationPolicyOutputManifestV1 as Outputs
} from "../../interfaces/stream/finality/IStreamPreservationPolicyOutputManifestV1.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
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
    IStreamPreservationPolicyContentRootPublicationV1 as PreservationRoot
} from "../../interfaces/stream/metadata/IStreamPreservationPolicyContentRootPublicationV1.sol";
import {
    StreamPreservationPolicyContentRootSchemasV1 as RootSchemas
} from "../finality/StreamPreservationPolicyContentRootSchemasV1.sol";
import {
    StreamPreservationPolicyOutputSchemasV1 as OutputSchemas
} from "../finality/StreamPreservationPolicyOutputSchemasV1.sol";

import {
    StreamPreservationTokenProducerProfilesV1 as ProducerProfiles
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    StreamPreservationPolicyContentRootSchemasV2 as RootSchemasV2
} from "../finality/StreamPreservationPolicyContentRootSchemasV2.sol";
import {
    StreamPreservationPolicyOutputSchemasV2 as OutputSchemasV2
} from "../finality/StreamPreservationPolicyOutputSchemasV2.sol";

/// @notice Complete admitted COLLECTION preservation output, canonical Router root and original-source policy joins.
/// @dev A complete output-row archive authenticates hashes, not full rendered byte preservation or
/// Artist root-publication authority. The consumer must retain those separate finality obligations.
library StreamPreservationPolicySnapshotSourceReadsV1 {
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

    /// @dev Historical entry point remains fixed to the original producer profile.
    function bindings(S.Dependencies memory d) public view {
        bindings(d, ProducerProfiles.ORIGINAL_PROFILE);
    }

    /// @dev Only a fixed caller configuration selects the closed family; no host autodetection.
    function bindings(S.Dependencies memory d, bytes32 family) public view {
        bool v2 = _version2(family);
        if (
            d.chainId != block.chainid || d.readGas < 50000 || d.sourceGas < d.readGas
                || d.inventoryGas < d.readGas || d.readGas > type(uint32).max
                || d.inventoryGas > type(uint32).max || d.sourceGas > type(uint32).max
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
        _supports(d.targets[7], type(Content).interfaceId, d.readGas);
        _supports(d.targets[8], type(Outputs).interfaceId, d.readGas);
        _supports(d.targets[10], type(Entropy).interfaceId, d.readGas);
        if (
            _word(d, 7, "preservationPolicyProfile()")
                    != (v2
                            ? ProducerProfiles.COLLECTION_CHECKPOINT_PROFILE
                            : keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_V1"))
                || _word(d, 8, "outputProfile()")
                    != (v2
                            ? ProducerProfiles.OUTPUT_MANIFEST_PROFILE
                            : keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_V1"))
                || _word(d, 7, "preservationOutputProfile()") != family
                || _word(d, 10, "SOURCE_SET_PROFILE()")
                    != keccak256("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2")
                || _word(d, 7, "entropySourceSetCodeHash()") != d.codeHashes[10]
        ) revert S.InvalidPolicySnapshot();
    }

    function current(S.Dependencies memory d, S.Publication memory p)
        public
        view
        returns (S.Source memory)
    {
        return current(d, p, ProducerProfiles.ORIGINAL_PROFILE);
    }

    function current(S.Dependencies memory d, S.Publication memory p, bytes32 family)
        public
        view
        returns (S.Source memory f)
    {
        bindings(d, family);
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
        ) revert S.InvalidPolicySnapshot();
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
        _root(d, p, f, family);
    }

    function sourceHash(S.Dependencies memory d, S.Source memory f)
        internal
        view
        returns (bytes32)
    {
        return sourceHash(d, f, ProducerProfiles.ORIGINAL_PROFILE);
    }

    function sourceHash(S.Dependencies memory d, S.Source memory f, bytes32 family)
        internal
        view
        returns (bytes32)
    {
        bool v2 = _version2(family);
        return keccak256(
            abi.encode(
                (v2
                        ? keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_SOURCES_V2")
                        : keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_SOURCES_V1")),
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

    function _root(
        S.Dependencies memory d,
        S.Publication memory p,
        S.Source memory f,
        bytes32 family
    ) private view {
        bool v2 = _version2(family);
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
            abi.encodeCall(
                PreservationRoot.preservationPolicyContentRootBinding, (p.contentRootRecord)
            ),
            608,
            d.readGas
        );
        f.rootBinding = abi.decode(raw, (PreservationRoot.Binding));
        _canonical(raw, abi.encode(f.rootBinding));
        PreservationRoot.Binding memory b = f.rootBinding;
        if (
            b.profileId != (v2 ? RootSchemasV2.PROFILE : RootSchemas.PROFILE)
                || b.outputManifest != d.targets[8] || b.outputManifestCodeHash != d.codeHashes[8]
                || b.checkpoint != d.targets[7] || b.checkpointCodeHash != d.codeHashes[7]
                || b.checkpointHash != f.outputs.checkpointHash
                || b.checkpointStateHash != f.outputs.checkpointStateHash
                || b.entropySourceSet != d.targets[10]
                || b.entropySourceSetCodeHash != d.codeHashes[10]
                || b.inventoryHash != f.entropy.inventoryHash
                || b.policyChainHash != f.entropy.policyChainHash
                || b.outputRoot != f.outputs.outputRoot || b.metadataRouter != d.targets[4]
                || b.preservationOutputProfile != f.outputs.preservationProfile
                || b.outputSchemaHash
                    != (v2
                            ? RootSchemasV2.definitionHash(OutputSchemasV2.SCHEMA)
                            : RootSchemas.definitionHash(OutputSchemas.SCHEMA))
                || b.outputCanonicalizationHash
                    != (v2
                            ? RootSchemasV2.definitionHash(OutputSchemasV2.CANON)
                            : RootSchemas.definitionHash(OutputSchemas.CANON))
                || b.leafSchemaHash
                    != (v2
                            ? RootSchemasV2.definitionHash(OutputSchemasV2.LEAF_SCHEMA)
                            : RootSchemas.definitionHash(OutputSchemas.LEAF_SCHEMA))
                || b.rootSchemaHash
                    != (v2
                            ? RootSchemasV2.definitionHash(RootSchemasV2.ROOT_SCHEMA)
                            : RootSchemas.definitionHash(RootSchemas.ROOT_SCHEMA))
                || b.rootCanonicalizationHash
                    != (v2
                            ? RootSchemasV2.definitionHash(RootSchemasV2.ROOT_CANON)
                            : RootSchemas.definitionHash(RootSchemas.ROOT_CANON))
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
                            (v2
                                    ? keccak256(
                                        "6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V2"
                                    )
                                    : keccak256(
                                        "6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V1"
                                    )),
                            d.chainId,
                            d.targets[4],
                            r,
                            b
                        )
                    ) != p.contentRootRecord
        ) revert S.InvalidPolicySnapshot();
    }

    function _version2(bytes32 family) private pure returns (bool) {
        if (family == ProducerProfiles.ORIGINAL_PROFILE) return false;
        if (family == ProducerProfiles.FAMILY_PROFILE) return true;
        revert S.InvalidPolicySnapshot();
    }

    function _supports(address target, bytes4 capability, uint256 cap) private view {
        bytes memory raw =
            Reads.read(target, abi.encodeCall(IERC165.supportsInterface, (capability)), 32, cap);
        if (keccak256(raw) != keccak256(abi.encode(true))) {
            revert S.PolicySnapshotDependency(target);
        }
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
