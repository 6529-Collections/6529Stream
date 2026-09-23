// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationState as Imported
} from "./StreamArtistRecoveredHydrationState.sol";
import {
    StreamArtistRecoveredHistoryOrder as Order
} from "./StreamArtistRecoveredHistoryOrder.sol";

import {
    StreamArtistIdentityRecoveryState as RecoveryState
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistRotationState as RotationState } from "./StreamArtistRotationState.sol";
import {
    StreamArtistIdentityResolutionState as Resolution
} from "./StreamArtistIdentityResolutionState.sol";
import {
    StreamArtistIdentityContestState as ContestState
} from "./StreamArtistIdentityContestState.sol";
import { StreamArtistRecoveryEstateClosed as Closed } from "./StreamArtistRecoveryEstateClosed.sol";
import { StreamArtistRotationHashes } from "./StreamArtistRotationHashes.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";

/// @notice Constant-size consumption of the admitted class3 vesting chain.
/// @dev Caller authenticates unchanged original op40 or designated op43 and excludes prior
/// recovery/supersession. These admitted origins establish class3; op32 preserves it and each write-once vesting
/// snapshot binds the owner's actual preceding head. No mutable retirement is a lineage anchor.
library StreamArtistRecoveryEstateRotationHistory {
    function terminal(
        RecoveryState.State storage recovery,
        RotationState.State storage rotations,
        Resolution.State storage resolutions,
        ContestState.State storage contests,
        StreamArtistHashes.Environment memory e,
        V.Snapshot memory origin,
        R.TransitionState memory originalTransition,
        D.Cause memory cause,
        bytes32 head,
        bytes32 closureProof
    ) public view returns (bytes32) {
        V.Snapshot memory v = recovery.vestingHistory.snapshots[head];
        R.RotationRecord memory r = rotations.rotations[head];
        _pair(recovery, e, v, r, origin);
        if (
            v.newAddress != cause.facts.incumbent || cause.facts.executedTransitionHash != head
                || rotations.retirement[v.artistId][v.oldAddress] != head
                || (closureProof == 0
                    && (rotations.latestTransition[v.artistId] != head
                        || cause.facts.enteredAt < r.transition.postWindowEndsAt
                        || r.transition.contestedAt != cause.facts.enteredAt))
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(v.artistId);
        }
        V.Snapshot memory previous =
            recovery.vestingHistory.snapshots[v.previousTransitionRecordHash];
        R.TransitionState memory previousTransition;
        R.RotationRecord memory prior;
        if (v.previousTransitionRecordHash == origin.transitionRecordHash) {
            if (keccak256(abi.encode(previous)) != keccak256(abi.encode(origin))) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(v.artistId);
            }
            previousTransition = originalTransition;
        } else {
            prior = rotations.rotations[previous.transitionRecordHash];
            _pair(recovery, e, previous, prior, origin);
            previousTransition = prior.transition;
        }
        if (
            previous.transitionRecordHash == head || previous.commitment != v.previousCommitment
                || previous.newAddress != v.oldAddress || !_before(e, previous, v)
                || previous.executedAt > r.transition.stagedAt
                || previous.guardians.count > v.guardians.count
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(v.artistId);
        }
        bytes32 previousClosure = Closed.beforeNext(
            rotations,
            resolutions,
            contests,
            e,
            previousTransition,
            v.oldAddress,
            r.transition.stagedAt
        );
        bytes32 stageProof;
        if (r.terms.expectedPreviousTransitionRecordHash != previous.transitionRecordHash) {
            stageProof = Closed.pendingBeforeNext(
                rotations,
                resolutions,
                contests,
                e,
                previousTransition,
                r.terms.expectedPreviousTransitionRecordHash,
                v.oldAddress,
                r.transition.stagedAt
            );
            if (previousClosure == 0) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(v.artistId);
            }
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_ESTATE_ROTATION_HISTORY_V1"),
                origin.commitment,
                r,
                v,
                previous,
                prior,
                previousClosure,
                stageProof
            )
        );
    }

    function _pair(
        RecoveryState.State storage recovery,
        StreamArtistHashes.Environment memory e,
        V.Snapshot memory v,
        R.RotationRecord memory r,
        V.Snapshot memory origin
    ) private view {
        R.TransitionState memory t = r.transition;
        if (
            v.artistId != origin.artistId || v.transitionRecordHash == 0
                || v.transitionRecordHash == origin.transitionRecordHash || v.operationId != 32
                || v.authorityClass != 3 || v.oldAddress == address(0) || v.newAddress == address(0)
                || v.oldAddress == v.newAddress || !_before(e, origin, v)
                || (Imported.commitment() == 0 && v.ownerRevision <= v.guardians.ownerRevision)
                || v.guardians.count < origin.guardians.count || v.executedAt < origin.executedAt
                || v.previousTransitionRecordHash == 0 || v.previousCommitment == 0
                || v.commitment == 0 || v.commitment != _vesting(e, v)
                || r.recordHash != v.transitionRecordHash || r.terms.artistId != v.artistId
                || r.terms.oldAddress != v.oldAddress || r.terms.newAddress != v.newAddress
                || r.terms.expectedPreviousTransitionRecordHash == 0 || t.artistId != v.artistId
                || t.recordHash != r.recordHash || t.phase != 2 || t.stagedAt < origin.executedAt
                || t.executedAt != v.executedAt || t.executedAt < t.stagedAt
                || r.effectiveWindow < 72 hours || r.standingTail < 30 days || r.timingRevision == 0
                || uint256(t.contestEndsAt) != uint256(t.stagedAt) + r.effectiveWindow
                || uint256(t.postWindowEndsAt) != uint256(t.executedAt) + r.effectiveWindow
                || (t.executedAt < t.contestEndsAt
                    && (r.approvalThreshold == 0 || r.guardianApprovals < r.approvalThreshold))
                || StreamArtistRotationHashes.rotationRecord(
                        _recordEnvironment(e, 29, r.terms.artistId, r.recordHash),
                        r.terms,
                        r.oldNonce,
                        t.stagedAt,
                        t.contestEndsAt
                    ) != r.recordHash
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(origin.artistId);
        }
        V.Snapshot memory parent = recovery.vestingHistory.snapshots[v.previousTransitionRecordHash];
        if (
            parent.artistId != v.artistId
                || parent.transitionRecordHash != v.previousTransitionRecordHash
                || parent.commitment != v.previousCommitment
                || parent.commitment != _vesting(e, parent) || parent.newAddress != v.oldAddress
                || !_before(e, parent, v) || parent.executedAt > t.stagedAt
                || parent.guardians.count > v.guardians.count || parent.authorityClass != 3
                || (parent.transitionRecordHash == origin.transitionRecordHash
                        ? keccak256(abi.encode(parent)) != keccak256(abi.encode(origin))
                        : parent.operationId != 32 || !_before(e, origin, parent)
                        || parent.previousTransitionRecordHash == 0
                        || parent.previousCommitment == 0)
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(v.artistId);
        }
        GH.Head memory h = v.guardians;
        if (h.count == 0) {
            if (h.ownerRevision != 0 || h.commitment != 0) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(v.artistId);
            }
        } else {
            bytes32 last = recovery.guardianHistory.records[v.artistId][h.count];
            GH.Entry memory entry = recovery.guardianHistory.entries[last];
            if (
                last == 0 || entry.artistId != v.artistId || entry.recordHash != last
                    || entry.index != h.count || entry.ownerRevision != h.ownerRevision
                    || entry.commitment != h.commitment || h.commitment == 0
                    || h.count > recovery.guardianRecordsSeen[v.artistId]
            ) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(v.artistId);
            }
        }
    }

    function _vesting(StreamArtistHashes.Environment memory e, V.Snapshot memory v)
        private
        view
        returns (bytes32)
    {
        if (Imported.commitment() != 0) return Order.vesting(e, v);
        return keccak256(
            bytes.concat(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_GUARDIAN_VESTING_V1"),
                    e.chainId,
                    e.registry,
                    address(this)
                ),
                abi.encode(
                    v.artistId,
                    v.transitionRecordHash,
                    v.operationId,
                    v.ownerRevision,
                    v.executedAt,
                    v.oldAddress,
                    v.newAddress,
                    v.authorityClass,
                    v.guardians,
                    v.previousTransitionRecordHash,
                    v.previousCommitment
                )
            )
        );
    }

    function _recordEnvironment(
        StreamArtistHashes.Environment memory e,
        uint16 operation,
        bytes32 artistId,
        bytes32 record
    ) private view returns (StreamArtistHashes.Environment memory) {
        return Imported.commitment() == 0
            ? e
            : Order.nativeEnvironment(e, operation, artistId, record);
    }

    function _before(
        StreamArtistHashes.Environment memory e,
        V.Snapshot memory a,
        V.Snapshot memory b
    ) private view returns (bool) {
        return Imported.commitment() == 0
            ? a.ownerRevision < b.ownerRevision
            : Order.before(e, a, b);
    }
}
