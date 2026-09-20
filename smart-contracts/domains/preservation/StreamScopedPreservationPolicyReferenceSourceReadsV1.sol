// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamScopedPreservationPolicyReferenceTypesV1 as T
} from "../../interfaces/stream/preservation/StreamScopedPreservationPolicyReferenceTypesV1.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    IStreamScopedPreservationPolicySnapshotPublicationV1 as Snap
} from "../../interfaces/stream/metadata/IStreamScopedPreservationPolicySnapshotPublicationV1.sol";
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
    StreamFinalityScopedPreservationPolicySnapshotReadsV1 as SnapRead
} from "../finality/StreamFinalityScopedPreservationPolicySnapshotReadsV1.sol";
import {
    StreamFinalityRouterEvidence as Reads
} from "../finality/StreamFinalityRouterEvidence.sol";
import {
    StreamScopedPreservationPolicyReferenceSampleReadsV1 as Samples
} from "./StreamScopedPreservationPolicyReferenceSampleReadsV1.sol";
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

import {
    IStreamScopedPreservationPolicyContentRootPublicationV1 as PreservationRoot
} from "../../interfaces/stream/metadata/IStreamScopedPreservationPolicyContentRootPublicationV1.sol";
import {
    IStreamPreservationPolicyOutputManifestV1 as Outputs
} from "../../interfaces/stream/finality/IStreamPreservationPolicyOutputManifestV1.sol";
import {
    StreamScopedPreservationPolicyContentRootSchemasV1 as RootSchemas
} from "../finality/StreamScopedPreservationPolicyContentRootSchemasV1.sol";
import {
    StreamPreservationPolicyOutputSchemasV1 as OutputSchemas
} from "../finality/StreamPreservationPolicyOutputSchemasV1.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";

