// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";
import "../records/StreamSnapshotSourceReads.sol";
import "../finality/StreamFinalityDescriptionReads.sol";
import "../finality/StreamFinalityConservationReads.sol";
import "../finality/StreamFinalityReferenceReads.sol";
import "../finality/StreamFinalitySnapshotReads.sol";
import "../finality/StreamFinalityCoordinatorPolicyReads.sol";
import "../finality/StreamOnchainContentBytes.sol";
import "../../interfaces/stream/core/IStreamCoreMint.sol";
import "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import "../../interfaces/stream/finality/IStreamCollectionTokenInventory.sol";
import "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import "../../interfaces/stream/metadata/IStreamConservationRecordSelection.sol";

/// @notice Actual current original inputs and deterministic native bytes, never a supplied set.
library StreamRenderCriticalSourceReads {
    function current(S.Dependencies memory d, uint256 cid)
        public
        view
        returns (S.Context memory c)
    {
        bindings(d);
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, cid, 0, 0);
        if (cid == 0) revert T.InventorySourceChanged();
        c.collectionId = cid;
        bytes memory raw = IO.fixedRead(
            d.targets[6],
            abi.encodeCall(IStreamReferenceRenderPublication.currentReference, (cid)),
            640,
            d.readGas
        );
        c.referenceRender = abi.decode(raw, (StreamReferenceRenderTypes.Receipt));
        IO.canonical(d.targets[6], raw, abi.encode(c.referenceRender));
        StreamFinalityReferenceReads.requireCurrent(
            _reference(d), scope, c.referenceRender.recordHash, c.referenceRender.revision
        );
        raw = IO.fixedRead(
            d.targets[5],
            abi.encodeCall(IStreamCollectionSnapshots.currentSnapshot, (cid)),
            672,
            d.readGas
        );
        c.snapshot = abi.decode(raw, (StreamSnapshotTypes.Receipt));
        IO.canonical(d.targets[5], raw, abi.encode(c.snapshot));
        StreamFinalitySnapshotReads.requireCurrent(
            _snapshot(d), scope, c.snapshot.recordHash, c.snapshot.revision
        );
        if (
            c.referenceRender.snapshotRecordHash != c.snapshot.recordHash
                || c.referenceRender.snapshotRevision != c.snapshot.revision
        ) {
            revert T.InventorySourceChanged();
        }
        c.descriptions = StreamFinalityDescriptionReads.requireCurrent(_descriptions(d), scope);
        StreamFinalityConservationEvidence memory conservation =
            StreamFinalityConservationReads.requireCurrent(_conservation(d), scope);
        c.conservation = conservation.selected;
        c.interviewEvidenceHash = conservation.interviewEvidenceHash;
        StreamSnapshotTypes.NativeFacts memory native =
            StreamSnapshotSourceReads.requireCurrent(snapshotDependencies(d), cid);
        requireSameArtistAssociation(
            d.artistTargets[0], d.artistCodeHashes[0], native.artist, c.conservation.association
        );
        c.subject = native.subject;
        c.artistId = native.artist.artistId;
        c.nativeHash = keccak256(abi.encode(native));
        c.rootRecordHash = native.contentRootRecordHash;
        c.tokenInventoryHash = native.checkpoint.inventoryHash;
        c.checkpointHash = native.leafManifest.checkpointHash;
        c.tokenCount = native.checkpoint.tokenCount;
        if (
            c.subject != c.descriptions.scopeSubject || c.subject != conservation.scopeSubject
                || c.artistId != c.conservation.association.artistId || c.tokenCount == 0
        ) revert T.InventorySourceChanged();
    }

    /// @dev Joins independently admitted original association facts. This pure predicate
    /// grants no authority and deliberately does not equate the nominated key with an
    /// original record signer: ordinary key rotation and delegation retain their meaning.
    function requireSameArtistAssociation(
        address registry,
        bytes32 registryCodeHash,
        IStreamMetadataServingFacts.ArtistPresentation memory presented,
        IStreamConservationRecordSelection.Association memory association
    ) internal pure {
        if (
            presented.registry != registry || presented.registryCodeHash != registryCodeHash
                || presented.artistId != association.artistId
                || presented.bindingGeneration != association.generation
                || presented.bindingHash != association.bindingHash
                || presented.identityRecordHash != association.identityRecordHash
        ) revert T.InventorySourceChanged();
    }

    function bindings(S.Dependencies memory d) public view {
        if (
            d.chainId != block.chainid || d.readGas < 50000 || d.sourceGas < d.readGas
                || d.selectionGas < d.readGas || d.snapshotGas < d.readGas
                || d.referenceGas < d.readGas
        ) {
            revert T.InventorySourceChanged();
        }
        for (uint256 i; i < 12; ++i) {
            IO.pin(d.targets[i], d.codeHashes[i]);
        }
        for (uint256 i; i < 5; ++i) {
            IO.pin(d.artistTargets[i], d.artistCodeHashes[i]);
        }
        IO.pin(d.artistContentOwner, d.artistContentOwnerCodeHash);
        if (
            IO.word(
                        d.targets[6],
                        abi.encodeCall(IStreamReferenceRenderPublication.archiveCoverage, ()),
                        d.readGas
                    ) != bytes32(uint256(uint160(d.targets[11])))
                || IO.word(d.targets[10], abi.encodeWithSignature("core()"), d.readGas)
                    != bytes32(uint256(uint160(d.targets[0])))
                || IO.word(d.targets[11], abi.encodeWithSignature("core()"), d.readGas)
                    != bytes32(uint256(uint160(d.targets[0])))
        ) revert T.InventorySourceChanged();
    }

    function snapshotDependencies(S.Dependencies memory d)
        public
        view
        returns (StreamSnapshotTypes.Dependencies memory sd)
    {
        bytes memory raw = IO.fixedRead(
            d.targets[5],
            abi.encodeCall(IStreamCollectionSnapshots.dependencies, ()),
            736,
            d.readGas
        );
        sd = abi.decode(raw, (StreamSnapshotTypes.Dependencies));
        IO.canonical(d.targets[5], raw, abi.encode(sd));
        if (sd.chainId != d.chainId) revert T.InventorySourceChanged();
        for (uint256 i; i < 5; ++i) {
            if (sd.targets[i] != d.targets[i] || sd.codeHashes[i] != d.codeHashes[i]) {
                revert T.InventorySourceChanged();
            }
        }
        if (
            IO.word(sd.targets[5], abi.encodeWithSignature("artifactCoverage()"), d.readGas)
                != bytes32(uint256(uint160(d.targets[10])))
        ) revert T.InventorySourceChanged();
    }

    function nativeItems(S.Dependencies memory d, S.Context memory c)
        public
        view
        returns (T.Item[] memory items)
    {
        bindings(d);
        StreamSnapshotTypes.Dependencies memory sd = snapshotDependencies(d);
        StreamSnapshotTypes.NativeFacts memory n =
            StreamSnapshotSourceReads.requireCurrent(sd, c.collectionId);
        if (keccak256(abi.encode(n)) != c.nativeHash) revert T.InventorySourceChanged();
        StreamFinalityCoordinatorPolicyReads.Dependencies memory pd;
        pd.targets = [sd.targets[0], sd.targets[1], sd.targets[7], sd.targets[8]];
        pd.codeHashes = [sd.codeHashes[0], sd.codeHashes[1], sd.codeHashes[7], sd.codeHashes[8]];
        pd.chainId = d.chainId;
        if (sd.readGas > type(uint32).max || sd.inventoryGas > type(uint32).max) {
            revert T.InventorySourceChanged();
        }
        pd.readGas = uint32(sd.readGas);
        pd.inventoryGas = uint32(sd.inventoryGas);
        StreamFinalityCoordinatorPolicyEvidence memory policies =
            StreamFinalityCoordinatorPolicyReads.requireCurrent(
                pd,
                StreamFinalityScope(StreamFinalityScopeType.COLLECTION, c.collectionId, 0, 0),
                c.snapshot.inventoryPlan
            );
        if (!policies.allFrozen || policies.policyCount != policies.policies.length) {
            revert T.InventorySourceChanged();
        }
        items = new T.Item[](14 + policies.policies.length * 2);
        bytes32 original = c.snapshot.recordHash;
        items[0] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("SCRIPT"),
            d.targets[4],
            original,
            0,
            bytes(n.source.script)
        );
        items[1] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("DISPLAY_NAME"),
            d.targets[4],
            original,
            0,
            bytes(n.source.name)
        );
        items[2] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("DISPLAY_DESCRIPTION"),
            d.targets[4],
            original,
            0,
            bytes(n.source.description)
        );
        items[3] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("IMAGE_URI"),
            d.targets[4],
            original,
            0,
            bytes(n.source.imageURI)
        );
        items[4] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("ANIMATION_BASE_URI"),
            d.targets[4],
            original,
            0,
            bytes(n.source.animationBaseURI)
        );
        items[5] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("NATIVE_SOURCE_FACTS"),
            d.targets[5],
            original,
            0,
            abi.encode(n)
        );
        items[6] =
            Items.runtime(keccak256("NATIVE_RENDERER_RUNTIME"), n.serving.renderer, original, 0);
        items[7] = Items.runtime(keccak256("ROUTER_RUNTIME"), d.targets[4], original, 0);
        items[8] = Items.runtime(keccak256("CORE_RUNTIME"), d.targets[0], original, 0);
        bytes memory raw = IO.read(
            d.targets[5],
            abi.encodeCall(IStreamCollectionSnapshots.snapshotManifestBytes, (original)),
            524352,
            d.sourceGas
        );
        bytes memory payload = abi.decode(raw, (bytes));
        IO.canonical(d.targets[5], raw, abi.encode(payload));
        if (
            payload.length != c.snapshot.manifestBytes
                || keccak256(payload) != c.snapshot.manifestHash
        ) revert T.InventorySourceChanged();
        items[9] = Items.bytesItem(
            T.Kind.ORIGINAL_PAYLOAD,
            keccak256("SNAPSHOT_MANIFEST"),
            d.targets[5],
            original,
            0,
            payload
        );
        items[9].schemaId = keccak256("STREAM_NATIVE_ONCHAIN_SNAPSHOT_V1");
        items[9].canonicalizationId = keccak256("RFC8785_JCS");
        items[10] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("ORIGINAL_COORDINATOR_POLICIES"),
            sd.targets[8],
            original,
            0,
            abi.encode(policies)
        );
        items[11] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("ORIGINAL_CONTENT_ROOT_RECORD"),
            d.targets[4],
            n.contentRootRecordHash,
            0,
            abi.encode(n.contentRoot)
        );
        items[12] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("ORIGINAL_CONTENT_LEAF_MANIFEST"),
            sd.targets[5],
            n.contentRoot.publication.verifiedManifestRecordHash,
            0,
            abi.encode(n.leafManifest)
        );
        items[13].kind = T.Kind.ONCHAIN_OBJECT;
        items[13].role = keccak256("COMPLETE_CONTENT_LEAF_LIST_BYTES");
        items[13].source = sd.targets[5];
        items[13].sourceRecord = n.contentRoot.publication.verifiedManifestRecordHash;
        items[13].algorithm = 1;
        items[13].canonicalizationId = keccak256("STREAM_ABI_TOKEN_CONTENT_LEAF_MANIFEST_V1");
        items[13].digest = abi.encodePacked(n.leafManifest.manifestHash);
        items[13].byteSize = n.leafManifest.byteLength;
        items[13].schemaId = keccak256("STREAM_TOKEN_CONTENT_LEAF_MANIFEST_V1");
        items[13].objectHash = n.leafManifest.artifactHash;
        items[13].originalCoverageHash = n.leafManifest.coverageHash;
        for (uint256 i; i < policies.policies.length; ++i) {
            items[14 + i * 2] = Items.runtime(
                keccak256("ORIGINAL_COORDINATOR_RUNTIME"),
                policies.policies[i].coordinator,
                original,
                i
            );
            items[15 + i * 2] = Items.bytesItem(
                T.Kind.NATIVE_BYTES,
                keccak256("ORIGINAL_COORDINATOR_POLICY"),
                policies.policies[i].coordinator,
                original,
                i,
                abi.encode(policies.policies[i])
            );
        }
    }

    function _reference(S.Dependencies memory d)
        private
        pure
        returns (StreamFinalityReferenceReads.Dependencies memory)
    {
        return StreamFinalityReferenceReads.Dependencies(
            d.targets[0],
            d.targets[1],
            d.targets[6],
            d.targets[4],
            d.targets[5],
            d.codeHashes[0],
            d.codeHashes[1],
            d.codeHashes[6],
            d.codeHashes[4],
            d.codeHashes[5],
            d.chainId,
            d.readGas,
            d.referenceGas
        );
    }

    function _snapshot(S.Dependencies memory d)
        private
        pure
        returns (StreamFinalitySnapshotReads.Dependencies memory)
    {
        return StreamFinalitySnapshotReads.Dependencies(
            d.targets[0],
            d.targets[1],
            d.targets[5],
            d.codeHashes[0],
            d.codeHashes[1],
            d.codeHashes[5],
            d.chainId,
            d.readGas,
            d.snapshotGas
        );
    }

    function _descriptions(S.Dependencies memory d)
        private
        pure
        returns (StreamFinalityDescriptionReads.Dependencies memory p)
    {
        p.targets = [
            d.targets[0], d.targets[1], d.targets[2], d.targets[3], d.targets[7], d.targets[8]
        ];
        p.codeHashes = [
            d.codeHashes[0],
            d.codeHashes[1],
            d.codeHashes[2],
            d.codeHashes[3],
            d.codeHashes[7],
            d.codeHashes[8]
        ];
        p.chainId = d.chainId;
        p.readGas = d.readGas;
        p.selectionGas = d.selectionGas;
    }

    function _conservation(S.Dependencies memory d)
        private
        pure
        returns (StreamFinalityConservationReads.Dependencies memory p)
    {
        p.targets = [d.targets[0], d.targets[1], d.targets[2], d.targets[3], d.targets[9]];
        p.codeHashes =
            [d.codeHashes[0], d.codeHashes[1], d.codeHashes[2], d.codeHashes[3], d.codeHashes[9]];
        p.chainId = d.chainId;
        p.readGas = d.readGas;
        p.selectionGas = d.selectionGas;
    }
}
