// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import "../metadata/StreamMetadataSubjects.sol";

import {
    IStreamViewPreservationContentRootV1 as Binding
} from "../../interfaces/stream/metadata/IStreamViewPreservationContentRootV1.sol";
import {
    StreamViewPreservationContentDefinitionsV1 as Definitions
} from "../records/StreamViewPreservationContentDefinitionsV1.sol";
import {
    StreamViewPreservationSnapshotDefinitionsV1 as SnapshotDefinitions
} from "../records/StreamViewPreservationSnapshotDefinitionsV1.sol";
import {
    StreamViewPreservationOutputSchemasV1 as OutputDefinitions
} from "../finality/StreamViewPreservationOutputSchemasV1.sol";
import { StreamViewPolicyTypesV2 as Policy } from "../metadata/StreamViewPolicyTypesV2.sol";
import {
    StreamViewPreservationCheckpointTypesV1 as C
} from "../../interfaces/stream/finality/StreamViewPreservationCheckpointTypesV1.sol";
import {
    IStreamViewPreservationContentCheckpointV1 as Checkpoint
} from "../../interfaces/stream/finality/IStreamViewPreservationContentCheckpointV1.sol";

import {
    StreamViewPreservationReferenceTypesV1 as T
} from "../../interfaces/stream/preservation/StreamViewPreservationReferenceTypesV1.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamViewPreservationSnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamViewPreservationSnapshotTypesV1.sol";
import {
    IStreamViewPreservationSnapshotPublicationV1 as Snap
} from "../../interfaces/stream/metadata/IStreamViewPreservationSnapshotPublicationV1.sol";
import {
    IStreamScopedContentRootPublication as Root
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamExternalArtifactCoverage as Archive
} from "../../interfaces/stream/preservation/IStreamExternalArtifactCoverage.sol";
import {
    IStreamExternalArtifactCurrentPair
} from "../../interfaces/stream/preservation/IStreamExternalArtifactCurrentPair.sol";
import {
    StreamFinalityViewPreservationSnapshotReadsV1 as SnapRead
} from "../finality/StreamFinalityViewPreservationSnapshotReadsV1.sol";
import {
    StreamFinalityRouterEvidence as Reads
} from "../finality/StreamFinalityRouterEvidence.sol";
import {
    StreamViewPreservationReferenceSampleReadsV1 as Samples
} from "../preservation/StreamViewPreservationReferenceSampleReadsV1.sol";
import {
    StreamReferenceRenderSourceReads as Archives
} from "../preservation/StreamReferenceRenderSourceReads.sol";
import {
    StreamReferenceRenderDefinitions as D
} from "../records/StreamReferenceRenderDefinitions.sol";
import { StreamMetadataSubjects } from "../metadata/StreamMetadataSubjects.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamExternalArtifactTypes as E
} from "../../interfaces/stream/preservation/StreamExternalArtifactTypes.sol";

import {
    StreamFinalityNativeProviderReads as Native
} from "./StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityViewPreservationConfigurationV1 as Configuration
} from "./StreamFinalityViewPreservationConfigurationV1.sol";
import {
    StreamFinalityViewPreservationSnapshotReadsV1 as Snapshots
} from "./StreamFinalityViewPreservationSnapshotReadsV1.sol";
import {
    IStreamViewPreservationSnapshotPublicationV1 as SnapshotHost
} from "../../interfaces/stream/metadata/IStreamViewPreservationSnapshotPublicationV1.sol";
import {
    StreamViewPreservationRenderCriticalSourceReadsV1 as InventorySources
} from "../preservation/StreamViewPreservationRenderCriticalSourceReadsV1.sol";

