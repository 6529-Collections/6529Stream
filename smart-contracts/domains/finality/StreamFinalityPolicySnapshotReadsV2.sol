// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import { StreamMetadataSubjects } from "../metadata/StreamMetadataSubjects.sol";
import {
    StreamPolicySnapshotTypesV2 as S
} from "../../interfaces/stream/metadata/StreamPolicySnapshotTypesV2.sol";
import {
    IStreamPolicySnapshotPublicationV2 as I
} from "../../interfaces/stream/metadata/IStreamPolicySnapshotPublicationV2.sol";
import {
    StreamPolicySnapshotDefinitionsV2 as Definitions
} from "../records/StreamPolicySnapshotDefinitionsV2.sol";
import { StreamFinalityRouterEvidence as Reads } from "./StreamFinalityRouterEvidence.sol";

/// @notice Distinct current/locked COLLECTION V2 snapshot evidence for the selected provider.
/// @dev The immutable host proves complete policy/output/current payload; this is not a V1 receipt.
library StreamFinalityPolicySnapshotReadsV2 {
    struct Dependencies {
        address core;
        address metadata;
        address snapshots;
        bytes32 coreCodeHash;
        bytes32 metadataCodeHash;
        bytes32 snapshotsCodeHash;
        uint256 chainId;
        uint256 readGas;
        uint256 validationGas;
    }

    struct Evidence {
        bytes32 inputHash;
        S.Receipt receipt;
        bytes32 contentRootRecord;
        bytes32 outputManifestRecord;
        bytes32 coordinatorInventoryPlan;
        bool locked;
        bytes32 lockHash;
    }
    error InvalidPolicySnapshotEvidence();

    function requireCurrent(
        Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 hash,
        uint64 revision
    ) public view returns (Evidence memory e) {
        if (
            d.chainId != block.chainid || d.readGas < 50000 || d.validationGas < d.readGas
                || scope.scopeType != StreamFinalityScopeType.COLLECTION || scope.collectionId == 0
                || scope.tokenId != 0 || scope.scopeId != 0 || hash == 0 || revision == 0
        ) revert InvalidPolicySnapshotEvidence();
        _pin(d.core, d.coreCodeHash);
        _pin(d.metadata, d.metadataCodeHash);
        _pin(d.snapshots, d.snapshotsCodeHash);
        if (
            _word(d, abi.encodeCall(I.core, ())) != bytes32(uint256(uint160(d.core)))
                || _word(d, abi.encodeCall(I.metadataHost, ()))
                    != bytes32(uint256(uint160(d.metadata)))
        ) revert InvalidPolicySnapshotEvidence();
        bytes memory raw = Reads.dynamicRead(
            d.snapshots, abi.encodeCall(I.snapshotRecord, (hash)), 4096, d.readGas
        );
        (S.Publication memory p, S.Receipt memory r) = abi.decode(raw, (S.Publication, S.Receipt));
        _canonical(raw, abi.encode(p, r));
        _original(d, scope, p, r, hash, revision);
        raw = Reads.read(
            d.snapshots,
            abi.encodeCall(I.requireCurrent, (scope, hash, revision)),
            544,
            d.validationGas
        );
        _canonical(raw, abi.encode(r));
        raw = Reads.read(d.snapshots, abi.encodeCall(I.snapshotLock, (scope)), 128, d.readGas);
        S.Lock memory locked = abi.decode(raw, (S.Lock));
        _canonical(raw, abi.encode(locked));
        if (locked.actionId == 0) {
            if (locked.recordHash != 0 || locked.revision != 0 || locked.lockedAt != 0) {
                revert InvalidPolicySnapshotEvidence();
            }
        } else {
            if (
                locked.recordHash != hash || locked.revision != revision
                    || locked.lockedAt < r.recordedAt
            ) revert InvalidPolicySnapshotEvidence();
            e.locked = true;
        }
        e.receipt = r;
        e.contentRootRecord = p.contentRootRecord;
        e.outputManifestRecord = p.outputManifestRecord;
        e.coordinatorInventoryPlan = p.coordinatorInventoryPlan;
        e.lockHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_POLICY_SNAPSHOT_LOCK_V2"),
                d.chainId,
                d.snapshots,
                scope,
                locked
            )
        );
        e.inputHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_POLICY_SNAPSHOT_INPUT_V2"),
                d.chainId,
                d.core,
                d.metadata,
                d.snapshots,
                d.snapshotsCodeHash,
                scope,
                e
            )
        );
    }

    function requireLocked(
        Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 hash,
        uint64 revision
    ) public view returns (Evidence memory e) {
        e = requireCurrent(d, scope, hash, revision);
        if (!e.locked) revert InvalidPolicySnapshotEvidence();
    }

    function _original(
        Dependencies memory d,
        StreamFinalityScope memory scope,
        S.Publication memory p,
        S.Receipt memory r,
        bytes32 hash,
        uint64 revision
    ) private pure {
        if (
            keccak256(abi.encode(p.scope)) != keccak256(abi.encode(scope))
                || r.scopeSubject != StreamMetadataSubjects.scopeSubject(d.chainId, d.core, scope)
                || r.recordHash != hash || r.revision != revision
                || p.expectedRevision == type(uint64).max || r.revision != p.expectedRevision + 1
                || r.predecessor != p.expectedHead || p.snapshotId == 0 || p.contentRootRecord == 0
                || p.outputManifestRecord == 0 || p.coordinatorInventoryPlan == 0
                || r.manifestHash == 0 || r.manifestBytes == 0 || r.manifestBytes > 524288
                || r.sourceHash == 0 || r.sourceHash != p.expectedSourceHash || r.chainHash == 0
                || r.publisher == address(0)
                || (r.authorizationClass != 7 && r.authorizationClass != 8)
                || (r.displayAuthorizationClass != 7 && r.displayAuthorizationClass != 8)
                || r.grantRevision == 0 || r.displayGrantRevision == 0 || r.recordedAt == 0
                || p.effectiveAt == 0 || p.effectiveAt > r.recordedAt || p.reasonHash == 0
                || bytes(p.manifestURI).length > 2048 || r.schemaHash != Definitions.SCHEMA_HASH
                || r.profileHash != Definitions.PROFILE_HASH
                || r.canonicalizationHash != Definitions.CANON_HASH
        ) revert InvalidPolicySnapshotEvidence();
        bytes32 chainHash = r.chainHash;
        r.recordHash = 0;
        r.chainHash = 0;
        if (
            keccak256(
                    abi.encode(
                        keccak256("6529STREAM_POLICY_SNAPSHOT_RECORD_V2"),
                        d.chainId,
                        d.snapshots,
                        d.core,
                        d.metadata,
                        p,
                        r
                    )
                ) != hash
        ) revert InvalidPolicySnapshotEvidence();
        // memory arguments alias: restore caller's authenticated receipt before later comparisons.
        r.recordHash = hash;
        r.chainHash = chainHash;
    }

    function _word(Dependencies memory d, bytes memory input) private view returns (bytes32) {
        return abi.decode(Reads.read(d.snapshots, input, 32, d.readGas), (bytes32));
    }

    function _pin(address target, bytes32 hash) private view {
        if (target.code.length == 0 || hash == 0 || target.codehash != hash) {
            revert InvalidPolicySnapshotEvidence();
        }
    }

    function _canonical(bytes memory a, bytes memory b) private pure {
        if (a.length != b.length || keccak256(a) != keccak256(b)) {
            revert InvalidPolicySnapshotEvidence();
        }
    }
}
