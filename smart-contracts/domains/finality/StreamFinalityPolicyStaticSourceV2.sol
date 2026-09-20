// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamFinalityPolicySnapshotReadsV2 as SnapshotReads
} from "./StreamFinalityPolicySnapshotReadsV2.sol";
import { StreamFinalityRouterEvidence as Reads } from "./StreamFinalityRouterEvidence.sol";
import {
    StreamPolicySnapshotTypesV2 as S
} from "../../interfaces/stream/metadata/StreamPolicySnapshotTypesV2.sol";
import {
    IStreamPolicySnapshotPublicationV2 as Snapshot
} from "../../interfaces/stream/metadata/IStreamPolicySnapshotPublicationV2.sol";
import {
    StreamFinalityScope
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamPolicySnapshotDefinitionsV2 as Definitions
} from "../records/StreamPolicySnapshotDefinitionsV2.sol";

/// @notice Closed current COLLECTION V2 source projection for the combined provider's STATIC components.
/// @dev No reference, inventory, finality manifest, or component-array read occurs here. The caller
/// supplies its immutable snapshot/Core/Metadata/Router pins, never a user-selected projection.
/// The separate fixed STATIC component worker still verifies every selected row and frozen source.
library StreamFinalityPolicyStaticSourceV2 {
    struct Projection {
        address selection;
        bytes32 selectionCodeHash;
        StreamFinalityScope scope;
        bytes32 sourceProfile;
        bytes32 selectionId;
        bytes32 membershipHash;
        bytes32 selectionRoot;
        uint64 tokenCount;
        bytes32 lockedArtistSnapshotHash;
        bytes32 snapshotRecordHash;
        bytes32 snapshotSourceHash;
        bytes32 contentRootRecordHash;
    }

    error InvalidPolicyStaticSource();

    function current(
        SnapshotReads.Dependencies memory d,
        address router,
        bytes32 routerCodeHash,
        StreamFinalityScope memory scope
    ) public view returns (Projection memory result) {
        _pin(router, routerCodeHash);
        bytes memory raw = Reads.read(
            d.snapshots, abi.encodeCall(Snapshot.currentSnapshot, (scope)), 544, d.readGas
        );
        S.Receipt memory receipt = abi.decode(raw, (S.Receipt));
        _canonical(raw, abi.encode(receipt));
        SnapshotReads.Evidence memory current_ =
            SnapshotReads.requireCurrent(d, scope, receipt.recordHash, receipt.revision);
        _canonical(raw, abi.encode(current_.receipt));
        raw = Reads.read(d.snapshots, abi.encodeCall(Snapshot.dependencies, ()), 832, d.readGas);
        S.Dependencies memory source = abi.decode(raw, (S.Dependencies));
        _canonical(raw, abi.encode(source));
        if (
            source.chainId != d.chainId || source.targets[0] != d.core
                || source.targets[1] != d.metadata || source.targets[4] != router
                || source.codeHashes[0] != d.coreCodeHash
                || source.codeHashes[1] != d.metadataCodeHash
                || source.codeHashes[4] != routerCodeHash
        ) revert InvalidPolicyStaticSource();
        for (uint256 i; i < 11; ++i) {
            _pin(source.targets[i], source.codeHashes[i]);
        }
        raw = Reads.dynamicRead(
            d.snapshots,
            abi.encodeCall(Snapshot.snapshotRecord, (receipt.recordHash)),
            4096,
            d.readGas
        );
        (S.Publication memory original, S.Receipt memory saved) =
            abi.decode(raw, (S.Publication, S.Receipt));
        _canonical(raw, abi.encode(original, saved));
        if (keccak256(abi.encode(saved)) != keccak256(abi.encode(receipt))) {
            revert InvalidPolicyStaticSource();
        }
        S.Source memory facts = _payload(d, source, original, receipt);
        if (
            original.contentRootRecord != current_.contentRootRecord
                || facts.root.publication.verifiedManifestRecordHash
                    != current_.outputManifestRecord || facts.outputs.checkpointHash == 0
                || facts.content.selectionId == 0 || facts.selection.tokenCount == 0
                || facts.selection.nextIndex != facts.selection.tokenCount || !facts.artist.locked
                || facts.artist.snapshotHash == 0 || receipt.profileHash != Definitions.PROFILE_HASH
        ) revert InvalidPolicyStaticSource();
        result = Projection(
            source.targets[6],
            source.codeHashes[6],
            scope,
            receipt.profileHash,
            facts.content.selectionId,
            facts.selection.membershipHash,
            facts.selection.selectionRoot,
            facts.selection.tokenCount,
            facts.artist.snapshotHash,
            receipt.recordHash,
            receipt.sourceHash,
            current_.contentRootRecord
        );
    }

    function _payload(
        SnapshotReads.Dependencies memory d,
        S.Dependencies memory source,
        S.Publication memory original,
        S.Receipt memory receipt
    ) private view returns (S.Source memory facts) {
        bytes memory out = Reads.dynamicRead(
            d.snapshots,
            abi.encodeCall(Snapshot.snapshotPayload, (receipt.recordHash)),
            receipt.manifestBytes + 96,
            d.validationGas
        );
        bytes memory raw = abi.decode(out, (bytes));
        _canonical(out, abi.encode(raw));
        if (raw.length != receipt.manifestBytes || keccak256(raw) != receipt.manifestHash) {
            revert InvalidPolicyStaticSource();
        }
        (
            bytes32 domain,
            uint256 chain,
            address host,
            address[11] memory targets,
            bytes32[11] memory hashes,
            S.Publication memory publication,
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
            raw, abi.encode(domain, chain, host, targets, hashes, publication, fields, value)
        );
        // Preserve the caller's authenticated receipt while matching the original five zero fields.
        receipt = abi.decode(abi.encode(receipt), (S.Receipt));
        original.expectedSourceHash = 0;
        receipt.recordHash = 0;
        receipt.chainHash = 0;
        receipt.manifestHash = 0;
        receipt.manifestBytes = 0;
        receipt.recordedAt = 0;
        if (
            domain != keccak256("6529STREAM_POLICY_SNAPSHOT_PAYLOAD_V2") || chain != d.chainId
                || host != d.snapshots
                || keccak256(abi.encode(targets, hashes))
                    != keccak256(abi.encode(source.targets, source.codeHashes))
                || keccak256(abi.encode(publication)) != keccak256(abi.encode(original))
                || keccak256(abi.encode(fields)) != keccak256(abi.encode(receipt))
                || keccak256(abi.encode(value.scope)) != keccak256(abi.encode(publication.scope))
                || fields.sourceHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_POLICY_SNAPSHOT_SOURCES_V2"),
                            chain,
                            host,
                            targets,
                            hashes,
                            value
                        )
                    )
        ) revert InvalidPolicyStaticSource();
        facts = value;
    }

    function _pin(address target, bytes32 hash) private view {
        if (target.code.length == 0 || hash == 0 || target.codehash != hash) {
            revert InvalidPolicyStaticSource();
        }
    }

    function _canonical(bytes memory a, bytes memory b) private pure {
        if (a.length != b.length || keccak256(a) != keccak256(b)) {
            revert InvalidPolicyStaticSource();
        }
    }
}
