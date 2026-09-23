// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamPreservationPolicyRootFamiliesV2 as RootFamilies
} from "../finality/StreamPreservationPolicyRootFamiliesV2.sol";
import {
    StreamScopedPreservationPolicyReferenceTypesV1 as T
} from "../../interfaces/stream/preservation/StreamScopedPreservationPolicyReferenceTypesV1.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    IStreamScopedContentRootPublication as Root
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamScopedPreservationPolicyContentRootPublicationV1 as PreservationRoot
} from "../../interfaces/stream/metadata/IStreamScopedPreservationPolicyContentRootPublicationV1.sol";
import {
    IStreamPreservationPolicyOutputManifestV1 as Outputs
} from "../../interfaces/stream/finality/IStreamPreservationPolicyOutputManifestV1.sol";
import {
    StreamFinalityRouterEvidence as Reads
} from "../finality/StreamFinalityRouterEvidence.sol";
import {
    StreamFinalityScope
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @notice Fixed scoped content-root, original output receipt and interpretation joins.
library StreamScopedPreservationReferenceRootWorkerV1 {
    function read(
        T.Dependencies memory d,
        S.Dependencies memory source,
        StreamFinalityScope memory scope,
        bytes32 outputManifestRecord,
        S.Source memory snapshotSource,
        S.Receipt memory snapshot,
        bytes32 family
    )
        public
        view
        returns (
            bytes32 recordHash,
            Root.Record memory rootRecord,
            PreservationRoot.Binding memory rootBinding
        )
    {
        recordHash = abi.decode(
            Reads.read(
                d.targets[4], abi.encodeCall(Root.scopedContentRootHead, (scope)), 32, d.readGas
            ),
            (bytes32)
        );
        bytes memory raw = Reads.dynamicRead(
            d.targets[4],
            abi.encodeCall(Root.scopedContentRootRecord, (recordHash)),
            4096,
            d.sourceGas
        );
        rootRecord = abi.decode(raw, (Root.Record));
        _canonical(d.targets[4], raw, abi.encode(rootRecord));
        raw = Reads.read(
            d.targets[4],
            abi.encodeCall(
                PreservationRoot.scopedPreservationPolicyContentRootBinding, (recordHash)
            ),
            800,
            d.sourceGas
        );
        rootBinding = abi.decode(raw, (PreservationRoot.Binding));
        _canonical(d.targets[4], raw, abi.encode(rootBinding));
        PreservationRoot.Binding memory expected =
            _binding(source, snapshotSource, snapshot, family);
        if (keccak256(raw) != keccak256(abi.encode(expected))) {
            revert T.InvalidScopedPolicyReference();
        }
        // The root-free snapshot declaration names the actual output receipt. Its payload
        // hash is a different value and must never stand in for this original record key.
        raw = Reads.read(
            source.targets[8],
            abi.encodeCall(Outputs.manifestRecord, (outputManifestRecord)),
            608,
            d.sourceGas
        );
        Outputs.Manifest memory manifest = abi.decode(raw, (Outputs.Manifest));
        _canonical(source.targets[8], raw, abi.encode(manifest));
        if (
            outputManifestRecord == 0
                || keccak256(raw) != keccak256(abi.encode(snapshotSource.outputs))
        ) {
            revert T.InvalidScopedPolicyReference();
        }
        Root.Record memory r = rootRecord;
        if (
            recordHash == 0
                || keccak256(abi.encode(r.publication.scope)) != keccak256(abi.encode(scope))
                || r.publication.snapshotRecordHash != snapshot.recordHash
                || r.publication.snapshotRevision != snapshot.revision
                || r.snapshotHost != d.targets[5] || r.snapshotCodeHash != d.codeHashes[5]
                || r.snapshotManifestHash != snapshot.manifestHash
                || r.snapshotSourceHash != snapshot.sourceHash
                || r.contentRoot != snapshotSource.outputs.contentRoot || r.contentRoot == 0
                || r.leafCount != snapshotSource.membership.tokenCount || r.leafCount == 0
                || r.outputManifestHash != snapshotSource.outputs.manifestHash
                || r.artistId != snapshotSource.artist.artistId
                || r.bindingGeneration != snapshotSource.artist.bindingGeneration
                || r.bindingHash != snapshotSource.artist.bindingHash || r.publisher == address(0)
                || (r.authorizationClass != 7 && r.authorizationClass != 8) || r.grantRevision == 0
                || r.routeHash == 0 || r.stateHash == 0 || r.artistConsent == 0
                || r.publishedAt == 0 || r.publishedAt > block.timestamp
        ) revert T.InvalidScopedPolicyReference();
        Root.Record memory fields = abi.decode(abi.encode(r), (Root.Record));
        fields.stateHash = 0;
        fields.artistConsent = 0;
        fields.publishedAt = 0;
        if (
            r.stateHash
                != keccak256(
                    abi.encode(
                        RootFamilies.stateDomain(family, true),
                        d.chainId,
                        d.targets[4],
                        d.targets[0],
                        fields,
                        rootBinding
                    )
                )
        ) revert T.InvalidScopedPolicyReference();
    }

    function _binding(
        S.Dependencies memory d,
        S.Source memory source,
        S.Receipt memory receipt,
        bytes32 family
    ) private pure returns (PreservationRoot.Binding memory b) {
        bytes32[5] memory ids = RootFamilies.ids(family, true);
        b.profileId = RootFamilies.profile(family, true);
        b.outputManifest = d.targets[8];
        b.outputManifestCodeHash = d.codeHashes[8];
        b.checkpoint = d.targets[7];
        b.checkpointCodeHash = d.codeHashes[7];
        b.checkpointHash = source.outputs.checkpointHash;
        b.checkpointStateHash = source.outputs.checkpointStateHash;
        b.entropySourceSet = d.targets[10];
        b.entropySourceSetCodeHash = d.codeHashes[10];
        b.inventoryHash = source.outputs.inventoryHash;
        b.policyChainHash = source.outputs.policyChainHash;
        b.outputRoot = source.outputs.outputRoot;
        b.outputSchemaHash = RootFamilies.definitionHash(family, true, ids[0]);
        b.outputCanonicalizationHash = RootFamilies.definitionHash(family, true, ids[1]);
        b.leafSchemaHash = RootFamilies.definitionHash(family, true, ids[2]);
        b.rootSchemaHash = RootFamilies.definitionHash(family, true, ids[3]);
        b.rootCanonicalizationHash = RootFamilies.definitionHash(family, true, ids[4]);
        b.sourceFactory = source.sourceFactory;
        b.sourceFactoryCodeHash = source.sourceFactoryCodeHash;
        b.factoryDependenciesHash = source.factoryDependenciesHash;
        b.snapshotSchemaHash = receipt.schemaHash;
        b.snapshotProfileHash = receipt.profileHash;
        b.snapshotCanonicalizationHash = receipt.canonicalizationHash;
        b.metadataRouter = source.outputs.metadataRouter;
        b.preservationOutputProfile = source.outputs.preservationProfile;
    }

    function _canonical(address target, bytes memory raw, bytes memory encoded) private pure {
        if (keccak256(raw) != keccak256(encoded)) revert T.ScopedPolicyReferenceDependency(target);
    }
}
