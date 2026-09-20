// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
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
} from "./StreamViewPreservationReferenceSampleReadsV1.sol";
import {
    StreamReferenceRenderSourceReads as Archives
} from "./StreamReferenceRenderSourceReads.sol";
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

/// @notice Current complete scoped snapshot and original Router authority, with bounded samples.
/// @dev A first/last capture is never substituted for the complete snapshot membership or archive.
library StreamViewPreservationReferenceSourceReadsV1 {
    function subject(T.Dependencies memory d, StreamFinalityScope memory scope)
        internal
        pure
        returns (bytes32)
    {
        if (scope.scopeType != StreamFinalityScopeType.VIEW) {
            revert T.InvalidViewPreservationReference();
        }
        return StreamMetadataSubjects.scopeSubject(d.chainId, d.targets[0], scope);
    }

    /// @notice Exact constructor graph. Current selection/source eligibility is checked on use.
    function bindings(T.Dependencies memory d) public view returns (S.Dependencies memory source) {
        if (
            d.chainId != block.chainid || d.readGas < 50000 || d.sourceGas < d.readGas
                || d.snapshotGas < d.sourceGas || d.archiveGas < d.readGas
        ) revert T.InvalidViewPreservationReference();
        for (uint256 i; i < 7; ++i) {
            if (d.targets[i].code.length == 0 || d.targets[i].codehash != d.codeHashes[i]) {
                revert T.ViewPreservationReferenceDependency(d.targets[i]);
            }
        }
        bytes memory raw =
            Reads.read(d.targets[5], abi.encodeCall(Snap.dependencies, ()), 768, d.readGas);
        source = abi.decode(raw, (S.Dependencies));
        _canonical(d.targets[5], raw, abi.encode(source));
        if (source.chainId != d.chainId) revert T.InvalidViewPreservationReference();
        for (uint256 i; i < 5; ++i) {
            if (source.targets[i] != d.targets[i] || source.codeHashes[i] != d.codeHashes[i]) {
                revert T.ViewPreservationReferenceDependency(d.targets[5]);
            }
        }
        if (
            abi.decode(
                        Reads.read(d.targets[6], abi.encodeCall(Archive.core, ()), 32, d.readGas),
                        (address)
                    ) != d.targets[0]
                || abi.decode(
                        Reads.read(
                            d.targets[6],
                            abi.encodeCall(
                                Archive.supportsInterface,
                                (type(IStreamExternalArtifactCurrentPair).interfaceId)
                            ),
                            32,
                            d.readGas
                        ),
                        (uint256)
                    ) != 1
        ) {
            revert T.ViewPreservationReferenceDependency(d.targets[6]);
        }
    }

    function requireSource(T.Dependencies memory d, T.Publication memory p, bool current)
        public
        view
        returns (T.SourceFacts memory f)
    {
        f.scopeSubject = subject(d, p.scope);
        if (p.observation.collectionId != p.scope.collectionId) {
            revert T.InvalidViewPreservationReference();
        }
        S.Dependencies memory source = bindings(d);
        SnapRead.Dependencies memory reader = SnapRead.Dependencies(
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
        SnapRead.Evidence memory evidence = SnapRead.requireCurrent(
            reader, p.scope, p.observation.snapshotRecordHash, p.observation.snapshotRevision
        );
        f.snapshot = evidence.receipt;
        f.snapshotSource = evidence.source;
        _root(d, source, p, f);
        uint256 count = f.snapshotSource.membership.tokenCount;
        if (
            count == 0 || count > type(uint64).max
                || p.observation.captures.length != (count == 1 ? 1 : 2)
        ) revert T.InvalidViewPreservationReference();
        R.Dependencies memory archive = archiveDependencies(d);
        f.environmentCoverage = Archives.coverage(
            archive,
            p.observation.environment.coverageHash,
            f.snapshotSource.artist.artistId,
            p.observation.environment.objectHash,
            current
        );
        _runtime(archive, f.environmentCoverage);
        f.samples = new T.Sample[](p.observation.captures.length);
        for (uint256 i; i < f.samples.length; ++i) {
            if (
                p.observation.captures[i].environmentManifestHash
                    != p.observation.environment.manifestHash
            ) {
                revert T.InvalidViewPreservationReference();
            }
            f.samples[i] = Samples.requireSample(
                d,
                source,
                f.snapshotSource,
                uint64(i == 0 ? 0 : count - 1),
                p.observation.captures[i],
                current
            );
        }
    }

    function sourceHash(T.Dependencies memory d, T.SourceFacts memory f)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_PRESERVATION_REFERENCE_SOURCES_V1"),
                d.chainId,
                address(this),
                d.targets,
                d.codeHashes,
                f
            )
        );
    }

    function archiveDependencies(T.Dependencies memory d)
        internal
        pure
        returns (R.Dependencies memory r)
    {
        r.targets = d.targets;
        r.codeHashes = d.codeHashes;
        r.chainId = d.chainId;
        r.readGas = d.readGas;
        r.sourceGas = d.sourceGas;
        r.snapshotGas = d.snapshotGas;
        r.archiveGas = d.archiveGas;
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

    function _runtime(R.Dependencies memory d, E.Coverage memory e) private view {
        bytes memory raw = Reads.read(
            d.targets[6], abi.encodeCall(Archive.objectIdentity, (e.objectHash)), 320, d.archiveGas
        );
        E.ObjectIdentity memory o = abi.decode(raw, (E.ObjectIdentity));
        _canonical(d.targets[6], raw, abi.encode(o));
        if (
            o.artistId != e.artistId || o.contentHash != e.contentHash
                || o.sha256Digest != e.sha256Digest || o.arweaveDataRoot != e.arweaveDataRoot
                || o.byteSize != e.byteSize || o.canonicalizationId != keccak256("RAW_BYTES")
                || o.schemaId != D.ZIP_SCHEMA_ID || o.formatId != keccak256("IANA:application/zip")
                || o.formatCatalogId != D.FORMAT_CATALOG_ID
                || o.formatCatalogHash != D.FORMAT_CATALOG_HASH
        ) revert T.InvalidViewPreservationReference();
    }

    function _canonical(address target, bytes memory raw, bytes memory encoded) private pure {
        if (keccak256(raw) != keccak256(encoded)) {
            revert T.ViewPreservationReferenceDependency(target);
        }
    }
}
