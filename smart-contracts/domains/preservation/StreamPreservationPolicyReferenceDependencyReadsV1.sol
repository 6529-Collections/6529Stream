// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
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
library StreamPreservationPolicyReferenceDependencyReadsV1 {
    function bindings(T.Dependencies memory d, bytes32 family)
        public
        view
        returns (S.Dependencies memory source)
    {
        F.isV2(family);
        if (
            d.chainId != block.chainid || d.readGas < 50000 || d.sourceGas < d.readGas
                || d.snapshotGas < d.sourceGas || d.archiveGas < d.readGas
        ) revert T.InvalidPolicyReference();
        for (uint256 i; i < 7; ++i) {
            if (d.targets[i].code.length == 0 || d.targets[i].codehash != d.codeHashes[i]) {
                revert T.PolicyReferenceDependency(d.targets[i]);
            }
        }
        if (
            abi.decode(
                        Reads.read(
                            d.targets[5],
                            abi.encodeWithSignature(
                                "supportsInterface(bytes4)", type(Snap).interfaceId
                            ),
                            32,
                            d.readGas
                        ),
                        (uint256)
                    ) != 1
                || abi.decode(
                        Reads.read(
                            d.targets[5],
                            abi.encodeCall(Snap.preservationPolicySnapshotProfile, ()),
                            32,
                            d.readGas
                        ),
                        (bytes32)
                    )
                    != (F.isV2(family)
                            ? keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_V2")
                            : keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_V1"))
        ) revert T.InvalidPolicyReference();
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

    function requireRuntime(R.Dependencies memory d, E.Coverage memory e) public view {
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
