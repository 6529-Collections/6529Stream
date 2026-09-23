// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistIdentityRecoveryState as RecoveryState
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistRotationState as Rotations } from "./StreamArtistRotationState.sol";
import {
    StreamArtistIdentityResolutionState as Resolution
} from "./StreamArtistIdentityResolutionState.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import { StreamArtistLivingRecoveryReads as Living } from "./StreamArtistLivingRecoveryReads.sol";
import { StreamArtistLivingDormancyReads as Ancestry } from "./StreamArtistLivingDormancyReads.sol";
import {
    StreamArtistDormancyNoticeHistory as NoticeHistory
} from "./StreamArtistDormancyNoticeHistory.sol";
import {
    StreamArtistCancelledNoticeHistory as Cancelled
} from "./StreamArtistCancelledNoticeHistory.sol";
import {
    StreamArtistRecoveryRotationClosure as Closed
} from "./StreamArtistRecoveryRotationClosure.sol";
import {
    IStreamArtistIdentityContestOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityContest.sol";
import {
    StreamArtistIdentityContestTypes as C
} from "../../interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    StreamArtistDormancyTypes as Dorm
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as I
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";

/// @notice Original cancelled-notice histories preceding a later completed designated notice.
/// @dev Every selected dismissal and every first closure is authenticated independently. The
/// completed notice remains a different record, and no saved status or baseline pair is changed.
library StreamArtistCancelledDormancyBoundary {
    struct History {
        Dorm.Notice notice;
        Dorm.Terminal terminal;
        V.Snapshot origin;
        Living.Facts living;
        NoticeHistory.Facts active;
        bytes32 entryCause;
        bytes32 entryResolution;
    }

    struct Member {
        V.Snapshot vesting;
        R.TransitionState transition;
        address incumbent;
        uint64 before;
    }

    /// @dev Classification only; read() subsequently authenticates the complete selected chain.
    /// Canonical immutable cause hashes prevent cycles without an arbitrary history limit.
    function contains(
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        bytes32 artistId,
        bytes32 causeHash,
        bytes32 baseline
    ) public view returns (bool) {
        while (causeHash != baseline) {
            D.Cause memory cause = resolutions.causes[causeHash];
            _cause(e, cause, artistId, causeHash);
            if (cause.facts.priorStatus == 2) return true;
            causeHash = cause.facts.previousCauseHash;
        }
        return false;
    }

    function read(
        RecoveryState.State storage recovery,
        Rotations.State storage rotations,
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        Dorm.Notice memory notice,
        Dorm.Terminal memory terminal,
        V.Snapshot memory origin,
        NoticeHistory.Facts memory active,
        bytes32 entryCause,
        bytes32 entryResolution
    ) public view returns (bytes32) {
        (Living.Facts memory living, bytes32 ancestry) = Ancestry.withInitialHistory(
            address(this),
            e.registry,
            e.chainId,
            notice,
            terminal,
            origin,
            recovery.latest[origin.artistId]
        );
        if (ancestry == 0 || (living.record.recordHash == 0 && terminal.delegationEpoch != 1)) {
            revert I.UnsupportedIdentityRecoveryProfile(origin.artistId);
        }
        History memory h =
            History(notice, terminal, origin, living, active, entryCause, entryResolution);
        bytes32 episodes = _episodes(recovery, rotations, resolutions, e, h);
        bytes32 closures = _closures(recovery, rotations, resolutions, e, h);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_CANCELLED_NOTICE_DORMANCY_BOUNDARY_V1"),
                e.chainId,
                e.registry,
                address(this),
                notice,
                terminal,
                origin,
                ancestry,
                episodes,
                closures,
                active.proof,
                entryCause,
                entryResolution,
                active.previousCause,
                active.previousResolution
            )
        );
    }

    function _episodes(
        RecoveryState.State storage recovery,
        Rotations.State storage rotations,
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        History memory h
    ) private view returns (bytes32 proof) {
        bytes32 causeHash = h.active.previousCause;
        bytes32 resolutionHash = h.active.previousResolution;
        bytes32 baseline = h.living.record.terms.expectedCauseHash;
        uint64 nextAt = h.notice.initiatedAt;
        Dorm.Notice memory newer = h.notice;
        bool activeBetween;
        bool found;
        while (causeHash != baseline) {
            D.Cause memory cause = resolutions.causes[causeHash];
            _cause(e, cause, h.origin.artistId, causeHash);
            if (
                cause.facts.authorityClass != 1 || cause.facts.enteredAt > nextAt
                    || cause.facts.enteredAt < h.living.record.fields.recoveredAt
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(h.origin.artistId);
            }
            Member memory m = _member(recovery, rotations, h, cause.facts.executedTransitionHash);
            if (
                cause.facts.incumbent != m.incumbent
                    || cause.facts.enteredAt < m.transition.executedAt
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(h.origin.artistId);
            }
            uint64 boundary = nextAt < m.before ? nextAt : m.before;
            bytes32 episode;
            if (cause.facts.priorStatus == 2) {
                Cancelled.Facts memory old =
                    Cancelled.read(resolutions, e, h.notice, causeHash, resolutionHash, boundary);
                if (
                    old.notice.incumbent != m.incumbent
                        || old.notice.initiatedAt < m.transition.executedAt
                        || old.cancellation.observedAt > m.before
                ) {
                    revert I.UnsupportedIdentityRecoveryProfile(h.origin.artistId);
                }
                if (old.notice.recordHash == newer.recordHash) {
                    if (activeBetween || old.dismissal.restoredStatus != 2) {
                        revert I.UnsupportedIdentityRecoveryProfile(h.origin.artistId);
                    }
                } else if (
                    old.notice.priorActivity >= newer.priorActivity
                        || old.cancellation.observedAt > newer.initiatedAt
                ) {
                    revert I.UnsupportedIdentityRecoveryProfile(h.origin.artistId);
                }
                newer = old.notice;
                activeBetween = false;
                found = true;
                episode = old.proof;
            } else {
                if (cause.facts.priorStatus != 1) {
                    revert I.UnsupportedIdentityRecoveryProfile(h.origin.artistId);
                }
                episode = Closed.selectedBeforeNext(
                    rotations,
                    resolutions,
                    e,
                    h.origin.artistId,
                    m.transition,
                    m.incumbent,
                    boundary,
                    causeHash,
                    resolutionHash
                );
                activeBetween = true;
            }
            proof = keccak256(abi.encode(proof, episode, m.vesting, m.incumbent, m.before));
            nextAt = cause.facts.enteredAt;
            causeHash = cause.facts.previousCauseHash;
            resolutionHash = cause.facts.previousResolutionHash;
        }
        if (!found || resolutionHash != h.living.record.terms.expectedResolutionHash) {
            revert I.UnsupportedIdentityRecoveryProfile(h.origin.artistId);
        }
    }

    function _member(
        RecoveryState.State storage recovery,
        Rotations.State storage rotations,
        History memory h,
        bytes32 hash
    ) private view returns (Member memory m) {
        V.Snapshot memory child = h.origin;
        m.before = h.notice.initiatedAt;
        while (child.previousTransitionRecordHash != 0) {
            V.Snapshot memory v =
                recovery.vestingHistory.snapshots[child.previousTransitionRecordHash];
            R.TransitionState memory t = v.operationId == 35
                ? recovery.transitions[v.transitionRecordHash]
                : rotations.rotations[v.transitionRecordHash].transition;
            if (v.transitionRecordHash == hash) {
                return Member(v, t, v.newAddress, m.before);
            }
            if (v.transitionRecordHash == h.living.record.recordHash) {
                revert I.UnsupportedIdentityRecoveryProfile(h.origin.artistId);
            }
            m.before = t.stagedAt;
            child = v;
        }
        if (hash != 0 || h.living.record.recordHash != 0) {
            revert I.UnsupportedIdentityRecoveryProfile(h.origin.artistId);
        }
        // The genuine zero execution stays wholly empty; its incumbent comes from the first
        // authenticated rotation's old address (or the completed notice if no rotation exists).
        m.incumbent = child.oldAddress;
    }

    function _closures(
        RecoveryState.State storage recovery,
        Rotations.State storage rotations,
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        History memory h
    ) private view returns (bytes32 proof) {
        bytes32 cursor = h.origin.previousTransitionRecordHash;
        uint64 nextAt = h.notice.initiatedAt;
        bytes32 stagedPrevious;
        while (cursor != 0) {
            V.Snapshot memory v = recovery.vestingHistory.snapshots[cursor];
            R.TransitionState memory t = v.operationId == 35
                ? recovery.transitions[cursor]
                : rotations.rotations[cursor].transition;
            if (
                resolutions.closures[cursor].dismissalRecordHash
                    != _firstForExecution(resolutions, h, cursor)
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(h.origin.artistId);
            }
            bool currentNotice =
                cursor == h.origin.previousTransitionRecordHash && h.active.closureProof != 0;
            bytes32 closure = currentNotice
                ? h.active.closureProof
                : _closure(rotations, resolutions, e, h, t, v.newAddress, nextAt);
            bytes32 pending;
            if (stagedPrevious != 0 && stagedPrevious != cursor) {
                if (currentNotice || resolutions.closures[cursor].dismissalRecordHash == 0) {
                    revert I.UnsupportedIdentityRecoveryProfile(h.origin.artistId);
                }
                pending = Closed.pendingBeforeNext(
                    rotations, resolutions, e, t, stagedPrevious, v.newAddress, nextAt, 1
                );
                _onChain(resolutions, h, resolutions.closures[stagedPrevious].dismissalRecordHash);
            }
            proof = keccak256(abi.encode(proof, cursor, closure, pending));
            if (cursor == h.living.record.recordHash) return proof;
            stagedPrevious = rotations.rotations[cursor].terms.expectedPreviousTransitionRecordHash;
            if (v.previousTransitionRecordHash != 0 && stagedPrevious == 0) {
                revert I.UnsupportedIdentityRecoveryProfile(h.origin.artistId);
            }
            nextAt = t.stagedAt;
            cursor = v.previousTransitionRecordHash;
        }
        D.Closure memory empty;
        if (keccak256(abi.encode(resolutions.closures[bytes32(0)])) != keccak256(abi.encode(empty)))
        {
            revert I.UnsupportedIdentityRecoveryProfile(h.origin.artistId);
        }
        if (stagedPrevious != 0) {
            D.Closure memory c = resolutions.closures[stagedPrevious];
            D.Record memory d = resolutions.records[c.dismissalRecordHash];
            D.Cause memory cause = resolutions.causes[d.terms.expectedCauseHash];
            if (
                cause.facts.kind != 2 || cause.facts.referenceHash != stagedPrevious
                    || cause.facts.pendingTransitionHash != stagedPrevious
                    || cause.facts.executedTransitionHash != 0
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(h.origin.artistId);
            }
            Member memory initial = _member(recovery, rotations, h, 0);
            bytes32 pending = Closed.selectedBeforeNext(
                rotations,
                resolutions,
                e,
                h.origin.artistId,
                initial.transition,
                initial.incumbent,
                nextAt,
                cause.causeHash,
                c.dismissalRecordHash
            );
            _onChain(resolutions, h, c.dismissalRecordHash);
            proof = keccak256(abi.encode(proof, bytes32(0), pending));
        }
    }

    function _closure(
        Rotations.State storage rotations,
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        History memory h,
        R.TransitionState memory t,
        address incumbent,
        uint64 before
    ) private view returns (bytes32) {
        D.Closure memory c = resolutions.closures[t.recordHash];
        D.Closure memory empty;
        if (keccak256(abi.encode(c)) == keccak256(abi.encode(empty))) {
            // Any dismissed cause on this actual execution must have created its first closure.
            bytes32 selected = h.entryCause;
            while (selected != h.living.record.terms.expectedCauseHash) {
                D.Cause memory cause = resolutions.causes[selected];
                if (cause.facts.executedTransitionHash == t.recordHash) {
                    revert I.UnsupportedIdentityRecoveryProfile(h.origin.artistId);
                }
                selected = cause.facts.previousCauseHash;
            }
            if (t.executedAt > before || t.postWindowEndsAt > before) {
                revert I.UnsupportedIdentityRecoveryProfile(h.origin.artistId);
            }
            if (t.contestedAt == 0) return 0;
            bytes32 subject = _lateSubject(resolutions, h, t.recordHash, t.contestedAt);
            if (subject == 0 || t.contestedAt < before) {
                revert I.UnsupportedIdentityRecoveryProfile(h.origin.artistId);
            }
            return keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_CANCELLED_NOTICE_LATE_SUBJECT_V1"),
                    t,
                    subject,
                    before
                )
            );
        }
        _onChain(resolutions, h, c.dismissalRecordHash);
        D.Record memory d = resolutions.records[c.dismissalRecordHash];
        D.Cause memory cause = resolutions.causes[d.terms.expectedCauseHash];
        bytes32 episode;
        if (cause.facts.priorStatus == 2) {
            Cancelled.Facts memory old =
                Cancelled.read(resolutions, e, h.notice, cause.causeHash, d.recordHash, before);
            if (
                old.notice.incumbent != incumbent || old.notice.initiatedAt < t.executedAt
                    || t.postWindowEndsAt > old.notice.initiatedAt
                    || t.contestedAt < t.postWindowEndsAt || old.cancellation.observedAt > before
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(h.origin.artistId);
            }
            episode = old.proof;
        } else {
            episode = Closed.selectedBeforeNext(
                rotations,
                resolutions,
                e,
                h.origin.artistId,
                t,
                incumbent,
                before,
                cause.causeHash,
                d.recordHash
            );
        }
        bool abandoned = t.contestedAt != 0 && t.contestedAt < t.postWindowEndsAt;
        if (
            c.artistId != h.origin.artistId || c.transitionRecordHash != t.recordHash
                || c.windowEndsAt != t.postWindowEndsAt || c.contestedAt != t.contestedAt
                || c.abandoned != abandoned || cause.facts.executedTransitionHash != t.recordHash
                || cause.facts.incumbent != incumbent || t.phase != 2
                || (cause.facts.kind == 1
                        ? t.contestedAt != cause.facts.enteredAt
                        : t.contestedAt != 0 || abandoned
                        || cause.facts.enteredAt < t.postWindowEndsAt)
                || (t.contestedAt != 0 && t.contestedAt < t.executedAt)
                || (!abandoned && d.dismissedAt < t.postWindowEndsAt)
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(h.origin.artistId);
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_CANCELLED_NOTICE_FIRST_CLOSURE_V1"),
                c,
                t,
                episode,
                before
            )
        );
    }

    function _onChain(Resolution.State storage resolutions, History memory h, bytes32 first)
        private
        view
    {
        bytes32 selected = h.active.previousResolution;
        bytes32 baseline = h.living.record.terms.expectedResolutionHash;
        while (selected != first && selected != baseline) {
            selected = resolutions.records[selected].terms.expectedResolutionHash;
        }
        if (first == 0 || selected != first || selected == baseline) {
            revert I.UnsupportedIdentityRecoveryProfile(h.origin.artistId);
        }
    }

    function _firstForExecution(
        Resolution.State storage resolutions,
        History memory h,
        bytes32 execution
    ) private view returns (bytes32 first) {
        bytes32 causeHash = h.entryCause;
        bytes32 resolutionHash = h.entryResolution;
        while (causeHash != h.living.record.terms.expectedCauseHash) {
            D.Cause memory cause = resolutions.causes[causeHash];
            if (cause.facts.executedTransitionHash == execution) first = resolutionHash;
            causeHash = cause.facts.previousCauseHash;
            resolutionHash = cause.facts.previousResolutionHash;
        }
    }

    function _lateSubject(
        Resolution.State storage resolutions,
        History memory h,
        bytes32 hash,
        uint64 at
    ) private view returns (bytes32) {
        bytes32 selected = h.entryCause;
        while (selected != h.living.record.terms.expectedCauseHash) {
            D.Cause memory cause = resolutions.causes[selected];
            if (cause.facts.kind == 1 && cause.facts.enteredAt == at) {
                C.Record memory contest = IStreamArtistIdentityContestOwner(address(this))
                    .identityContestRecord(cause.facts.referenceHash);
                if (contest.terms.subjectRecordHash == hash) {
                    return keccak256(abi.encode(cause, contest));
                }
            }
            selected = cause.facts.previousCauseHash;
        }
        return 0;
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
