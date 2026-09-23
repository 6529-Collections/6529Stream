// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityScopedPolicySnapshotReadsV2 as SnapshotReads
} from "./StreamFinalityScopedPolicySnapshotReadsV2.sol";
import { StreamFinalityRouterEvidence as Reads } from "./StreamFinalityRouterEvidence.sol";
import { StreamMetadataSubjects } from "../metadata/StreamMetadataSubjects.sol";
import {
    IStreamScopedContentRootPublication as Root
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamScopedPolicySnapshotPublicationV2 as Snapshot
} from "../../interfaces/stream/metadata/IStreamScopedPolicySnapshotPublicationV2.sol";
import {
    StreamScopedPolicySnapshotTypesV2 as S
} from "../../interfaces/stream/metadata/StreamScopedPolicySnapshotTypesV2.sol";
import "../../interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

import {
    IStreamScopedPolicyContentRootPublicationV2 as RootV2
} from "../../interfaces/stream/metadata/IStreamScopedPolicyContentRootPublicationV2.sol";
import {
    IStreamScopedPolicyOutputManifestV2 as Outputs
} from "../../interfaces/stream/finality/IStreamScopedPolicyOutputManifestV2.sol";
import {
    StreamScopedPolicyContentRootSchemasV2 as RootSchemas
} from "./StreamScopedPolicyContentRootSchemasV2.sol";
import {
    StreamScopedPolicyOutputSchemasV2 as OutputSchemas
} from "./StreamScopedPolicyOutputSchemasV2.sol";
import {
    IStreamFinalityScopedEntropyPolicySourceFactoryV2 as Factory
} from "../../interfaces/stream/finality/IStreamFinalityScopedEntropyPolicySourceFactoryV2.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as Policies
} from "./StreamFinalityCoordinatorPolicyReadsV2.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";

import {
    StreamFinalityScopedPolicyProviderMetadataV2 as M
} from "./StreamFinalityScopedPolicyProviderMetadataV2.sol";

/// @notice Fixed full-policy payload reader in the calling provider's delegate context.
library StreamFinalityScopedPolicyMetadataPayloadV2 {
    function read(
        M.Config memory c,
        S.Dependencies memory source,
        S.Publication memory original,
        S.Receipt memory receipt
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
            domain != keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_PAYLOAD_V2")
                || chain != c.snapshots.chainId || host != c.snapshots.snapshots
                || keccak256(abi.encode(targets, hashes))
                    != keccak256(abi.encode(source.targets, source.codeHashes))
                || keccak256(abi.encode(p)) != keccak256(abi.encode(original))
                || keccak256(abi.encode(fields)) != keccak256(abi.encode(receipt))
                || keccak256(abi.encode(value.scope)) != keccak256(abi.encode(p.scope))
                || fields.sourceHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_SOURCES_V2"),
                            chain,
                            host,
                            targets,
                            hashes,
                            value
                        )
                    )
        ) revert M.InvalidScopedProviderMetadata();
        f = value;
    }

    function _canonical(bytes memory raw, bytes memory encoded) private pure {
        if (keccak256(raw) != keccak256(encoded)) revert M.InvalidScopedProviderMetadata();
    }
}
