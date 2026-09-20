// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPolicyReferenceTypesV2 as T
} from "../../interfaces/stream/preservation/StreamPolicyReferenceTypesV2.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamPolicySnapshotTypesV2 as S
} from "../../interfaces/stream/metadata/StreamPolicySnapshotTypesV2.sol";
import {
    IStreamPolicySnapshotPublicationV2 as Snap
} from "../../interfaces/stream/metadata/IStreamPolicySnapshotPublicationV2.sol";
import {
    IStreamContentRootPublication as Root
} from "../../interfaces/stream/metadata/IStreamContentRootPublication.sol";
import {
    IStreamExternalArtifactCoverage as Archive
} from "../../interfaces/stream/preservation/IStreamExternalArtifactCoverage.sol";
import {
    IStreamExternalArtifactCurrentPair
} from "../../interfaces/stream/preservation/IStreamExternalArtifactCurrentPair.sol";
import {
    StreamFinalityPolicySnapshotReadsV2 as SnapRead
} from "../finality/StreamFinalityPolicySnapshotReadsV2.sol";
import {
    StreamFinalityRouterEvidence as Reads
} from "../finality/StreamFinalityRouterEvidence.sol";
import {
    StreamPolicyReferenceSampleReadsV2 as Samples
} from "./StreamPolicyReferenceSampleReadsV2.sol";
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
library StreamPolicyReferenceSourceReadsV2 {
    function subject(T.Dependencies memory d, StreamFinalityScope memory scope)
        internal
        pure
        returns (bytes32)
    {
        if (
            scope.scopeType != StreamFinalityScopeType.COLLECTION || scope.collectionId == 0
                || scope.tokenId != 0 || scope.scopeId != 0
        ) revert T.InvalidPolicyReference();
        return StreamMetadataSubjects.scopeSubject(d.chainId, d.targets[0], scope);
    }

    /// @notice Exact constructor graph. Current selection/source eligibility is checked on use.
    function bindings(T.Dependencies memory d) public view returns (S.Dependencies memory source) {
        if (
            d.chainId != block.chainid || d.readGas < 50000 || d.sourceGas < d.readGas
                || d.snapshotGas < d.sourceGas || d.archiveGas < d.readGas
        ) revert T.InvalidPolicyReference();
        for (uint256 i; i < 7; ++i) {
            if (d.targets[i].code.length == 0 || d.targets[i].codehash != d.codeHashes[i]) {
                revert T.PolicyReferenceDependency(d.targets[i]);
            }
        }
        bytes memory raw =
            Reads.read(d.targets[5], abi.encodeCall(Snap.dependencies, ()), 832, d.readGas);
        source = abi.decode(raw, (S.Dependencies));
        _canonical(d.targets[5], raw, abi.encode(source));
        if (source.chainId != d.chainId) revert T.InvalidPolicyReference();
        for (uint256 i; i < 5; ++i) {
            if (source.targets[i] != d.targets[i] || source.codeHashes[i] != d.codeHashes[i]) {
                revert T.PolicyReferenceDependency(d.targets[5]);
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
            revert T.PolicyReferenceDependency(d.targets[6]);
        }
    }

    function requireSource(T.Dependencies memory d, T.Publication memory p, bool current)
        public
        view
        returns (T.SourceFacts memory f)
    {
        f.scopeSubject = subject(d, p.scope);
        if (p.observation.collectionId != p.scope.collectionId) revert T.InvalidPolicyReference();
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
        SnapRead.Evidence memory snapshot = SnapRead.requireCurrent(
            reader, p.scope, p.observation.snapshotRecordHash, p.observation.snapshotRevision
        );
        bytes memory raw = Reads.dynamicRead(
            d.targets[5],
            abi.encodeCall(Snap.snapshotRecord, (p.observation.snapshotRecordHash)),
            4096,
            d.readGas
        );
        (S.Publication memory original, S.Receipt memory receipt) =
            abi.decode(raw, (S.Publication, S.Receipt));
        _canonical(d.targets[5], raw, abi.encode(original, receipt));
        if (keccak256(abi.encode(receipt)) != keccak256(abi.encode(snapshot.receipt))) {
            revert T.InvalidPolicyReference();
        }
        f.snapshot = receipt;
        f.snapshotSource = _snapshot(d, source, original, receipt);
        f.contentRootRecordHash = original.contentRootRecord;
        f.contentRoot = f.snapshotSource.root;
        if (
            abi.decode(
                    Reads.read(
                        d.targets[4],
                        abi.encodeCall(Root.collectionContentRootHead, (p.scope.collectionId)),
                        32,
                        d.readGas
                    ),
                    (bytes32)
                ) != original.contentRootRecord
        ) revert T.InvalidPolicyReference();
        uint256 count = f.snapshotSource.membership.tokenCount;
        if (
            count == 0 || count > type(uint64).max
                || p.observation.captures.length != (count == 1 ? 1 : 2)
        ) revert T.InvalidPolicyReference();
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
                revert T.InvalidPolicyReference();
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
                keccak256("6529STREAM_POLICY_REFERENCE_SOURCES_V2"),
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
            revert T.InvalidPolicyReference();
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
            domain != keccak256("6529STREAM_POLICY_SNAPSHOT_PAYLOAD_V2") || chain != d.chainId
                || host != d.targets[5]
                || keccak256(abi.encode(targets, hashes))
                    != keccak256(abi.encode(source.targets, source.codeHashes))
                || keccak256(abi.encode(p)) != keccak256(abi.encode(original))
                || keccak256(abi.encode(fields)) != keccak256(abi.encode(receipt))
                || keccak256(abi.encode(value.scope)) != keccak256(abi.encode(p.scope))
                || fields.sourceHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_POLICY_SNAPSHOT_SOURCES_V2"),
                            chain,
                            host,
                            targets,
                            hashes,
                            value
                        )
                    )
        ) revert T.InvalidPolicyReference();
        f = value;
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
        ) revert T.InvalidPolicyReference();
    }

    function _canonical(address target, bytes memory raw, bytes memory encoded) private pure {
        if (keccak256(raw) != keccak256(encoded)) revert T.PolicyReferenceDependency(target);
    }
}
