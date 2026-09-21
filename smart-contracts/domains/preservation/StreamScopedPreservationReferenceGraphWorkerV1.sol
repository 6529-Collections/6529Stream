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

/// @notice Fixed original dependency graph checks; no source admission or state.
library StreamScopedPreservationReferenceGraphWorkerV1 {
    function read(T.Dependencies memory d, bytes32 family)
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

    function _canonical(address target, bytes memory raw, bytes memory encoded) private pure {
        if (keccak256(raw) != keccak256(encoded)) revert T.ScopedPolicyReferenceDependency(target);
    }
}
