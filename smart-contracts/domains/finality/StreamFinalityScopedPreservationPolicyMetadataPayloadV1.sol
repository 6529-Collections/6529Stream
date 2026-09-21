// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationTokenProducerProfilesV1 as Producers
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    StreamPreservationPolicySnapshotFamiliesV2 as SnapshotFamilies
} from "../records/StreamPreservationPolicySnapshotFamiliesV2.sol";
import {
    StreamPreservationPolicyRootFamiliesV2 as RootFamilies
} from "./StreamPreservationPolicyRootFamiliesV2.sol";

import {
    StreamFinalityScopedPreservationPolicySnapshotReadsV1 as SnapshotReads
} from "./StreamFinalityScopedPreservationPolicySnapshotReadsV1.sol";
import { StreamFinalityRouterEvidence as Reads } from "./StreamFinalityRouterEvidence.sol";
import { StreamMetadataSubjects } from "../metadata/StreamMetadataSubjects.sol";
import {
    IStreamScopedContentRootPublication as Root
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamScopedPreservationPolicySnapshotPublicationV1 as Snapshot
} from "../../interfaces/stream/metadata/IStreamScopedPreservationPolicySnapshotPublicationV1.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import "../../interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

import {
    IStreamScopedPreservationPolicyContentRootPublicationV1 as PreservationRoot
} from "../../interfaces/stream/metadata/IStreamScopedPreservationPolicyContentRootPublicationV1.sol";
import {
    IStreamPreservationPolicyOutputManifestV1 as Outputs
} from "../../interfaces/stream/finality/IStreamPreservationPolicyOutputManifestV1.sol";
import {
    StreamScopedPreservationPolicyContentRootSchemasV1 as RootSchemas
} from "./StreamScopedPreservationPolicyContentRootSchemasV1.sol";
import {
    StreamPreservationPolicyOutputSchemasV1 as OutputSchemas
} from "./StreamPreservationPolicyOutputSchemasV1.sol";
import {
    IStreamFinalityScopedEntropyPolicySourceFactoryV2 as Factory
} from "../../interfaces/stream/finality/IStreamFinalityScopedEntropyPolicySourceFactoryV2.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as Policies
} from "./StreamFinalityCoordinatorPolicyReadsV2.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";

import {
    StreamFinalityScopedPreservationPolicyProviderMetadataV1 as M
} from "./StreamFinalityScopedPreservationPolicyProviderMetadataV1.sol";

/// @notice Fixed full payload reader; called only with the provider's authenticated context.
library StreamFinalityScopedPreservationPolicyMetadataPayloadV1 {
    function read(
        M.Config memory c,
        S.Dependencies memory source,
        S.Publication memory original,
        S.Receipt memory receipt,
        bytes32 preservationFamily
    ) public view returns (S.Source memory f) {
        bytes memory out = Reads.dynamicRead(
            c.snapshots.snapshots,
            abi.encodeCall(Snapshot.snapshotPayload, (receipt.recordHash)),
            receipt.manifestBytes + 96,
            c.snapshots.validationGas
        );
        bytes memory raw = abi.decode(out, (bytes));
        _canonical(out, abi.encode(raw));
        if (raw.length != receipt.manifestBytes || keccak256(raw) != receipt.manifestHash) {
            revert M.InvalidScopedProviderMetadata();
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
        _canonical(raw, abi.encode(domain, chain, host, targets, hashes, p, fields, value));
        // The caller retains the original receipt for the root/source join below.
        receipt = abi.decode(abi.encode(receipt), (S.Receipt));
        original.expectedSourceHash = 0;
        receipt.recordHash = 0;
        receipt.chainHash = 0;
        receipt.manifestHash = 0;
        receipt.manifestBytes = 0;
        receipt.recordedAt = 0;
        if (
            domain != SnapshotFamilies.payloadDomain(preservationFamily, true)
                || chain != c.snapshots.chainId || host != c.snapshots.snapshots
                || keccak256(abi.encode(targets, hashes))
                    != keccak256(abi.encode(source.targets, source.codeHashes))
                || keccak256(abi.encode(p)) != keccak256(abi.encode(original))
                || keccak256(abi.encode(fields)) != keccak256(abi.encode(receipt))
                || keccak256(abi.encode(value.scope)) != keccak256(abi.encode(p.scope))
                || fields.sourceHash
                    != keccak256(
                        abi.encode(
                            SnapshotFamilies.sourcesDomain(preservationFamily, true),
                            chain,
                            host,
                            targets,
                            hashes,
                            value
                        )
                    )
        ) revert M.InvalidScopedProviderMetadata();
        if (
            value.outputs.metadataRouter != c.snapshots.router
                || value.outputs.preservationProfile != preservationFamily
                || value.content.preservationProfile != value.outputs.preservationProfile
        ) revert M.InvalidScopedProviderMetadata();
        f = value;
    }

    function _canonical(bytes memory raw, bytes memory encoded) private pure {
        if (keccak256(raw) != keccak256(encoded)) revert M.InvalidScopedProviderMetadata();
    }
}
