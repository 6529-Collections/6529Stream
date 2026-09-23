// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationTokenProducerProfilesV1 as Producers
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    StreamPreservationPolicySnapshotFamiliesV2 as SnapshotFamilies
} from "../records/StreamPreservationPolicySnapshotFamiliesV2.sol";
import {
    StreamPreservationPolicyRootFamiliesV2 as RootFamilies
} from "./StreamPreservationPolicyRootFamiliesV2.sol";

import {
    StreamFinalityScopedPreservationPolicySnapshotReadsV1 as SnapshotReads
} from "./StreamFinalityScopedPreservationPolicySnapshotReadsV1.sol";
import { StreamFinalityRouterEvidence as Reads } from "./StreamFinalityRouterEvidence.sol";
import { StreamMetadataSubjects } from "../metadata/StreamMetadataSubjects.sol";
import {
    IStreamScopedContentRootPublication as Root
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamScopedPreservationPolicySnapshotPublicationV1 as Snapshot
} from "../../interfaces/stream/metadata/IStreamScopedPreservationPolicySnapshotPublicationV1.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import "../../interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

import {
    IStreamScopedPreservationPolicyContentRootPublicationV1 as PreservationRoot
} from "../../interfaces/stream/metadata/IStreamScopedPreservationPolicyContentRootPublicationV1.sol";
import {
    IStreamPreservationPolicyOutputManifestV1 as Outputs
} from "../../interfaces/stream/finality/IStreamPreservationPolicyOutputManifestV1.sol";
import {
    StreamScopedPreservationPolicyContentRootSchemasV1 as RootSchemas
} from "./StreamScopedPreservationPolicyContentRootSchemasV1.sol";
import {
    StreamPreservationPolicyOutputSchemasV1 as OutputSchemas
} from "./StreamPreservationPolicyOutputSchemasV1.sol";
import {
    IStreamFinalityScopedEntropyPolicySourceFactoryV2 as Factory
} from "../../interfaces/stream/finality/IStreamFinalityScopedEntropyPolicySourceFactoryV2.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as Policies
} from "./StreamFinalityCoordinatorPolicyReadsV2.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";

import {
    StreamFinalityScopedPreservationPolicyProviderMetadataV1 as M
} from "./StreamFinalityScopedPreservationPolicyProviderMetadataV1.sol";

