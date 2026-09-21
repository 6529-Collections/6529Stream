// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyRootFamiliesV2 as RootFamilies
} from "../finality/StreamPreservationPolicyRootFamiliesV2.sol";
import {
    StreamPreservationPolicyReferenceFamiliesV2 as F
} from "./StreamPreservationPolicyReferenceFamiliesV2.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Profiles
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";

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

import {
    StreamScopedPreservationReferenceSnapshotWorkerV1 as SnapshotWorker
} from "./StreamScopedPreservationReferenceSnapshotWorkerV1.sol";
import {
    StreamScopedPreservationReferenceRootWorkerV1 as RootWorker
} from "./StreamScopedPreservationReferenceRootWorkerV1.sol";

/// @notice Current complete preservation snapshot and original Router authority, with bounded samples.
/// @dev A first/last capture is never substituted for the complete snapshot membership or archive.
library StreamScopedPreservationPolicyReferenceSourceReadsV1 {
    // Preserve the original error ABI after moving the final root-family check.
    error InvalidPreservationRootFamily();

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
        return bindings(d, Profiles.ORIGINAL_PROFILE);
    }

    function bindings(T.Dependencies memory d, bytes32 family)
        public
        view
        returns (S.Dependencies memory source)
    {
        F.isV2(family);
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
                    )
                    != (F.isV2(family)
                            ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V2")
                            : keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V1"))
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
        return requireSource(d, p, current, Profiles.ORIGINAL_PROFILE);
    }

    function requireSource(
        T.Dependencies memory d,
        T.Publication memory p,
        bool current,
        bytes32 family
    ) public view returns (T.SourceFacts memory f) {
        f.scopeSubject = subject(d, p.scope);
        if (p.observation.collectionId != p.scope.collectionId) {
            revert T.InvalidScopedPolicyReference();
        }
        S.Dependencies memory source = bindings(d, family);
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
            reader,
            p.scope,
            p.observation.snapshotRecordHash,
            p.observation.snapshotRevision,
            family
        );
        (S.Publication memory original, S.Receipt memory receipt) = SnapRead.original(
            reader,
            p.scope,
            p.observation.snapshotRecordHash,
            p.observation.snapshotRevision,
            family
        );
        f.snapshot = receipt;
        f.snapshotSource = _snapshot(d, source, original, receipt, family);
        _root(d, source, p, original.outputManifestRecord, f, family);
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
                current,
                family
            );
        }
    }

    function sourceHash(T.Dependencies memory d, T.SourceFacts memory f)
        internal
        view
        returns (bytes32)
    {
        return sourceHash(d, f, Profiles.ORIGINAL_PROFILE);
    }

    function sourceHash(T.Dependencies memory d, T.SourceFacts memory f, bytes32 family)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                F.sourceDomain(family, true), d.chainId, address(this), d.targets, d.codeHashes, f
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
        S.Receipt memory receipt,
        bytes32 family
    ) private view returns (S.Source memory f) {
        S.Source memory value = SnapshotWorker.read(d, source, original, receipt, family);
        // Public library arguments are copied. Preserve the prior internal publication mutation;
        // the worker still normalizes a separate receipt copy, leaving the original receipt intact.
        original.expectedSourceHash = 0;
        return value;
    }

    function _root(
        T.Dependencies memory d,
        S.Dependencies memory source,
        T.Publication memory p,
        bytes32 outputManifestRecord,
        T.SourceFacts memory f,
        bytes32 family
    ) private view {
        (f.contentRootRecordHash, f.contentRoot, f.contentRootBinding) =
            RootWorker.read(
                d, source, p.scope, outputManifestRecord, f.snapshotSource, f.snapshot, family
            );
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
