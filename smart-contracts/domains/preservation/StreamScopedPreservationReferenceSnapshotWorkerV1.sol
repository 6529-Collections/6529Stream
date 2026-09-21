// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamPreservationPolicyReferenceFamiliesV2 as F
} from "./StreamPreservationPolicyReferenceFamiliesV2.sol";
import {
    StreamScopedPreservationPolicyReferenceTypesV1 as T
} from "../../interfaces/stream/preservation/StreamScopedPreservationPolicyReferenceTypesV1.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    IStreamScopedPreservationPolicySnapshotPublicationV1 as Snap
} from "../../interfaces/stream/metadata/IStreamScopedPreservationPolicySnapshotPublicationV1.sol";
import {
    StreamFinalityRouterEvidence as Reads
} from "../finality/StreamFinalityRouterEvidence.sol";

/// @notice Fixed original scoped snapshot payload validation for reference sources.
library StreamScopedPreservationReferenceSnapshotWorkerV1 {
    function read(
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
            revert T.InvalidScopedPolicyReference();
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
                            ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_PAYLOAD_V2")
                            : keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_PAYLOAD_V1"))
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
                                        "6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_SOURCES_V2"
                                    )
                                    : keccak256(
                                        "6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_SOURCES_V1"
                                    )),
                            chain,
                            host,
                            targets,
                            hashes,
                            value
                        )
                    )
        ) revert T.InvalidScopedPolicyReference();
        f = value;
    }

    function _canonical(address target, bytes memory raw, bytes memory encoded) private pure {
        if (keccak256(raw) != keccak256(encoded)) revert T.ScopedPolicyReferenceDependency(target);
    }
}
