// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistIdentityRecoveryState as State
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistRotationState as Rotations } from "./StreamArtistRotationState.sol";
import {
    StreamArtistIdentityResolutionState as Resolution
} from "./StreamArtistIdentityResolutionState.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import { StreamArtistLivingRecoveryReads as Living } from "./StreamArtistLivingRecoveryReads.sol";
import {
    StreamArtistCurrentCompromiseReads as Current
} from "./StreamArtistCurrentCompromiseReads.sol";
import {
    StreamArtistRecoveryRotationContinuation as Rotated
} from "./StreamArtistRecoveryRotationContinuation.sol";
import {
    StreamArtistRecoveryRotationClosure as Closed
} from "./StreamArtistRecoveryRotationClosure.sol";
import {
    StreamArtistCancelledNoticeHistory as Cancelled
} from "./StreamArtistCancelledNoticeHistory.sol";
import {
    StreamArtistDormancyTypes as Dorm
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as I
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistIdentityContestTypes as C
} from "../../interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    IStreamArtistIdentityContestOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityContest.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";

/// @notice Complete resolved class1 history between an admitted living35 and a fresh compromise.
/// @dev One walk handles actual32 ancestry, ACTIVE/standing dismissals, cancelled notices and
/// historical subjects. Existing encodings remain selected when the original readers support
/// their inspected records; a separate proof binds newly supported histories without synthetic43.
library StreamArtistLivingRecoveryHistory {
    struct Facts {
        bytes32 proof;
        bool legacyCompatible;
    }

    struct Episode {
        D.Cause cause;
        D.Record dismissal;
        C.Record contest;
        Dorm.Notice notice;
        Dorm.Terminal cancellation;
        bytes32 proof;
    }

    struct Chain {
        Living.Facts living;
        V.Snapshot head;
        D.Cause current;
        C.Record contest;
        Episode[] episodes;
        R.RotationRecord pending;
        bytes32 pendingProof;
    }

    struct Member {
        V.Snapshot vesting;
        R.TransitionState transition;
        uint64 before;
    }

    function read(
        State.State storage recovery,
        Rotations.State storage rotations,
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        I.Record memory prior,
        D.Cause memory current
    ) public view returns (Facts memory f) {
        bytes32 id = prior.fields.artistId;
        Chain memory h;
        h.living = Living.read(address(this), e.registry, e.chainId, id, prior.recordHash);
        if (
            keccak256(abi.encode(prior)) != keccak256(abi.encode(h.living.record))
                || recovery.latest[id] != prior.recordHash
        ) revert I.UnsupportedIdentityRecoveryProfile(id);
        h.head = recovery.vestingHistory.snapshots[rotations.latestExecution[id]];
        h.current = current;
        _cause(e, current, id, current.causeHash);
        if (
            current.facts.kind != 1 || current.facts.authorityClass != 1
                || current.facts.priorStatus != 1 || current.facts.enteredAt > block.timestamp
                || current.facts.executedTransitionHash != h.head.transitionRecordHash
                || current.facts.incumbent != h.head.newAddress || h.head.authorityClass != 1
                || current.facts.actor == address(0) || current.facts.evidenceHash == 0
                || current.facts.reasonHash == 0 || current.facts.enteredAt < h.head.executedAt
        ) revert I.UnsupportedIdentityRecoveryProfile(id);
        bytes32 ancestry =
            Rotated.ancestry(recovery, rotations, e, h.living.vesting, h.head.transitionRecordHash);
        if (current.facts.pendingTransitionHash == 0) {
            h.contest =
                Closed.compromiseRecord(resolutions, e, current, h.head.transitionRecordHash);
        } else {
            R.TransitionState memory executed = h.head.transitionRecordHash == prior.recordHash
                ? recovery.transitions[prior.recordHash]
                : rotations.rotations[h.head.transitionRecordHash].transition;
            Current.Facts memory captured =
                Current.read(address(this), e.registry, e.chainId, current, executed);
            h.contest = captured.contest;
            h.pending = captured.pending;
            h.pendingProof = captured.proof;
        }
        bytes32 episodes = _episodes(recovery, rotations, resolutions, e, h);
        bytes32 closures = _closures(recovery, rotations, resolutions, e, h);
        f.proof = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RESOLVED_LIVING_RECOVERY_HISTORY_V1"),
                e.chainId,
                e.registry,
                address(this),
                h.living.proof,
                h.head,
                current,
                h.contest,
                ancestry,
                episodes,
                closures,
                prior.terms.expectedCauseHash,
                prior.terms.expectedResolutionHash
            )
        );
        if (h.pendingProof != 0) {
            f.proof = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_CURRENT_PENDING_LIVING_RECOVERY_HISTORY_V1"),
                    f.proof,
                    h.pendingProof
                )
            );
        }
        f.legacyCompatible = _legacy(recovery, rotations, resolutions, h);
    }

    function _episodes(
        State.State storage recovery,
        Rotations.State storage rotations,
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        Chain memory h
    ) private view returns (bytes32 proof) {
        bytes32 baseline = h.living.record.terms.expectedCauseHash;
        bytes32 selected = h.current.facts.previousCauseHash;
        uint256 count;
        while (selected != baseline) {
            D.Cause memory c = resolutions.causes[selected];
            _cause(e, c, h.head.artistId, selected);
            selected = c.facts.previousCauseHash;
            ++count;
        }
        h.episodes = new Episode[](count);
        selected = h.current.facts.previousCauseHash;
        bytes32 resolutionHash = h.current.facts.previousResolutionHash;
        uint64 nextAt = h.current.facts.enteredAt;
        Dorm.Notice memory newer;
        bool activeBetween;
        for (uint256 i; i < count; ++i) {
            Episode memory x;
            x.cause = resolutions.causes[selected];
            x.dismissal = resolutions.records[resolutionHash];
            Member memory m = _member(recovery, rotations, h, x.cause.facts.executedTransitionHash);
            uint64 boundary = nextAt < m.before ? nextAt : m.before;
            if (
                x.cause.facts.authorityClass != 1 || x.cause.facts.incumbent != m.vesting.newAddress
                    || x.cause.facts.enteredAt < m.transition.executedAt
                    || x.cause.facts.enteredAt > boundary || x.dismissal.dismissedAt > boundary
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(h.head.artistId);
            }
            if (x.cause.facts.priorStatus == 2) {
                Cancelled.Facts memory old = Cancelled.readAt(
                    resolutions,
                    e,
                    h.head.artistId,
                    selected,
                    resolutionHash,
                    h.current.facts.enteredAt
                );
                if (
                    old.notice.incumbent != m.vesting.newAddress
                        || old.notice.initiatedAt < m.transition.executedAt
                        || old.cancellation.observedAt > m.before
                ) revert I.UnsupportedIdentityRecoveryProfile(h.head.artistId);
                if (old.notice.recordHash == newer.recordHash) {
                    if (activeBetween || old.dismissal.restoredStatus != 2) {
                        revert I.UnsupportedIdentityRecoveryProfile(h.head.artistId);
                    }
                } else if (
                    newer.recordHash != 0
                        && (old.notice.priorActivity >= newer.priorActivity
                            || old.cancellation.observedAt > newer.initiatedAt)
                ) {
                    revert I.UnsupportedIdentityRecoveryProfile(h.head.artistId);
                }
                newer = old.notice;
                activeBetween = false;
                x.notice = old.notice;
                x.cancellation = old.cancellation;
                x.contest = old.contest;
                x.proof = old.proof;
            } else {
                if (x.cause.facts.priorStatus != 1) {
                    revert I.UnsupportedIdentityRecoveryProfile(h.head.artistId);
                }
                x.proof = Closed.selectedHistory(
                    rotations,
                    resolutions,
                    e,
                    h.head.artistId,
                    m.transition,
                    m.vesting.newAddress,
                    boundary,
                    selected,
                    resolutionHash
                );
                if (x.cause.facts.kind == 1) {
                    x.contest = IStreamArtistIdentityContestOwner(address(this))
                        .identityContestRecord(x.cause.facts.referenceHash);
                }
                activeBetween = true;
            }
            proof = keccak256(abi.encode(proof, x.proof, m.vesting, m.before));
            h.episodes[i] = x;
            nextAt = x.cause.facts.enteredAt;
            selected = x.cause.facts.previousCauseHash;
            resolutionHash = x.cause.facts.previousResolutionHash;
        }
        if (resolutionHash != h.living.record.terms.expectedResolutionHash) {
            revert I.UnsupportedIdentityRecoveryProfile(h.head.artistId);
        }
    }

    function _member(
        State.State storage recovery,
        Rotations.State storage rotations,
        Chain memory h,
        bytes32 execution
    ) private view returns (Member memory m) {
        bytes32 cursor = h.head.transitionRecordHash;
        m.before = h.pendingProof == 0 ? h.current.facts.enteredAt : h.pending.transition.stagedAt;
        while (true) {
            m.vesting = recovery.vestingHistory.snapshots[cursor];
            m.transition = cursor == h.living.record.recordHash
                ? recovery.transitions[cursor]
                : rotations.rotations[cursor].transition;
            if (cursor == execution) return m;
            if (cursor == h.living.record.recordHash) {
                revert I.UnsupportedIdentityRecoveryProfile(h.head.artistId);
            }
            m.before = m.transition.stagedAt;
            cursor = m.vesting.previousTransitionRecordHash;
        }
    }

    function _closures(
        State.State storage recovery,
        Rotations.State storage rotations,
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        Chain memory h
    ) private view returns (bytes32 proof) {
        bytes32 cursor = h.head.transitionRecordHash;
        uint64 before = h.current.facts.enteredAt;
        bytes32 stage = rotations.latestTransition[h.head.artistId];
        if (h.pendingProof != 0) {
            // The current op33 aborted this exact pending32 without a dismissal. Its
            // executed predecessor must have been eligible when it was originally staged.
            // Any older aborted staging predecessor still requires its actual closure.
            before = h.pending.transition.stagedAt;
            stage = h.pending.terms.expectedPreviousTransitionRecordHash;
        }
        while (true) {
            V.Snapshot memory v = recovery.vestingHistory.snapshots[cursor];
            R.TransitionState memory t = cursor == h.living.record.recordHash
                ? recovery.transitions[cursor]
                : rotations.rotations[cursor].transition;
            if (stage != _stagingHead(h, cursor)) {
                revert I.UnsupportedIdentityRecoveryProfile(h.head.artistId);
            }
            bytes32 closed =
                _closure(resolutions, h, t, before, cursor == h.head.transitionRecordHash);
            bytes32 pending;
            if (stage != cursor) {
                pending = _pending(rotations, resolutions, e, h, t, v.newAddress, stage, before);
                if (resolutions.closures[cursor].dismissalRecordHash == 0) {
                    revert I.UnsupportedIdentityRecoveryProfile(h.head.artistId);
                }
            }
            proof = keccak256(abi.encode(proof, v, t, closed, pending, before));
            if (cursor == h.living.record.recordHash) return proof;
            stage = rotations.rotations[cursor].terms.expectedPreviousTransitionRecordHash;
            if (stage == 0) revert I.UnsupportedIdentityRecoveryProfile(h.head.artistId);
            before = t.stagedAt;
            cursor = v.previousTransitionRecordHash;
        }
    }

    // Every unexecuted stage must be aborted before another stage can be admitted. The
    // complete newest-first cause chain therefore identifies the exact last staging head,
    // including same-time episodes. A record hash alone does not bind this saved pointer.
    function _stagingHead(Chain memory h, bytes32 execution) private pure returns (bytes32) {
        for (uint256 i; i < h.episodes.length; ++i) {
            D.CauseFacts memory c = h.episodes[i].cause.facts;
            if (c.executedTransitionHash == execution && c.pendingTransitionHash != 0) {
                return c.pendingTransitionHash;
            }
        }
        return execution;
    }

    function _closure(
        Resolution.State storage resolutions,
        Chain memory h,
        R.TransitionState memory t,
        uint64 before,
        bool terminal
    ) private view returns (bytes32) {
        D.Closure memory c = resolutions.closures[t.recordHash];
        (bool found, uint256 index) = _first(h, t.recordHash);
        if (!found) {
            D.Closure memory empty;
            if (
                keccak256(abi.encode(c)) != keccak256(abi.encode(empty))
                    || t.postWindowEndsAt > before
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(h.head.artistId);
            }
            if (terminal) {
                if (t.contestedAt != h.current.facts.enteredAt) {
                    revert I.UnsupportedIdentityRecoveryProfile(h.head.artistId);
                }
                return 0;
            }
            if (t.contestedAt == 0) return 0;
            bytes32 subject = _lateSubject(h, t.recordHash, t.contestedAt);
            if (subject == 0 || t.contestedAt < before) {
                revert I.UnsupportedIdentityRecoveryProfile(h.head.artistId);
            }
            return keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_LIVING_HISTORY_LATE_SUBJECT_V1"),
                    t,
                    subject,
                    before
                )
            );
        }
        Episode memory x = h.episodes[index];
        bool abandoned = t.contestedAt != 0 && t.contestedAt < t.postWindowEndsAt;
        if (
            c.artistId != h.head.artistId || c.transitionRecordHash != t.recordHash
                || c.dismissalRecordHash != x.dismissal.recordHash
                || c.windowEndsAt != t.postWindowEndsAt || c.contestedAt != t.contestedAt
                || c.abandoned != abandoned || x.dismissal.dismissedAt > before
                || (!abandoned && x.dismissal.dismissedAt < t.postWindowEndsAt)
                || (t.contestedAt != 0 && t.contestedAt < t.executedAt)
                || (x.cause.facts.kind == 1
                        ? t.contestedAt != x.cause.facts.enteredAt
                        : t.contestedAt != 0 || abandoned
                        || x.cause.facts.enteredAt < t.postWindowEndsAt)
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(h.head.artistId);
        }
        if (
            x.cause.facts.priorStatus == 2
                && (abandoned
                    || x.notice.initiatedAt < t.postWindowEndsAt
                    || x.cancellation.observedAt > before)
        ) revert I.UnsupportedIdentityRecoveryProfile(h.head.artistId);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_LIVING_HISTORY_FIRST_CLOSURE_V1"),
                c,
                t,
                x.proof,
                before
            )
        );
    }

    function _pending(
        Rotations.State storage rotations,
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        Chain memory h,
        R.TransitionState memory t,
        address incumbent,
        bytes32 pending,
        uint64 before
    ) private view returns (bytes32) {
        D.Closure memory c = resolutions.closures[pending];
        for (uint256 i; i < h.episodes.length; ++i) {
            Episode memory x = h.episodes[i];
            if (x.dismissal.recordHash != c.dismissalRecordHash) continue;
            if (
                pending == 0 || (x.cause.facts.kind != 1 && x.cause.facts.kind != 2)
                    || (x.cause.facts.kind == 2 && x.cause.facts.referenceHash != pending)
                    || x.cause.facts.pendingTransitionHash != pending
                    || x.cause.facts.executedTransitionHash != t.recordHash
                    || x.dismissal.dismissedAt > before
            ) revert I.UnsupportedIdentityRecoveryProfile(h.head.artistId);
            if (x.cause.facts.kind == 1) {
                // selectedHistory already proves this exact aborted pending record and closure.
                return keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_LIVING_HISTORY_PENDING_COMPROMISE_V1"),
                        x.proof,
                        pending,
                        t.recordHash,
                        before
                    )
                );
            }
            return
                Closed.pendingBeforeNext(
                    rotations, resolutions, e, t, pending, incumbent, before, 1
                );
        }
        revert I.UnsupportedIdentityRecoveryProfile(h.head.artistId);
    }

    function _first(Chain memory h, bytes32 execution)
        private
        pure
        returns (bool found, uint256 index)
    {
        for (uint256 i; i < h.episodes.length; ++i) {
            if (h.episodes[i].cause.facts.executedTransitionHash == execution) {
                found = true;
                index = i;
            }
        }
    }

    function _lateSubject(Chain memory h, bytes32 execution, uint64 at)
        private
        pure
        returns (bytes32)
    {
        if (h.current.facts.enteredAt == at && h.contest.terms.subjectRecordHash == execution) {
            return keccak256(abi.encode(h.current, h.contest));
        }
        for (uint256 i; i < h.episodes.length; ++i) {
            Episode memory x = h.episodes[i];
            if (
                x.cause.facts.kind == 1 && x.cause.facts.enteredAt == at
                    && x.contest.terms.subjectRecordHash == execution
            ) {
                return keccak256(abi.encode(x.cause, x.contest));
            }
        }
        return 0;
    }

    // Select by the exact records inspected by the original readers, not by a superficial
    // sequence label. A cancelled episode between compatible ACTIVE endpoints can already have
    // an old encoding; its full chain is now checked without changing that encoding.
    function _legacy(
        State.State storage recovery,
        Rotations.State storage rotations,
        Resolution.State storage resolutions,
        Chain memory h
    ) private view returns (bool) {
        bytes32 original = h.living.record.recordHash;
        bytes32 head = h.head.transitionRecordHash;
        if (h.current.facts.pendingTransitionHash != 0 || h.contest.terms.subjectRecordHash != head)
        {
            return false;
        }
        bool rotated = head != original;
        if (
            !rotated
                && (rotations.latestTransition[h.head.artistId] != original
                    || rotations.retirement[h.head.artistId][h.living.vesting.oldAddress]
                        != original)
        ) return false;
        (bool firstFound, uint256 firstIndex) = _first(h, original);
        if (firstFound) {
            Episode memory first = h.episodes[firstIndex];
            if (
                first.cause.facts.previousCauseHash != h.living.record.terms.expectedCauseHash
                    || first.cause.facts.previousResolutionHash
                        != h.living.record.terms.expectedResolutionHash
                    || !_oldEpisode(first, original) || (!rotated && first.cause.facts.kind != 1)
            ) return false;
        } else if (h.living.transition.contestedAt != 0 && rotated) {
            return false;
        }
        if (!rotated) {
            if (!firstFound) return true;
            return h.episodes.length != 0 && h.episodes[0].cause.facts.kind == 1
                && _oldEpisode(h.episodes[0], head);
        }
        if (rotations.retirement[h.head.artistId][h.head.oldAddress] != head) return false;
        bytes32 lastStage = rotations.latestTransition[h.head.artistId];
        if (lastStage != head && !_oldPending(resolutions, lastStage)) return false;
        (bool terminalFound, uint256 terminalIndex) = _first(h, head);
        if (
            terminalFound
                && (!_oldEpisode(h.episodes[terminalIndex], head)
                    || h.episodes.length == 0
                    || !_oldEpisode(h.episodes[0], head))
        ) return false;
        bytes32 previous = h.head.previousTransitionRecordHash;
        bytes32 stagedPrevious =
            rotations.rotations[head].terms.expectedPreviousTransitionRecordHash;
        if (stagedPrevious != previous && !_oldPending(resolutions, stagedPrevious)) return false;
        (bool previousFound, uint256 previousIndex) = _first(h, previous);
        if (previousFound) {
            if (!_oldEpisode(h.episodes[previousIndex], previous)) return false;
        } else {
            R.TransitionState memory t = previous == original
                ? recovery.transitions[previous]
                : rotations.rotations[previous].transition;
            if (t.contestedAt != 0) return false;
        }
        // The full walk has already authenticated each retained pending veto and every boundary.
        return true;
    }

    function _oldEpisode(Episode memory x, bytes32 execution) private pure returns (bool) {
        return x.cause.facts.priorStatus == 1 && x.dismissal.restoredStatus == 1
            && x.cause.facts.executedTransitionHash == execution
            && (x.cause.facts.kind == 2
                || (x.cause.facts.kind == 1
                    && x.cause.facts.pendingTransitionHash == 0
                    && x.contest.terms.subjectRecordHash == execution));
    }

    function _oldPending(Resolution.State storage resolutions, bytes32 pending)
        private
        view
        returns (bool)
    {
        D.Record memory d = resolutions.records[resolutions.closures[pending].dismissalRecordHash];
        return pending != 0 && resolutions.causes[d.terms.expectedCauseHash].facts.kind == 2;
    }

    function _cause(
        StreamArtistHashes.Environment memory e,
        D.Cause memory c,
        bytes32 id,
        bytes32 expected
    ) private view {
        if (
            expected == 0 || c.causeHash != expected || c.facts.artistId != id
                || c.facts.enteredAt == 0
                || c.causeHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_IDENTITY_CONTEST_CAUSE_V1"),
                            e.chainId,
                            e.registry,
                            address(this),
                            c.facts
                        )
                    )
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(id);
        }
    }
}
