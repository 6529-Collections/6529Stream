// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamScopedPreservationPolicySnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    IStreamScopedPreservationPolicySnapshotPublicationV1 as Snapshot
} from "../../interfaces/stream/metadata/IStreamScopedPreservationPolicySnapshotPublicationV1.sol";
import {
    StreamScopedPreservationPolicySnapshotDefinitionsV1 as Definitions
} from "../records/StreamScopedPreservationPolicySnapshotDefinitionsV1.sol";
import { StreamMetadataSubjects } from "../metadata/StreamMetadataSubjects.sol";
import { StreamFinalityRouterEvidence as Reads } from "./StreamFinalityRouterEvidence.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import "../../interfaces/stream/finality/StreamFinalitySnapshotTypes.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @notice Current scoped preservation snapshot evidence from the distinct pinned producer.
/// @dev COLLECTION remains on its original reader. Snapshot evidence is not Artist root authority,
/// complete output-byte preservation, a reference acceptance mode, or aggregate finality readiness.
library StreamFinalityScopedPreservationPolicySnapshotReadsV1 {
    struct Dependencies {
        address core;
        address metadata;
        address router;
        address snapshots;
        bytes32 coreCodeHash;
        bytes32 metadataCodeHash;
        bytes32 routerCodeHash;
        bytes32 snapshotsCodeHash;
        uint256 chainId;
        uint256 readGas;
        uint256 validationGas;
    }

    error InvalidScopedPreservationPolicySnapshotEvidence();

    function requireCurrent(
        Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 recordHash,
        uint64 revision
    ) public view returns (StreamFinalitySnapshotEvidence memory e) {
        (S.Publication memory p, S.Receipt memory r) = original(d, scope, recordHash, revision);
        bytes memory raw = Reads.read(
            d.snapshots,
            abi.encodeCall(Snapshot.requireCurrent, (scope, recordHash, revision)),
            544,
            d.validationGas
        );
        if (keccak256(raw) != keccak256(abi.encode(r))) {
            revert InvalidScopedPreservationPolicySnapshotEvidence();
        }
        raw = Reads.read(
            d.snapshots, abi.encodeCall(Snapshot.snapshotLock, (scope)), 128, d.readGas
        );
        S.Lock memory lock_ = abi.decode(raw, (S.Lock));
        _canonical(raw, abi.encode(lock_));
        bool locked = lock_.actionId != 0;
        if (locked) {
            if (
                lock_.recordHash != recordHash || lock_.revision != revision
                    || lock_.lockedAt < r.recordedAt || lock_.lockedAt > block.timestamp
            ) revert InvalidScopedPreservationPolicySnapshotEvidence();
        } else if (lock_.recordHash != 0 || lock_.revision != 0 || lock_.lockedAt != 0) {
            revert InvalidScopedPreservationPolicySnapshotEvidence();
        }
        e = StreamFinalitySnapshotEvidence(
            0,
            recordHash,
            r.manifestHash,
            r.sourceHash,
            p.coordinatorInventoryPlan,
            r.schemaHash,
            r.profileHash,
            r.canonicalizationHash,
            revision,
            r.manifestBytes,
            r.publisher,
            r.authorizationClass,
            r.grantRevision,
            r.displayAuthorizationClass,
            r.displayGrantRevision,
            locked,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_FINALITY_SCOPED_PRESERVATION_POLICY_SNAPSHOT_LOCK_V1"),
                    d.chainId,
                    d.snapshots,
                    scope,
                    lock_
                )
            )
        );
        e.inputHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_SCOPED_PRESERVATION_POLICY_SNAPSHOT_INPUT_V1"),
                d.chainId,
                d.core,
                d.metadata,
                d.router,
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
        bytes32 recordHash,
        uint64 revision
    ) public view returns (StreamFinalitySnapshotEvidence memory e) {
        e = requireCurrent(d, scope, recordHash, revision);
        if (!e.locked) revert InvalidScopedPreservationPolicySnapshotEvidence();
    }

    /// @notice Exact immutable original record; does not assert that it remains the current head.
    function original(
        Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 recordHash,
        uint64 revision
    ) public view returns (S.Publication memory p, S.Receipt memory r) {
        if (
            d.chainId != block.chainid || d.readGas < 50000 || d.validationGas < d.readGas
                || recordHash == 0 || revision == 0
                || (scope.scopeType != StreamFinalityScopeType.TOKEN
                    && scope.scopeType != StreamFinalityScopeType.RELEASE
                    && scope.scopeType != StreamFinalityScopeType.SEASON)
        ) revert InvalidScopedPreservationPolicySnapshotEvidence();
        bytes32 subject = StreamMetadataSubjects.scopeSubject(d.chainId, d.core, scope);
        _pin(d.core, d.coreCodeHash);
        _pin(d.metadata, d.metadataCodeHash);
        _pin(d.router, d.routerCodeHash);
        _pin(d.snapshots, d.snapshotsCodeHash);
        if (
            _word(d, abi.encodeCall(Snapshot.core, ())) != bytes32(uint256(uint160(d.core)))
                || _word(d, abi.encodeCall(Snapshot.metadataHost, ()))
                    != bytes32(uint256(uint160(d.metadata)))
                || _word(d, abi.encodeCall(Snapshot.scopedPreservationPolicySnapshotProfile, ()))
                    != keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V1")
                || _word(d, abi.encodeCall(IERC165.supportsInterface, (type(Snapshot).interfaceId)))
                    != bytes32(uint256(1))
        ) revert InvalidScopedPreservationPolicySnapshotEvidence();
        bytes memory raw =
            Reads.read(d.snapshots, abi.encodeCall(Snapshot.dependencies, ()), 832, d.readGas);
        S.Dependencies memory source = abi.decode(raw, (S.Dependencies));
        _canonical(raw, abi.encode(source));
        if (
            source.chainId != d.chainId || source.targets[0] != d.core
                || source.targets[1] != d.metadata || source.targets[4] != d.router
                || source.codeHashes[0] != d.coreCodeHash
                || source.codeHashes[1] != d.metadataCodeHash
                || source.codeHashes[4] != d.routerCodeHash
        ) revert InvalidScopedPreservationPolicySnapshotEvidence();
        raw = Reads.dynamicRead(
            d.snapshots, abi.encodeCall(Snapshot.snapshotRecord, (recordHash)), 4096, d.readGas
        );
        (p, r) = abi.decode(raw, (S.Publication, S.Receipt));
        _canonical(raw, abi.encode(p, r));
        if (
            keccak256(abi.encode(p.scope)) != keccak256(abi.encode(scope))
                || r.scopeSubject != subject || r.recordHash != recordHash || r.revision != revision
                || p.expectedRevision == type(uint64).max || revision != p.expectedRevision + 1
                || r.predecessor != p.expectedHead
                || (revision == 1 ? r.predecessor != 0 : r.predecessor == 0) || r.chainHash == 0
                || p.snapshotId == 0 || p.outputManifestRecord == 0
                || p.coordinatorInventoryPlan == 0 || p.expectedSourceHash == 0
                || p.expectedSourceHash != r.sourceHash || r.manifestHash == 0
                || r.manifestBytes == 0 || r.manifestBytes > 524288 || r.publisher == address(0)
                || (r.authorizationClass != 7 && r.authorizationClass != 8)
                || (r.displayAuthorizationClass != 7 && r.displayAuthorizationClass != 8)
                || r.grantRevision == 0 || r.displayGrantRevision == 0 || r.recordedAt == 0
                || r.recordedAt > block.timestamp || p.effectiveAt == 0
                || p.effectiveAt > r.recordedAt || p.reasonHash == 0
                || bytes(p.manifestURI).length > 2048 || r.schemaHash != Definitions.SCHEMA_HASH
                || r.profileHash != Definitions.PROFILE_HASH
                || r.canonicalizationHash != Definitions.CANON_HASH
        ) revert InvalidScopedPreservationPolicySnapshotEvidence();
        S.Receipt memory committed = abi.decode(abi.encode(r), (S.Receipt));
        committed.recordHash = 0;
        committed.chainHash = 0;
        if (
            keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_RECORD_V1"),
                        d.chainId,
                        d.snapshots,
                        d.core,
                        d.metadata,
                        p,
                        committed
                    )
                ) != recordHash
        ) revert InvalidScopedPreservationPolicySnapshotEvidence();
    }

    function _word(Dependencies memory d, bytes memory input) private view returns (bytes32) {
        return abi.decode(Reads.read(d.snapshots, input, 32, d.readGas), (bytes32));
    }

    function _pin(address target, bytes32 expected) private view {
        if (target.code.length == 0 || target.codehash != expected) {
            revert InvalidScopedPreservationPolicySnapshotEvidence();
        }
    }

    function _canonical(bytes memory supplied, bytes memory expected) private pure {
        if (keccak256(supplied) != keccak256(expected)) {
            revert InvalidScopedPreservationPolicySnapshotEvidence();
        }
    }
}