/// @notice Fixed selected root reader; preserves delegate-host identity and original read budgets.
library StreamFinalityScopedPreservationPolicyMetadataRootV1 {
    function read(
        M.Config memory c,
        StreamFinalityScope memory scope,
        bytes32 outputManifestRecord,
        M.RootFacts memory f,
        bytes32 preservationFamily
    ) public view returns (bytes32, Root.Record memory, PreservationRoot.Binding memory) {
        f.recordHash = abi.decode(
            Reads.read(
                c.snapshots.router,
                abi.encodeCall(Root.scopedContentRootHead, (scope)),
                32,
                c.snapshots.readGas
            ),
            (bytes32)
        );
        bytes memory raw = Reads.dynamicRead(
            c.snapshots.router,
            abi.encodeCall(Root.scopedContentRootRecord, (f.recordHash)),
            4096,
            c.snapshots.validationGas
        );
        f.record = abi.decode(raw, (Root.Record));
        _canonical(raw, abi.encode(f.record));
        raw = Reads.read(
            c.snapshots.router,
            abi.encodeCall(
                PreservationRoot.scopedPreservationPolicyContentRootBinding, (f.recordHash)
            ),
            800,
            c.snapshots.validationGas
        );
        f.binding = abi.decode(raw, (PreservationRoot.Binding));
        _canonical(raw, abi.encode(f.binding));
        PreservationRoot.Binding memory expected =
            _binding(f.dependencies, f.source, f.snapshot, preservationFamily);
        if (keccak256(raw) != keccak256(abi.encode(expected))) {
            revert M.InvalidScopedProviderMetadata();
        }
        // The root-free snapshot declaration names the actual output receipt. Its payload
        // hash is a different value and must never stand in for this original record key.
        raw = Reads.read(
            f.dependencies.targets[8],
            abi.encodeCall(Outputs.manifestRecord, (outputManifestRecord)),
            608,
            c.snapshots.validationGas
        );
        Outputs.Manifest memory savedManifest = abi.decode(raw, (Outputs.Manifest));
        _canonical(raw, abi.encode(savedManifest));
        if (outputManifestRecord == 0 || keccak256(raw) != keccak256(abi.encode(f.source.outputs)))
        {
            revert M.InvalidScopedProviderMetadata();
        }
        Root.Record memory r = f.record;
        if (
            f.recordHash == 0
                || keccak256(abi.encode(r.publication.scope)) != keccak256(abi.encode(scope))
                || r.publication.snapshotRecordHash != f.snapshot.recordHash
                || r.publication.snapshotRevision != f.snapshot.revision
                || r.snapshotHost != c.snapshots.snapshots
                || r.snapshotCodeHash != c.snapshots.snapshotsCodeHash
                || r.snapshotManifestHash != f.snapshot.manifestHash
                || r.snapshotSourceHash != f.snapshot.sourceHash
                || r.contentRoot != f.source.outputs.contentRoot || r.contentRoot == 0
                || r.leafCount != f.source.membership.tokenCount || r.leafCount == 0
                || r.outputManifestHash != f.source.outputs.manifestHash
                || r.artistId != f.source.artist.artistId
                || r.bindingGeneration != f.source.artist.bindingGeneration
                || r.bindingHash != f.source.artist.bindingHash || r.publisher == address(0)
                || (r.authorizationClass != 7 && r.authorizationClass != 8) || r.grantRevision == 0
                || r.routeHash == 0 || r.stateHash == 0 || r.artistConsent == 0
                || r.publishedAt == 0 || r.publishedAt > block.timestamp
        ) revert M.InvalidScopedProviderMetadata();
        Root.Record memory fields = abi.decode(abi.encode(r), (Root.Record));
        fields.stateHash = 0;
        fields.artistConsent = 0;
        fields.publishedAt = 0;
        if (
            r.stateHash
                != keccak256(
                    abi.encode(
                        RootFamilies.stateDomain(preservationFamily, true),
                        c.snapshots.chainId,
                        c.snapshots.router,
                        c.snapshots.core,
                        fields,
                        f.binding
                    )
                )
        ) revert M.InvalidScopedProviderMetadata();
        raw = Reads.read(
            c.snapshots.router,
            abi.encodeCall(Root.scopedTokenContentRoot, (scope)),
            96,
            c.snapshots.readGas
        );
        (bytes32 value, uint64 count, bytes32 schema) = abi.decode(raw, (bytes32, uint64, bytes32));
        _canonical(raw, abi.encode(value, count, schema));
        if (value != r.contentRoot || count != r.leafCount || schema != OutputSchemas.LEAF_SCHEMA) {
            revert M.InvalidScopedProviderMetadata();
        }
        return (f.recordHash, f.record, f.binding);
    }

    function _binding(
        S.Dependencies memory d,
        S.Source memory source,
        S.Receipt memory receipt,
        bytes32 preservationFamily
    ) private pure returns (PreservationRoot.Binding memory b) {
        b.profileId = RootFamilies.profile(preservationFamily, true);
        bytes32[5] memory ids = RootFamilies.ids(preservationFamily, true);
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
        b.outputSchemaHash = RootFamilies.definitionHash(preservationFamily, true, ids[0]);
        b.outputCanonicalizationHash = RootFamilies.definitionHash(preservationFamily, true, ids[1]);
        b.leafSchemaHash = RootFamilies.definitionHash(preservationFamily, true, ids[2]);
        b.rootSchemaHash = RootFamilies.definitionHash(preservationFamily, true, ids[3]);
        b.rootCanonicalizationHash = RootFamilies.definitionHash(preservationFamily, true, ids[4]);
        b.sourceFactory = source.sourceFactory;
        b.sourceFactoryCodeHash = source.sourceFactoryCodeHash;
        b.factoryDependenciesHash = source.factoryDependenciesHash;
        b.snapshotSchemaHash = receipt.schemaHash;
        b.snapshotProfileHash = receipt.profileHash;
        b.snapshotCanonicalizationHash = receipt.canonicalizationHash;
        b.metadataRouter = d.targets[4];
        b.preservationOutputProfile = source.outputs.preservationProfile;
    }

    function _canonical(bytes memory raw, bytes memory encoded) private pure {
        if (keccak256(raw) != keccak256(encoded)) revert M.InvalidScopedProviderMetadata();
    }
}
