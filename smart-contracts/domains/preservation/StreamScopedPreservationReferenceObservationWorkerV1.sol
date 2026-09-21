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

/// @notice Fixed environment and first/last sample joins after the original snapshot/root checks.
/// @dev Returns all formerly assigned SourceFacts fields; no storage or alternate targets.
library StreamScopedPreservationReferenceObservationWorkerV1 {
    function read(
        T.Dependencies memory d,
        S.Dependencies memory source,
        T.Publication memory p,
        S.Source memory snapshotSource,
        bool current,
        bytes32 family
    ) public view returns (E.Coverage memory environmentCoverage, T.Sample[] memory samples) {
        uint256 count = snapshotSource.membership.tokenCount;
        if (
            count == 0 || count > type(uint64).max
                || p.observation.captures.length != (count == 1 ? 1 : 2)
        ) revert T.InvalidScopedPolicyReference();
        R.Dependencies memory archive = archiveDependencies(d);
        environmentCoverage = Archives.coverage(
            archive,
            p.observation.environment.coverageHash,
            snapshotSource.artist.artistId,
            p.observation.environment.objectHash,
            current
        );
        _runtime(archive, environmentCoverage);
        samples = new T.Sample[](p.observation.captures.length);
        for (uint256 i; i < samples.length; ++i) {
            if (
                p.observation.captures[i].environmentManifestHash
                    != p.observation.environment.manifestHash
            ) {
                revert T.InvalidScopedPolicyReference();
            }
            samples[i] = Samples.requireSample(
                d,
                source,
                p.scope,
                snapshotSource,
                uint64(i == 0 ? 0 : count - 1),
                p.observation.captures[i],
                current,
                family
            );
        }
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