/// @notice Current complete preservation snapshot and original Router authority, with bounded samples.
/// @dev A first/last capture is never substituted for the complete snapshot membership or archive.
library StreamScopedPreservationPolicyReferenceSourceReadsV1 {
    function subject(T.Dependencies memory d, StreamFinalityScope memory scope)
        internal
        pure
        returns (bytes32)
    {
        if (
            scope.scopeType != StreamFinalityScopeType.TOKEN
                && scope.scopeType != StreamFinalityScopeType.RELEASE
                && scope.scopeType != StreamFinalityScopeType.SEASON
        ) revert T.InvalidScopedPolicyReference();
        return StreamMetadataSubjects.scopeSubject(d.chainId, d.targets[0], scope);
    }

    /// @notice Exact constructor graph. Current selection/source eligibility is checked on use.
    function bindings(T.Dependencies memory d) public view returns (S.Dependencies memory source) {
        if (
            d.chainId != block.chainid || d.readGas < 50000 || d.sourceGas < d.readGas
                || d.snapshotGas < d.sourceGas || d.archiveGas < d.readGas
        ) revert T.InvalidScopedPolicyReference();
        for (uint256 i; i < 7; ++i) {
            if (d.targets[i].code.length == 0 || d.targets[i].codehash != d.codeHashes[i]) {
                revert T.ScopedPolicyReferenceDependency(d.targets[i]);
            }
        }
        if (
            abi.decode(
                        Reads.read(
                            d.targets[5],
                            abi.encodeCall(IERC165.supportsInterface, (type(Snap).interfaceId)),
                            32,
                            d.readGas
                        ),
                        (uint256)
                    ) != 1
                || abi.decode(
                        Reads.read(
                            d.targets[5],
                            abi.encodeCall(Snap.scopedPreservationPolicySnapshotProfile, ()),
                            32,
                            d.readGas
                        ),
                        (bytes32)
                    ) != keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V1")
                || abi.decode(
                        Reads.read(
                            d.targets[4],
                            abi.encodeCall(
                                IERC165.supportsInterface, (type(PreservationRoot).interfaceId)
                            ),
                            32,
                            d.readGas
                        ),
                        (uint256)
                    ) != 1
        ) revert T.InvalidScopedPolicyReference();
        bytes memory raw =
            Reads.read(d.targets[5], abi.encodeCall(Snap.dependencies, ()), 832, d.readGas);
        source = abi.decode(raw, (S.Dependencies));
        _canonical(d.targets[5], raw, abi.encode(source));
        if (source.chainId != d.chainId) revert T.InvalidScopedPolicyReference();
        for (uint256 i; i < 5; ++i) {
            if (source.targets[i] != d.targets[i] || source.codeHashes[i] != d.codeHashes[i]) {
                revert T.ScopedPolicyReferenceDependency(d.targets[5]);
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
            revert T.ScopedPolicyReferenceDependency(d.targets[6]);
        }
    }

    function requireSource(T.Dependencies memory d, T.Publication memory p, bool current)
        public
        view
        returns (T.SourceFacts memory f)
    {
        f.scopeSubject = subject(d, p.scope);
        if (p.observation.collectionId != p.scope.collectionId) {
            revert T.InvalidScopedPolicyReference();
        }
        S.Dependencies memory source = bindings(d);
        SnapRead.Dependencies memory reader = SnapRead.Dependencies(
            d.targets[0],
            d.targets[1],
            d.targets[4],
            d.targets[5],
            d.codeHashes[0],
            d.codeHashes[1],
            d.codeHashes[4],
            d.codeHashes[5],
            d.chainId,
            d.readGas,
            d.snapshotGas
        );
        SnapRead.requireCurrent(
            reader, p.scope, p.observation.snapshotRecordHash, p.observation.snapshotRevision
        );
        (S.Publication memory original, S.Receipt memory receipt) = SnapRead.original(
            reader, p.scope, p.observation.snapshotRecordHash, p.observation.snapshotRevision
        );
        f.snapshot = receipt;
        f.snapshotSource = _snapshot(d, source, original, receipt);
        _root(d, source, p, original.outputManifestRecord, f);
        uint256 count = f.snapshotSource.membership.tokenCount;
        if (
            count == 0 || count > type(uint64).max
                || p.observation.captures.length != (count == 1 ? 1 : 2)
        ) revert T.InvalidScopedPolicyReference();
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
                revert T.InvalidScopedPolicyReference();
            }
            f.samples[i] = Samples.requireSample(
                d,
                source,
                p.scope,
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
                keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_SOURCES_V1"),
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

    function _snapshot(
        T.Dependencies memory d,
        S.Dependencies memory source,
        S.Publication memory original,
        S.Receipt memory receipt
    ) private view returns (S.Source memory f) {
        bytes memory out = Reads.dynamicRead(
            d.targets[5],
            abi.encodeCall(Snap.snapshotPayload, (receipt.recordHash)),
            receipt.manifestBytes + 96,
            d.snapshotGas
        );
        bytes memory raw = abi.decode(out, (bytes));
        _canonical(d.targets[5], out, abi.encode(raw));
        if (raw.length != receipt.manifestBytes || keccak256(raw) != receipt.manifestHash) {
            revert T.InvalidScopedPolicyReference();
        }
        (
            bytes32 domain,
            uint256 chain,
            address host,
            address[11] memory targets,
            bytes32[11] memory hashes,
            S.Publication memory p,
            S.Receipt memory fields,
            S.Source memory value
        ) = abi.decode(
            raw,
            (
                bytes32,
                uint256,
                address,
                address[11],
                bytes32[11],
                S.Publication,
                S.Receipt,
                S.Source
            )
        );
        _canonical(
            d.targets[5], raw, abi.encode(domain, chain, host, targets, hashes, p, fields, value)
        );
        // The caller retains the original receipt for the root/source join below.
        receipt = abi.decode(abi.encode(receipt), (S.Receipt));
        original.expectedSourceHash = 0;
        receipt.recordHash = 0;
        receipt.chainHash = 0;
        receipt.manifestHash = 0;
        receipt.manifestBytes = 0;
        receipt.recordedAt = 0;
        if (
            domain != keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_PAYLOAD_V1")
                || chain != d.chainId || host != d.targets[5]
                || keccak256(abi.encode(targets, hashes))
                    != keccak256(abi.encode(source.targets, source.codeHashes))
                || keccak256(abi.encode(p)) != keccak256(abi.encode(original))
                || keccak256(abi.encode(fields)) != keccak256(abi.encode(receipt))
                || keccak256(abi.encode(value.scope)) != keccak256(abi.encode(p.scope))
                || fields.sourceHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_SOURCES_V1"),
                            chain,
                            host,
                            targets,
                            hashes,
                            value
                        )
                    )
        ) revert T.InvalidScopedPolicyReference();
        f = value;
    }

    function _root(
        T.Dependencies memory d,
        S.Dependencies memory source,
        T.Publication memory p,
        bytes32 outputManifestRecord,
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
            abi.encodeCall(
                PreservationRoot.scopedPreservationPolicyContentRootBinding,
                (f.contentRootRecordHash)
            ),
            800,
            d.sourceGas
        );
        f.contentRootBinding = abi.decode(raw, (PreservationRoot.Binding));
        _canonical(d.targets[4], raw, abi.encode(f.contentRootBinding));
        PreservationRoot.Binding memory expected = _binding(source, f.snapshotSource, f.snapshot);
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
                || keccak256(raw) != keccak256(abi.encode(f.snapshotSource.outputs))
        ) {
            revert T.InvalidScopedPolicyReference();
        }
        Root.Record memory r = f.contentRoot;
        if (
            f.contentRootRecordHash == 0
                || keccak256(abi.encode(r.publication.scope)) != keccak256(abi.encode(p.scope))
                || r.publication.snapshotRecordHash != f.snapshot.recordHash
                || r.publication.snapshotRevision != f.snapshot.revision
                || r.snapshotHost != d.targets[5] || r.snapshotCodeHash != d.codeHashes[5]
                || r.snapshotManifestHash != f.snapshot.manifestHash
                || r.snapshotSourceHash != f.snapshot.sourceHash
                || r.contentRoot != f.snapshotSource.outputs.contentRoot || r.contentRoot == 0
                || r.leafCount != f.snapshotSource.membership.tokenCount || r.leafCount == 0
                || r.outputManifestHash != f.snapshotSource.outputs.manifestHash
                || r.artistId != f.snapshotSource.artist.artistId
                || r.bindingGeneration != f.snapshotSource.artist.bindingGeneration
                || r.bindingHash != f.snapshotSource.artist.bindingHash || r.publisher == address(0)
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
                        keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_STATE_V1"),
                        d.chainId,
                        d.targets[4],
                        d.targets[0],
                        fields,
                        f.contentRootBinding
                    )
                )
        ) revert T.InvalidScopedPolicyReference();
    }

    function _binding(S.Dependencies memory d, S.Source memory source, S.Receipt memory receipt)
        private
        pure
        returns (PreservationRoot.Binding memory b)
    {
        b.profileId = RootSchemas.PROFILE;
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
        b.outputSchemaHash = RootSchemas.definitionHash(OutputSchemas.SCHEMA);
        b.outputCanonicalizationHash = RootSchemas.definitionHash(OutputSchemas.CANON);
        b.leafSchemaHash = RootSchemas.definitionHash(OutputSchemas.LEAF_SCHEMA);
        b.rootSchemaHash = RootSchemas.definitionHash(RootSchemas.ROOT_SCHEMA);
        b.rootCanonicalizationHash = RootSchemas.definitionHash(RootSchemas.ROOT_CANON);
        b.sourceFactory = source.sourceFactory;
        b.sourceFactoryCodeHash = source.sourceFactoryCodeHash;
        b.factoryDependenciesHash = source.factoryDependenciesHash;
        b.snapshotSchemaHash = receipt.schemaHash;
        b.snapshotProfileHash = receipt.profileHash;
        b.snapshotCanonicalizationHash = receipt.canonicalizationHash;
        b.metadataRouter = source.outputs.metadataRouter;
        b.preservationOutputProfile = source.outputs.preservationProfile;
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
        ) revert T.InvalidScopedPolicyReference();
    }

    function _canonical(address target, bytes memory raw, bytes memory encoded) private pure {
        if (keccak256(raw) != keccak256(encoded)) revert T.ScopedPolicyReferenceDependency(target);
    }
}
