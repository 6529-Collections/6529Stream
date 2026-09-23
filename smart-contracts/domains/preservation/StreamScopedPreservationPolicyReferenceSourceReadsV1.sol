// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamScopedPreservationReferenceGraphWorkerV1 as GraphWorker
} from "./StreamScopedPreservationReferenceGraphWorkerV1.sol";
import {
    StreamScopedPreservationReferenceObservationWorkerV1 as ObservationWorker
} from "./StreamScopedPreservationReferenceObservationWorkerV1.sol";
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
    error InvalidPreservationReferenceFamily();
    error InvalidPreservationRootFamily();
    // Preserve the original dependency/read error surface after fixed-worker extraction.
    error RouterEvidenceGas(uint256 available, uint256 required);
    error RouterEvidenceRead(address target, bytes4 selector);
    error ScopedPolicyReferenceDependency(address target);

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
        return GraphWorker.read(d, family);
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
        bytes32 outputManifestRecord;
        (f.snapshot, f.snapshotSource, outputManifestRecord) = SnapshotWorker.capture(
            d,
            source,
            p.scope,
            p.observation.snapshotRecordHash,
            p.observation.snapshotRevision,
            family
        );
        _root(d, source, p, outputManifestRecord, f, family);
        (f.environmentCoverage, f.samples) =
            ObservationWorker.read(d, source, p, f.snapshotSource, current, family);
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
}