/// @notice Exact VIEW metadata projections; no reference, inventory or component-current callback.
library StreamFinalityViewPreservationMetadataV1 {
    struct Evidence {
        Snapshots.Evidence snapshot;
        T.SourceFacts root;
    }

    function current(Native.Config memory c, StreamFinalityScope memory scope, bool locked)
        public
        view
        returns (Evidence memory e)
    {
        Configuration.requireScope(c, scope);
        Configuration.Context memory x = Configuration.resolve(c);
        bytes memory raw = Reads.read(
            x.snapshots.snapshots,
            abi.encodeCall(SnapshotHost.currentSnapshot, (scope)),
            544,
            c.readGas
        );
        S.Receipt memory r = abi.decode(raw, (S.Receipt));
        _canonical(x.snapshots.snapshots, raw, abi.encode(r));
        e.snapshot = locked
            ? Snapshots.requireLocked(x.snapshots, scope, r.recordHash, r.revision)
            : Snapshots.requireCurrent(x.snapshots, scope, r.recordHash, r.revision);
        e.root.snapshot = r;
        e.root.snapshotSource = e.snapshot.source;
        T.Publication memory publication;
        publication.scope = scope;
        T.Dependencies memory rd = InventorySources.referenceBindings(x.inventory);
        S.Dependencies memory sd = InventorySources.snapshotBindings(x.inventory);
        _root(rd, sd, publication, e.root);
    }

    function root(Native.Config memory c, StreamFinalityScope memory scope)
        public
        view
        returns (bytes32, uint64, bytes32)
    {
        Evidence memory e = current(c, scope, false);
        bytes memory raw = Reads.read(
            c.targets[2], abi.encodeCall(Root.scopedTokenContentRoot, (scope)), 96, c.readGas
        );
        (bytes32 value, uint64 count, bytes32 schema) = abi.decode(raw, (bytes32, uint64, bytes32));
        _canonical(c.targets[2], raw, abi.encode(value, count, schema));
        if (
            value != e.root.contentRoot.contentRoot || count != e.root.contentRoot.leafCount
                || schema != OutputDefinitions.LEAF
        ) {
            revert T.InvalidViewPreservationReference();
        }
        return (value, count, schema);
    }

    function snapshot(Native.Config memory c, StreamFinalityScope memory scope)
        public
        view
        returns (bytes32)
    {
        return current(c, scope, false).snapshot.receipt.manifestHash;
    }

    function manifest(Native.Config memory c, StreamFinalityScope memory scope)
        public
        view
        returns (bool, bytes32)
    {
        Configuration.requireScope(c, scope);
        Configuration.resolve(c);
        bytes memory raw = Reads.read(
            c.targets[3],
            abi.encodeWithSignature(
                "requireScopeMembership((uint8,uint256,uint256,bytes32))", scope
            ),
            256,
            c.componentSourceGas
        );
        StreamScopeMembershipFacts memory f = abi.decode(raw, (StreamScopeMembershipFacts));
        _canonical(c.targets[3], raw, abi.encode(f));
        if (
            f.scopeSubject != StreamMetadataSubjects.scopeSubject(c.chainId, c.targets[0], scope)
                || f.tokenCount == 0 || f.membershipHash == 0 || f.sourceRecordHash == 0
                || f.scopeManifestHash == 0
        ) {
            revert T.InvalidViewPreservationReference();
        }
        return (true, f.scopeManifestHash);
    }

    function _root(
        T.Dependencies memory d,
        S.Dependencies memory source,
        T.Publication memory p,
        T.SourceFacts memory f
    ) private view {
        f.contentRootRecordHash = abi.decode(
            Reads.read(
                d.targets[4], abi.encodeCall(Root.scopedContentRootHead, (p.scope)), 32, d.readGas
            ),
            (bytes32)
        );
        bytes memory raw = Reads.dynamicRead(
            d.targets[4],
            abi.encodeCall(Root.scopedContentRootRecord, (f.contentRootRecordHash)),
            4096,
            d.sourceGas
        );
        f.contentRoot = abi.decode(raw, (Root.Record));
        _canonical(d.targets[4], raw, abi.encode(f.contentRoot));
        raw = Reads.read(
            d.targets[4],
            abi.encodeCall(Binding.viewPreservationContentRootBinding, (f.contentRootRecordHash)),
            896,
            d.sourceGas
        );
        f.contentBinding = abi.decode(raw, (Binding.Binding));
        _canonical(d.targets[4], raw, abi.encode(f.contentBinding));
        Binding.Binding memory expected = _binding(d, source, f.snapshotSource);
        if (keccak256(abi.encode(expected)) != keccak256(abi.encode(f.contentBinding))) {
            revert T.InvalidViewPreservationReference();
        }
        // The actual pinned Router getter authenticates the original outer record using its
        // historical aggregate. Recompute the distinct prepared state here as a second join.
        Root.Record memory stateFields = abi.decode(abi.encode(f.contentRoot), (Root.Record));
        stateFields.stateHash = 0;
        stateFields.artistConsent = 0;
        stateFields.publishedAt = 0;
        if (
            keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_PRESERVATION_CONTENT_ROOT_STATE_V1"),
                        d.chainId,
                        d.targets[4],
                        d.targets[0],
                        stateFields,
                        f.contentBinding
                    )
                ) != f.contentRoot.stateHash
        ) revert T.InvalidViewPreservationReference();
        Root.Record memory r = f.contentRoot;
        if (
            f.contentRootRecordHash == 0
                || keccak256(abi.encode(r.publication.scope)) != keccak256(abi.encode(p.scope))
                || r.publication.snapshotRecordHash != f.snapshot.recordHash
                || r.publication.snapshotRevision != f.snapshot.revision
                || r.snapshotHost != d.targets[5] || r.snapshotCodeHash != d.codeHashes[5]
                || r.snapshotManifestHash != f.snapshot.manifestHash
                || r.snapshotSourceHash != f.snapshot.sourceHash
                || r.contentRoot != f.snapshotSource.outputs.header.contentRoot
                || r.contentRoot == 0 || r.leafCount != f.snapshotSource.membership.tokenCount
                || r.leafCount == 0
                || r.outputManifestHash != f.snapshotSource.outputs.carrier.contentHash
                || r.artistId != f.snapshotSource.artist.artistId
                || r.bindingGeneration != f.snapshotSource.artist.bindingGeneration
                || r.bindingHash != f.snapshotSource.artist.bindingHash || r.publisher == address(0)
                || (r.authorizationClass != 7 && r.authorizationClass != 8) || r.grantRevision == 0
                || r.routeHash == 0 || r.stateHash == 0 || r.artistConsent == 0
                || r.publishedAt == 0 || r.publishedAt > block.timestamp
        ) revert T.InvalidViewPreservationReference();
    }

    function _binding(
        T.Dependencies memory referenceDependencies,
        S.Dependencies memory d,
        S.Source memory f
    ) private view returns (Binding.Binding memory b) {
        C.Configuration memory c = abi.decode(
            Reads.read(
                d.targets[6],
                abi.encodeCall(Checkpoint.configuration, ()),
                384,
                referenceDependencies.readGas
            ),
            (C.Configuration)
        );
        b.profileId = Definitions.PROFILE;
        b.outputProfile = C.OUTPUT_PROFILE;
        b.adoptionRecord = f.adoption.adoption.recordHash;
        b.adoptionProfile = Policy.PROFILE;
        b.membershipHash = f.membership.membershipHash;
        b.policyChainHash = f.entropy.policyChainHash;
        b.checkpoint = d.targets[6];
        b.checkpointCodeHash = d.codeHashes[6];
        b.checkpointRecord = f.outputs.header.checkpointId;
        b.checkpointStateHash = f.outputs.header.checkpointStateHash;
        b.outputManifest = d.targets[7];
        b.outputManifestCodeHash = d.codeHashes[7];
        b.outputManifestRecord = f.outputs.recordHash;
        b.manifestIndexHash = f.outputs.carrier.contentHash;
        b.partChain = f.outputs.partChain;
        b.preservationRenderer = c.serving;
        b.preservationRendererCodeHash = c.servingCodeHash;
        b.preservationConfigurationHash = c.servingConfigurationHash;
        b.liveRenderer = f.adoption.preservation.liveRenderer;
        b.liveRendererCodeHash = f.adoption.preservation.liveRendererRuntimeHash;
        b.preservationAttribution = f.adoption.preservation.preservationAttribution;
        b.preservationAttributionCodeHash =
        f.adoption.preservation.preservationAttributionRuntimeHash;
        b.leafSchemaHash = keccak256(OutputDefinitions.document(OutputDefinitions.LEAF));
        b.rootSchemaHash = Definitions.SCHEMA_HASH;
        b.rootCanonicalizationHash = Definitions.CANON_HASH;
        b.snapshotSchemaHash = SnapshotDefinitions.SCHEMA_HASH;
        b.snapshotProfileHash = SnapshotDefinitions.PROFILE_HASH;
        b.snapshotCanonicalizationHash = SnapshotDefinitions.CANON_HASH;
    }

    function _canonical(address target, bytes memory raw, bytes memory encoded) private pure {
        if (keccak256(raw) != keccak256(encoded)) {
            revert T.ViewPreservationReferenceDependency(target);
        }
    }
}
