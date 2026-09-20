// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamViewPreservationSnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamViewPreservationSnapshotTypesV1.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamScopeMembershipFacts
} from "../../interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import {
    StreamViewPreservationCheckpointTypesV1 as C
} from "../../interfaces/stream/finality/StreamViewPreservationCheckpointTypesV1.sol";
import {
    StreamViewPreservationManifestTypesV1 as M
} from "../../interfaces/stream/finality/StreamViewPreservationManifestTypesV1.sol";
import {
    IStreamViewPreservationContentCheckpointV1 as Checkpoint
} from "../../interfaces/stream/finality/IStreamViewPreservationContentCheckpointV1.sol";
import {
    IStreamViewPreservationOutputManifestV1 as Manifest
} from "../../interfaces/stream/finality/IStreamViewPreservationOutputManifestV1.sol";
import {
    StreamViewPreservationCheckpointSourceV1 as Adoption
} from "../finality/StreamViewPreservationCheckpointSourceV1.sol";
import { StreamViewAdoptionReads as Read } from "../metadata/StreamViewAdoptionReads.sol";
import { StreamMetadataRecoveryRoutes } from "../metadata/StreamMetadataRecoveryRoutes.sol";
import { StreamMetadataSubjects } from "../metadata/StreamMetadataSubjects.sol";
import {
    IStreamCollectionMetadataV1 as Metadata
} from "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import { IStreamMetadataRouter } from "../../interfaces/stream/metadata/IStreamMetadataRouter.sol";
import {
    IStreamMetadataServingFacts as Artist
} from "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import {
    IStreamFinalityScopeMembership as Membership
} from "../../interfaces/stream/finality/IStreamFinalityScopeMembership.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as Set
} from "../../interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    StreamFinalityCoordinatorPolicyV2 as Policy
} from "../../interfaces/stream/finality/StreamFinalityCoordinatorPolicyTypesV2.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";

