// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityScopedPreservationPolicySnapshotOriginalReadsV1 as OriginalReads
} from "./StreamFinalityScopedPreservationPolicySnapshotOriginalReadsV1.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Producers
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    StreamPreservationPolicySnapshotFamiliesV2 as SnapshotFamilies
} from "../records/StreamPreservationPolicySnapshotFamiliesV2.sol";

import {
    StreamScopedPreservationPolicySnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    IStreamScopedPreservationPolicySnapshotPublicationV1 as Snapshot
} from "../../interfaces/stream/metadata/IStreamScopedPreservationPolicySnapshotPublicationV1.sol";
import { StreamFinalityRouterEvidence as Reads } from "./StreamFinalityRouterEvidence.sol";
import "../../interfaces/stream/finality/StreamFinalitySnapshotTypes.sol";
import {
    StreamFinalityScope
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

    // Preserve the reader ABI for the scope error now bubbled from its fixed worker.
    error InvalidMetadataScope();
    error InvalidScopedPreservationPolicySnapshotEvidence();

    function requireCurrent(
        Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 recordHash,
        uint64 revision
    ) public view returns (StreamFinalitySnapshotEvidence memory e) {
        return requireCurrent(d, scope, recordHash, revision, Producers.ORIGINAL_PROFILE);
    }

    function requireCurrent(
        Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 recordHash,
        uint64 revision,
        bytes32 family
    ) public view returns (StreamFinalitySnapshotEvidence memory e) {
        SnapshotFamilies.version2(family);
        (S.Publication memory p, S.Receipt memory r) =
            original(d, scope, recordHash, revision, family);
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
                    SnapshotFamilies.finalityLockDomain(family, true),
                    d.chainId,
                    d.snapshots,
                    scope,
                    lock_
                )
            )
        );
        e.inputHash = keccak256(
            abi.encode(
                SnapshotFamilies.inputDomain(family, true),
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
        return requireLocked(d, scope, recordHash, revision, Producers.ORIGINAL_PROFILE);
    }

    function requireLocked(
        Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 recordHash,
        uint64 revision,
        bytes32 family
    ) public view returns (StreamFinalitySnapshotEvidence memory e) {
        SnapshotFamilies.version2(family);
        e = requireCurrent(d, scope, recordHash, revision, family);
        if (!e.locked) revert InvalidScopedPreservationPolicySnapshotEvidence();
    }

    /// @notice Exact immutable original record; does not assert that it remains the current head.
    function original(
        Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 recordHash,
        uint64 revision
    ) public view returns (S.Publication memory p, S.Receipt memory r) {
        return original(d, scope, recordHash, revision, Producers.ORIGINAL_PROFILE);
    }

    function original(
        Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 recordHash,
        uint64 revision,
        bytes32 family
    ) public view returns (S.Publication memory p, S.Receipt memory r) {
        return OriginalReads.original(d, scope, recordHash, revision, family);
    }

    function _canonical(bytes memory supplied, bytes memory expected) private pure {
        if (keccak256(supplied) != keccak256(expected)) {
            revert InvalidScopedPreservationPolicySnapshotEvidence();
        }
    }
}
