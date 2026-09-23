// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistIdentityRecoveryState as RecoveryState
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistRotationState as RotationState } from "./StreamArtistRotationState.sol";
import {
    StreamArtistIdentityResolutionState as Resolution
} from "./StreamArtistIdentityResolutionState.sol";
import { StreamArtistEstateState as EstateState } from "./StreamArtistEstateState.sol";
import {
    StreamArtistRecoveryRotationClosure as Closed
} from "./StreamArtistRecoveryRotationClosure.sol";
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

/// @notice Complete admitted rotation suffix after the latest original operation35.
/// @dev Only32 preserves the delegation epoch. Every35/40/43 increases it, and the fixed
/// vesting writer binds its actual prior head. An unchanged latest35 and epoch therefore
/// authenticate the entire suffix without a caller-selected prefix or a history-depth limit.
library StreamArtistRecoveryRotationContinuation {
    /// @notice Authenticate every actual32 between an admitted35 and the current execution.
    /// @dev Closure and cause chronology are separate. Existing proof() retains its exact tuple.
    function ancestry(
        RecoveryState.State storage recovery,
        RotationState.State storage rotations,
        StreamArtistHashes.Environment memory e,
        V.Snapshot memory origin,
        bytes32 head
    ) public view returns (bytes32 history) {
        if (head == 0 || recovery.vestingHistory.latest[origin.artistId] != head) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(origin.artistId);
        }
        bytes32 cursor = head;
        while (cursor != origin.transitionRecordHash) {
            V.Snapshot memory v = recovery.vestingHistory.snapshots[cursor];
            R.RotationRecord memory r = rotations.rotations[cursor];
            _pair(recovery, e, v, r, origin);
            history = keccak256(abi.encode(history, v, r));
            cursor = v.previousTransitionRecordHash;
        }
        if (
            keccak256(abi.encode(recovery.vestingHistory.snapshots[cursor]))
                != keccak256(abi.encode(origin))
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(origin.artistId);
        }
    }

    function proof(
        RecoveryState.State storage recovery,
        RotationState.State storage rotations,
        Resolution.State storage resolutions,
        EstateState.State storage estate,
        StreamArtistHashes.Environment memory e,
        Recovery.Record memory prior,
        R.TransitionState memory originalTransition,
        D.Cause memory cause
    ) public view returns (bytes32) {
        bytes32 artistId = prior.fields.artistId;
        bytes32 head = rotations.latestExecution[artistId];
        V.Snapshot memory origin = recovery.vestingHistory.snapshots[prior.recordHash];
        if (
            recovery.latest[artistId] != prior.recordHash || prior.recordHash == 0
                || prior.delegationEpoch == 0
                || prior.delegationEpoch != estate.delegationEpoch[artistId]
                || (prior.fields.vestedAuthorityClass != 1
                    && prior.fields.vestedAuthorityClass != 3) || head == 0
                || head == prior.recordHash || recovery.vestingHistory.latest[artistId] != head
                || origin.artistId != artistId || origin.transitionRecordHash != prior.recordHash
                || origin.operationId != 35
                || origin.authorityClass != prior.fields.vestedAuthorityClass
                || origin.oldAddress != prior.fields.oldAddress
                || origin.newAddress != prior.fields.newAddress
                || origin.executedAt != prior.fields.recoveredAt || origin.ownerRevision == 0
                || origin.ownerRevision <= origin.guardians.ownerRevision || origin.commitment == 0
                || origin.commitment != _vesting(e, origin)
                || cause.facts.authorityClass != origin.authorityClass
                || cause.facts.priorStatus != origin.authorityClass
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        _prefix(recovery, origin);
        if (origin.previousTransitionRecordHash == 0) {
            if (origin.previousCommitment != 0) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            }
        } else {
            V.Snapshot memory parent =
                recovery.vestingHistory.snapshots[origin.previousTransitionRecordHash];
            if (
                parent.artistId != artistId
                    || parent.transitionRecordHash != origin.previousTransitionRecordHash
                    || parent.commitment == 0 || parent.commitment != origin.previousCommitment
                    || parent.commitment != _vesting(e, parent)
                    || parent.ownerRevision >= origin.ownerRevision
                    || parent.executedAt > origin.executedAt
                    || parent.newAddress != origin.oldAddress
                    || parent.guardians.count > origin.guardians.count
                    || parent.authorityClass != origin.authorityClass
            ) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            }
        }
        R.TransitionState memory terminal = rotations.rotations[head].transition;
        bytes32 originalClosure = _originalClosure(
            rotations, resolutions, e, prior, originalTransition, terminal.stagedAt
        );
        bytes32 terminalClosure = Closed.proof(rotations, resolutions, e, cause, terminal);
        bytes32 history = _terminal(
            recovery,
            rotations,
            resolutions,
            e,
            origin,
            originalTransition,
            cause,
            head,
            terminalClosure
        );
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_ROTATED_REPEAT_FACTS_V1"),
                prior.recordHash,
                prior.delegationEpoch,
                origin,
                originalClosure,
                terminalClosure,
                history
            )
        );
    }

    function _originalClosure(
        RotationState.State storage rotations,
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        Recovery.Record memory prior,
        R.TransitionState memory original,
        uint64 terminalStagedAt
    ) private view returns (bytes32) {
        D.Closure memory closure = resolutions.closures[prior.recordHash];
        D.Closure memory empty;
        if (keccak256(abi.encode(closure)) != keccak256(abi.encode(empty))) {
            D.Record memory first = resolutions.records[closure.dismissalRecordHash];
            D.Cause memory cause = resolutions.causes[first.terms.expectedCauseHash];
            if (
                cause.facts.previousCauseHash != prior.terms.expectedCauseHash
                    || cause.facts.previousResolutionHash != prior.terms.expectedResolutionHash
            ) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(prior.fields.artistId);
            }
        }
        // op58 can close only its captured current execution. A later32 cannot rewrite this
        // write-once closure; the producer chain proves closure preceded the first successor32.
        return Closed.beforeNext(
            rotations,
            resolutions,
            e,
            original,
            prior.fields.newAddress,
            terminalStagedAt,
            prior.fields.vestedAuthorityClass
        );
    }

    function _prefix(RecoveryState.State storage recovery, V.Snapshot memory v) private view {
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

    function _terminal(
        RecoveryState.State storage recovery,
        RotationState.State storage rotations,
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        V.Snapshot memory origin,
        R.TransitionState memory originalTransition,
        D.Cause memory cause,
        bytes32 head,
        bytes32 closureProof
    ) private view returns (bytes32) {
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
                || previous.newAddress != v.oldAddress || previous.ownerRevision >= v.ownerRevision
                || previous.executedAt > r.transition.stagedAt
                || previous.guardians.count > v.guardians.count
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(v.artistId);
        }
        bytes32 previousClosure = Closed.beforeNext(
            rotations,
            resolutions,
            e,
            previousTransition,
            v.oldAddress,
            r.transition.stagedAt,
            origin.authorityClass
        );
        bytes32 stageProof;
        if (r.terms.expectedPreviousTransitionRecordHash != previous.transitionRecordHash) {
            stageProof = Closed.pendingBeforeNext(
                rotations,
                resolutions,
                e,
                previousTransition,
                r.terms.expectedPreviousTransitionRecordHash,
                v.oldAddress,
                r.transition.stagedAt,
                origin.authorityClass
            );
            if (previousClosure == 0) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(v.artistId);
            }
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_REPEAT_ROTATION_HISTORY_V1"),
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
                || v.authorityClass != origin.authorityClass || v.oldAddress == address(0)
                || v.newAddress == address(0) || v.oldAddress == v.newAddress
                || v.ownerRevision <= origin.ownerRevision
                || v.ownerRevision <= v.guardians.ownerRevision
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
                        e, r.terms, r.oldNonce, t.stagedAt, t.contestEndsAt
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
                || parent.ownerRevision >= v.ownerRevision || parent.executedAt > t.stagedAt
                || parent.guardians.count > v.guardians.count
                || parent.authorityClass != origin.authorityClass
                || (parent.transitionRecordHash == origin.transitionRecordHash
                        ? keccak256(abi.encode(parent)) != keccak256(abi.encode(origin))
                        : parent.operationId != 32 || parent.ownerRevision <= origin.ownerRevision
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
}
