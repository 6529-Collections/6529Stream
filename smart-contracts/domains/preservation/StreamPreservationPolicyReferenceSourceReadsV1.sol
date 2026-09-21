// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyReferenceDependencyReadsV1 as DependencyReads
} from "./StreamPreservationPolicyReferenceDependencyReadsV1.sol";
import {
    StreamPreservationPolicyReferenceSnapshotPayloadReadsV1 as SnapshotPayloadReads
} from "./StreamPreservationPolicyReferenceSnapshotPayloadReadsV1.sol";
import {
    StreamPreservationPolicyReferenceFamiliesV2 as F
} from "./StreamPreservationPolicyReferenceFamiliesV2.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Profiles
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";

import {
    StreamPreservationPolicyReferenceTypesV1 as T
} from "../../interfaces/stream/preservation/StreamPreservationPolicyReferenceTypesV1.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamPreservationPolicySnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamPreservationPolicySnapshotTypesV1.sol";
import {
    IStreamPreservationPolicySnapshotPublicationV1 as Snap
} from "../../interfaces/stream/metadata/IStreamPreservationPolicySnapshotPublicationV1.sol";
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
    StreamFinalityPreservationPolicySnapshotReadsV1 as SnapRead
} from "../finality/StreamFinalityPreservationPolicySnapshotReadsV1.sol";
import {
    StreamFinalityRouterEvidence as Reads
} from "../finality/StreamFinalityRouterEvidence.sol";
import {
    StreamPreservationPolicyReferenceSampleReadsV1 as Samples
} from "./StreamPreservationPolicyReferenceSampleReadsV1.sol";
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
library StreamPreservationPolicyReferenceSourceReadsV1 {
    // Retain the original ABI for errors propagated by fixed linked workers.
    error InvalidPreservationReferenceFamily();
    error PolicyReferenceDependency(address target);

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
        return bindings(d, Profiles.ORIGINAL_PROFILE);
    }

    function bindings(T.Dependencies memory d, bytes32 family)
        public
        view
        returns (S.Dependencies memory source)
    {
        return DependencyReads.bindings(d, family);
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
        if (p.observation.collectionId != p.scope.collectionId) revert T.InvalidPolicyReference();
        S.Dependencies memory source = bindings(d, family);
        (f.snapshot, f.snapshotSource, f.contentRootRecordHash) = SnapshotPayloadReads.readFacts(
            d,
            source,
            p.scope,
            p.observation.snapshotRecordHash,
            p.observation.snapshotRevision,
            family
        );
        f.contentRoot = f.snapshotSource.root;
        f.contentRootBinding = f.snapshotSource.rootBinding;
        if (
            abi.decode(
                    Reads.read(
                        d.targets[4],
                        abi.encodeCall(Root.collectionContentRootHead, (p.scope.collectionId)),
                        32,
                        d.readGas
                    ),
                    (bytes32)
                ) != f.contentRootRecordHash
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
                F.sourceDomain(family, false), d.chainId, address(this), d.targets, d.codeHashes, f
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
        f = SnapshotPayloadReads.snapshot(d, source, original, receipt, family);
        // A linked call copies memory. Retain the original internal caller-visible normalization.
        original.expectedSourceHash = 0;
    }

    function _runtime(R.Dependencies memory d, E.Coverage memory e) private view {
        DependencyReads.requireRuntime(d, e);
    }

    function _canonical(address target, bytes memory raw, bytes memory encoded) private pure {
        if (keccak256(raw) != keccak256(encoded)) revert T.PolicyReferenceDependency(target);
    }
}
