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
/// @dev Fixed linked snapshot-payload decoder; retains the complete canonical read and hash checks.
library StreamPreservationPolicyReferenceSnapshotPayloadReadsV1 {
    function readFacts(
        T.Dependencies memory d,
        S.Dependencies memory source,
        StreamFinalityScope memory scope,
        bytes32 recordHash,
        uint64 revision,
        bytes32 family
    ) public view returns (S.Receipt memory savedReceipt, S.Source memory sourceFacts, bytes32 contentRootRecord) {
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
        SnapRead.Evidence memory currentSnapshot = SnapRead.requireCurrent(
            reader,
            scope,
            recordHash,
            revision,
            family
        );
        bytes memory raw = Reads.dynamicRead(
            d.targets[5],
            abi.encodeCall(Snap.snapshotRecord, (recordHash)),
            4096,
            d.readGas
        );
        (S.Publication memory original, S.Receipt memory receipt) =
            abi.decode(raw, (S.Publication, S.Receipt));
        _canonical(d.targets[5], raw, abi.encode(original, receipt));
        if (keccak256(abi.encode(receipt)) != keccak256(abi.encode(currentSnapshot.receipt))) {
            revert T.InvalidPolicyReference();
        }
        savedReceipt = receipt;
        sourceFacts = snapshot(d, source, original, receipt, family);
        contentRootRecord = original.contentRootRecord;
    }

    function snapshot(
        T.Dependencies memory d,
        S.Dependencies memory source,
        S.Publication memory original,
        S.Receipt memory receipt,
        bytes32 family
    ) public view returns (S.Source memory f) {
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
            domain
                    != (F.isV2(family)
                            ? keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_PAYLOAD_V2")
                            : keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_PAYLOAD_V1"))
                || chain != d.chainId || host != d.targets[5]
                || keccak256(abi.encode(targets, hashes))
                    != keccak256(abi.encode(source.targets, source.codeHashes))
                || keccak256(abi.encode(p)) != keccak256(abi.encode(original))
                || keccak256(abi.encode(fields)) != keccak256(abi.encode(receipt))
                || keccak256(abi.encode(value.scope)) != keccak256(abi.encode(p.scope))
                || fields.sourceHash
                    != keccak256(
                        abi.encode(
                            (F.isV2(family)
                                    ? keccak256(
                                        "6529STREAM_PRESERVATION_POLICY_SNAPSHOT_SOURCES_V2"
                                    )
                                    : keccak256(
                                            "6529STREAM_PRESERVATION_POLICY_SNAPSHOT_SOURCES_V1"
                                        )),
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

    function _canonical(address target, bytes memory raw, bytes memory encoded) private pure {
        if (keccak256(raw) != keccak256(encoded)) revert T.PolicyReferenceDependency(target);
    }
}