/// @notice Complete current preservation source with no dependency on a future root or finality result.
library StreamViewPreservationSnapshotSourceReadsV1 {
    function scopeSubject(S.Dependencies memory d, StreamFinalityScope memory scope)
        internal
        pure
        returns (bytes32)
    {
        if (scope.scopeType != StreamFinalityScopeType.VIEW) {
            revert S.InvalidViewPreservationSnapshot();
        }
        return StreamMetadataSubjects.scopeSubject(d.chainId, d.targets[0], scope);
    }

    function bindings(S.Dependencies memory d) public view {
        if (
            d.chainId != block.chainid || d.readGas < 50000 || d.sourceGas < d.readGas
                || d.inventoryGas < d.readGas || d.readGas > type(uint32).max
                || d.sourceGas > 16777216 || d.inventoryGas > 16777216
        ) {
            revert S.InvalidViewPreservationSnapshot();
        }
        for (uint256 i; i < d.targets.length; ++i) {
            Read.pin(d.targets[i], d.codeHashes[i]);
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
        _address(d, 1, "governanceAuthority()", 9);
        _address(d, 2, "chunkStore()", 3);
        _address(d, 4, "core()", 0);
        _address(d, 4, "governanceAuthority()", 9);
        _address(d, 5, "core()", 0);
        _address(d, 5, "metadataHost()", 1);
        _address(d, 8, "core()", 0);
        _address(d, 8, "schemaRegistry()", 2);
        _address(d, 8, "chunkStore()", 3);
        if (
            _word(d, 1, "coreCodeHash()") != d.codeHashes[0]
                || _word(d, 1, "schemaRegistryCodeHash()") != d.codeHashes[2]
                || _word(d, 1, "chunkStoreCodeHash()") != d.codeHashes[3]
                || _word(d, 1, "executorCodeHash()") != d.codeHashes[9]
        ) {
            revert S.ViewPreservationSnapshotDependency(d.targets[1]);
        }
        _checkpointConfiguration(d);
        if (
            Read.word(
                        d.targets[7],
                        abi.encodeCall(IERC165.supportsInterface, (type(Manifest).interfaceId)),
                        d.readGas
                    ) != 1 || _word(d, 7, "outputProfile()") != M.PROFILE
        ) revert S.InvalidViewPreservationSnapshot();
        bytes memory raw =
            Read.read(d.targets[7], abi.encodeCall(Manifest.configuration, ()), 384, d.readGas);
        M.Configuration memory m = abi.decode(raw, (M.Configuration));
        _canonical(raw, abi.encode(m));
        if (
            m.core != d.targets[0] || m.coreCodeHash != d.codeHashes[0]
                || m.checkpoint != d.targets[6] || m.checkpointCodeHash != d.codeHashes[6]
                || m.checkpointConfigurationHash != _word(d, 6, "configurationHash()")
                || m.coverage != d.targets[8] || m.coverageCodeHash != d.codeHashes[8]
                || m.schemas != d.targets[2] || m.schemasCodeHash != d.codeHashes[2]
                || m.chainId != d.chainId
        ) {
            revert S.InvalidViewPreservationSnapshot();
        }
    }

    function current(S.Dependencies memory d, S.Publication memory p)
        public
        view
        returns (S.Source memory f)
    {
        bindings(d);
        f.scope = p.scope;
        bytes32 subject = scopeSubject(d, p.scope);
        bytes memory raw = Read.read(
            d.targets[5],
            abi.encodeCall(Membership.requireScopeMembership, (p.scope)),
            256,
            d.inventoryGas
        );
        f.membership = abi.decode(raw, (StreamScopeMembershipFacts));
        _canonical(raw, abi.encode(f.membership));
        if (
            f.membership.scopeSubject != subject || f.membership.membershipHash == 0
                || f.membership.tokenCount == 0 || f.membership.tokenCount > C.MAX_ROWS
        ) revert S.InvalidViewPreservationSnapshot();
        raw = Read.read(
            d.targets[4],
            abi.encodeCall(Artist.artistPresentation, (p.scope.collectionId)),
            384,
            d.readGas
        );
        f.artist = abi.decode(raw, (Artist.ArtistPresentation));
        _canonical(raw, abi.encode(f.artist));
        if (
            !f.artist.locked || f.artist.artistId == 0 || f.artist.snapshotHash == 0
                || f.artist.registry == address(0) || f.artist.registryCodeHash == 0
                || f.artist.bindingGeneration == 0 || f.artist.bindingHash == 0
                || f.artist.identityRecordHash == 0 || f.artist.acceptanceRecordHash == 0
                || f.artist.nominatedArtist == address(0) || f.artist.acceptedAt == 0
                || f.artist.lockedAt == 0
        ) revert S.InvalidViewPreservationSnapshot();
        raw = Read.read(
            d.targets[7],
            abi.encodeCall(
                Manifest.requireCurrentManifest, (p.outputManifestRecord, f.artist.artistId)
            ),
            768,
            d.sourceGas
        );
        f.outputs = abi.decode(raw, (M.Plan));
        _canonical(raw, abi.encode(f.outputs));
        if (
            p.outputManifestRecord == 0 || f.outputs.recordHash != p.outputManifestRecord
                || f.outputs.carrier.artistId != f.artist.artistId
                || f.outputs.carrier.contentHash == 0
                || f.outputs.nextRow != f.membership.tokenCount
                || f.outputs.nextPart != f.outputs.partCount
                || f.outputs.partCount != (f.membership.tokenCount + 63) / 64
                || f.outputs.partChain == 0
        ) {
            revert S.InvalidViewPreservationSnapshot();
        }
        M.Header memory h = f.outputs.header;
        if (
            keccak256(abi.encode(h.scope)) != keccak256(abi.encode(p.scope))
                || h.tokenCount != f.membership.tokenCount
                || h.membershipHash != f.membership.membershipHash
                || h.adoptionRecord != p.expectedAdoptionRecord || h.contentRoot == 0
                || h.outputRoot == 0 || h.checkpointStateHash == 0
        ) {
            revert S.InvalidViewPreservationSnapshot();
        }
        raw = Read.read(
            d.targets[6], abi.encodeCall(Checkpoint.checkpoint, (h.checkpointId)), 416, d.readGas
        );
        f.checkpoint = abi.decode(raw, (C.Plan));
        _canonical(raw, abi.encode(f.checkpoint));
        if (
            keccak256(raw) != h.checkpointStateHash || f.checkpoint.nextIndex != h.tokenCount
                || f.checkpoint.tokenCount != h.tokenCount
                || f.checkpoint.contentRoot != h.contentRoot
                || f.checkpoint.outputRoot != h.outputRoot
                || f.checkpoint.adoptionRecord != h.adoptionRecord
                || f.checkpoint.sourceContextHash != h.sourceContextHash
                || f.checkpoint.membershipHash != h.membershipHash
                || f.checkpoint.policyChainHash != h.policyChainHash
                || keccak256(abi.encode(f.checkpoint.scope)) != keccak256(abi.encode(p.scope))
        ) {
            revert S.InvalidViewPreservationSnapshot();
        }
        // Source.contextHash includes the actual checkpoint host. Execute its fixed source
        // getter rather than reproducing that domain under this snapshot's delegate context.
        raw = Read.bounded(
            d.targets[6],
            abi.encodeCall(Checkpoint.currentSource, (p.scope)),
            16384,
            d.sourceGas,
            false
        );
        f.adoption = abi.decode(raw, (C.Source));
        _canonical(raw, abi.encode(f.adoption));
        if (
            f.adoption.contextHash != h.sourceContextHash
                || f.adoption.adoption.recordHash != h.adoptionRecord
                || f.adoption.adoption.source.route.binding.membership != d.targets[5]
                || f.adoption.adoption.source.route.binding.membershipCodeHash != d.codeHashes[5]
                || f.adoption.adoption.source.route.artist != f.artist.registry
                || f.adoption.adoption.source.route.artistCodeHash != f.artist.registryCodeHash
                || f.adoption.adoption.source.route.metadata != d.targets[1]
                || f.adoption.adoption.source.route.metadataCodeHash != d.codeHashes[1]
                || f.adoption.adoption.source.route.schemas != d.targets[2]
                || f.adoption.adoption.source.route.schemasCodeHash != d.codeHashes[2]
                || f.adoption.adoption.source.route.store != d.targets[3]
                || f.adoption.adoption.source.route.storeCodeHash != d.codeHashes[3]
                || keccak256(abi.encode(f.adoption.adoption.source.membership))
                    != keccak256(abi.encode(f.membership))
                || f.adoption.policy.policyChainHash != h.policyChainHash
        ) revert S.InvalidViewPreservationSnapshot();
        _policies(d, f);
    }

    function sourceHash(S.Dependencies memory d, S.Source memory f)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_PRESERVATION_SNAPSHOT_SOURCES_V1"),
                d.chainId,
                address(this),
                d.targets,
                d.codeHashes,
                f
            )
        );
    }

    function _policies(S.Dependencies memory d, S.Source memory f) private view {
        // Adoption.current has already required the real factory plan, source set and full current
        // policy roster. Retain every canonical row from that same pinned immutable set, not samples.
        uint256 count = f.adoption.policy.policyCount;
        if (count == 0 || count > f.membership.tokenCount || count > 630) {
            revert S.InvalidViewPreservationSnapshot();
        }
        address set = f.adoption.policy.sourceSet;
        Read.pin(set, f.adoption.policy.sourceSetCodeHash);
        f.entropy.planId = f.adoption.policy.inventoryPlan;
        f.entropy.inventoryHash = f.adoption.policy.inventoryHash;
        f.entropy.policyChainHash = f.adoption.policy.policyChainHash;
        f.entropy.policyCount = count;
        f.entropy.allFrozen = true;
        f.entropy.policies = new Policy[](count);
        for (uint256 i; i < count; ++i) {
            bytes memory raw =
                Read.read(set, abi.encodeCall(Set.sourcePolicyAt, (i)), 832, d.readGas);
            Policy memory row = abi.decode(raw, (Policy));
            _canonical(raw, abi.encode(row));
            if (
                !row.frozen || row.coordinator == address(0) || row.indexedCodeHash == 0
                    || row.policyHash == 0 || row.componentDataHash == 0
            ) {
                revert S.InvalidViewPreservationSnapshot();
            }
            f.entropy.policies[i] = row;
        }
    }

    function _checkpointConfiguration(S.Dependencies memory d)
        private
        view
        returns (C.Configuration memory c)
    {
        if (
            Read.word(
                        d.targets[6],
                        abi.encodeCall(IERC165.supportsInterface, (type(Checkpoint).interfaceId)),
                        d.readGas
                    ) != 1 || _word(d, 6, "checkpointProfile()") != C.PROFILE
        ) revert S.InvalidViewPreservationSnapshot();
        bytes memory raw =
            Read.read(d.targets[6], abi.encodeCall(Checkpoint.configuration, ()), 384, d.readGas);
        c = abi.decode(raw, (C.Configuration));
        _canonical(raw, abi.encode(c));
        if (
            c.core != d.targets[0] || c.coreCodeHash != d.codeHashes[0] || c.router != d.targets[4]
                || c.routerCodeHash != d.codeHashes[4] || c.authority != d.targets[9]
                || c.authorityCodeHash != d.codeHashes[9] || c.chainId != d.chainId
        ) {
            revert S.InvalidViewPreservationSnapshot();
        }
        Adoption.validate(c);
    }

    function _address(S.Dependencies memory d, uint256 at, string memory selector, uint256 expected)
        private
        view
    {
        if (uint256(_word(d, at, selector)) != uint256(uint160(d.targets[expected]))) {
            revert S.ViewPreservationSnapshotDependency(d.targets[at]);
        }
    }

    function _word(S.Dependencies memory d, uint256 at, string memory selector)
        private
        view
        returns (bytes32)
    {
        return bytes32(Read.word(d.targets[at], abi.encodeWithSignature(selector), d.readGas));
    }

    function _canonical(bytes memory raw, bytes memory encoded) private pure {
        if (keccak256(raw) != keccak256(encoded)) revert S.InvalidViewPreservationSnapshot();
    }
}
