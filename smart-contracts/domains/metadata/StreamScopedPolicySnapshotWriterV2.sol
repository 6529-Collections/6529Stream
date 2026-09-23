// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamScopedPolicySnapshotTypesV2 as S
} from "../../interfaces/stream/metadata/StreamScopedPolicySnapshotTypesV2.sol";

import { StreamSnapshotManifestBytes as Bytes } from "../records/StreamSnapshotManifestBytes.sol";

/// @notice Fixed linked operations retain the original host storage and domains.
library StreamScopedPolicySnapshotWriterV2 {
    event ScopedPolicySnapshotPublished(
        uint16 schemaVersion,
        bytes32 indexed scopeSubject,
        bytes32 indexed snapshotId,
        bytes32 indexed recordHash,
        S.Publication publication,
        S.Receipt receipt
    );

    function publish(
        mapping(bytes32 => S.Publication) storage _publications,
        mapping(bytes32 => S.Receipt) storage _receipts,
        mapping(bytes32 => Bytes.Manifest) storage _payloads,
        mapping(bytes32 => mapping(bytes32 => bytes32)) storage _ids,
        mapping(bytes32 => bytes32[]) storage _history,
        S.Dependencies memory _fixed,
        address core,
        address metadataHost,
        S.Publication calldata p,
        S.Receipt memory r,
        bytes memory canonical
    ) public returns (bytes32 hash) {
        if (p.expectedSourceHash == 0 || p.expectedSourceHash != r.sourceHash) {
            revert S.InvalidScopedPolicySnapshot();
        }
        r.manifestHash = keccak256(canonical);
        r.manifestBytes = uint32(canonical.length);
        r.recordedAt = uint64(block.timestamp);
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_RECORD_V2"),
                _fixed.chainId,
                address(this),
                core,
                metadataHost,
                p,
                r
            )
        );
        r.recordHash = hash;
        r.chainHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_CHAIN_V2"),
                _fixed.chainId,
                address(this),
                core,
                p.scope,
                _receipts[p.expectedHead].chainHash,
                r.revision,
                hash
            )
        );
        // The fixed Store cannot call back into the writer. Its immutable bytes grant no authority.
        Bytes.retain(_payloads[hash], _fixed.targets[3], canonical);
        _publications[hash] = p;
        _receipts[hash] = r;
        _ids[r.scopeSubject][p.snapshotId] = hash;
        _history[r.scopeSubject].push(hash);
        emit ScopedPolicySnapshotPublished(2, r.scopeSubject, p.snapshotId, hash, p, r);
    }
}
