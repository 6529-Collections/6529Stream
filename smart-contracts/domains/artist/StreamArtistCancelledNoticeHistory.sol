// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistIdentityResolutionState as Resolution
} from "./StreamArtistIdentityResolutionState.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistDormancyOwner,
    StreamArtistDormancyTypes as Dorm
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    IStreamArtistIdentityContestOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityContest.sol";
import {
    IStreamArtistIdentityRecoveryOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamArtistRotationReads
} from "../../interfaces/stream/artist/IStreamArtistRotation.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistIdentityContestTypes as Cont
} from "../../interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";

/// @notice One original status-2 compromise and dismissal from a later-cancelled notice.
/// @dev The caller authenticates currentNotice, selects the saved cause/resolution pair, and
/// proves its executed-principal ancestry, maturity and ordering between distinct notice groups.
/// This helper reads fixed-owner history without replaying historical roles or live dismissal.
library StreamArtistCancelledNoticeHistory {
    struct Facts {
        bytes32 proof;
        Dorm.Notice notice;
        Dorm.Terminal cancellation;
        D.Cause cause;
        D.Record dismissal;
        Cont.Record contest;
        uint256 activityCount;
    }

    /// @notice Read an original cancelled episode before an authenticated current compromise.
    /// @dev boundaryAt is the current cause's actual enteredAt, authenticated by the caller.
    /// It is not the earlier selected episode's next-link time: a group can cancel after one of
    /// its already-dismissed episodes. The caller separately checks episode/member ordering and
    /// monotonic counters between notice groups. No later notice or authority installation is used.
    function readAt(
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        bytes32 artistId,
        bytes32 causeHash,
        bytes32 resolutionHash,
        uint64 boundaryAt
    ) public view returns (Facts memory f) {
        if (
            artistId == 0 || boundaryAt == 0 || boundaryAt > block.timestamp
                || e.chainId != block.chainid || e.registry == address(0)
                || IStreamArtistOwner(address(this)).deploymentChainId() != e.chainId
                || IStreamArtistOwner(address(this)).artistRegistry() != e.registry
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);

        f.cause = resolutions.causes[causeHash];
        _cause(e, f.cause, artistId, causeHash);
        (bytes32 noticeHash, uint8 phase, bytes32 terminalHash) =
            IStreamArtistDormancyOwner(address(this)).dormancyResolutionState(artistId, causeHash);
        if (noticeHash == 0 || phase != 2 || terminalHash == 0) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        }
        (f.notice, phase, f.cancellation) =
            IStreamArtistDormancyOwner(address(this)).dormancyRecord(noticeHash);
        if (
            phase != 2 || f.notice.recordHash != noticeHash
                || f.cancellation.recordHash != terminalHash
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        f.activityCount =
            _noticeAndCancellationAt(e, artistId, boundaryAt, f.notice, f.cancellation);
        if (
            f.cause.facts.incumbent != f.notice.incumbent
                || f.cause.facts.enteredAt < f.notice.initiatedAt
                || f.cause.facts.enteredAt > f.cancellation.observedAt
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        f.dismissal = resolutions.records[resolutionHash];
        _dismissal(e, f.cause, f.dismissal, resolutionHash, boundaryAt);
        if (f.dismissal.restoredStatus == 2
                ? f.dismissal.dismissedAt > f.cancellation.observedAt
                : f.dismissal.dismissedAt < f.cancellation.observedAt) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        f.contest = _contest(resolutions, e, f.cause);
        f.proof = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_CANCELLED_NOTICE_EPISODE_AT_V1"),
                e.chainId,
                e.registry,
                address(this),
                artistId,
                boundaryAt,
                f.notice,
                f.cancellation,
                f.cause,
                f.dismissal,
                f.contest,
                f.activityCount
            )
        );
    }

    function _noticeAndCancellationAt(
        StreamArtistHashes.Environment memory e,
        bytes32 artistId,
        uint64 boundaryAt,
        Dorm.Notice memory n,
        Dorm.Terminal memory t
    ) private view returns (uint256 count) {
        if (
            n.terms.artistId != artistId || n.incumbent == address(0) || n.terms.evidenceHash == 0
                || bytes(n.terms.reasonURI).length == 0 || bytes(n.terms.reasonURI).length > 2048
                || n.initiatedAt == 0 || n.inactivitySeconds < 365 days
                || n.noticeSeconds < 180 days || n.timingRevision == 0 || n.actionId == 0
                || n.witnessHash == 0
                || uint256(n.noticeEndsAt) != uint256(n.initiatedAt) + n.noticeSeconds
                || uint256(n.initiatedAt) < uint256(n.priorLivenessAt) + n.inactivitySeconds
                || n.priorActivity == type(uint256).max || n.recordHash != _noticeHash(e, n)
                || t.noticeHash != n.recordHash || t.actor == address(0)
                || (t.authorityClass != 1 && t.authorityClass != 2 && t.authorityClass != 3)
                || (t.authorityClass == 1 && t.actor != n.incumbent) || t.observedAt < n.initiatedAt
                || t.observedAt > boundaryAt
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        count = n.priorActivity + 1;
        Dorm.Terminal memory canonical;
        canonical.noticeHash = n.recordHash;
        canonical.actor = t.actor;
        canonical.authorityClass = t.authorityClass;
        canonical.observedAt = t.observedAt;
        canonical.recordHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DORMANCY_CANCELLATION_V1"),
                e.chainId,
                e.registry,
                address(this),
                canonical,
                count
            )
        );
        if (keccak256(abi.encode(t)) != keccak256(abi.encode(canonical))) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        }
    }

    function read(
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        Dorm.Notice memory currentNotice,
        bytes32 causeHash,
        bytes32 resolutionHash,
        uint64 nextAt
    ) public view returns (Facts memory f) {
        bytes32 artistId = currentNotice.terms.artistId;
        if (
            artistId == 0 || currentNotice.recordHash == 0 || currentNotice.initiatedAt == 0
                || e.chainId != block.chainid || e.registry == address(0)
                || IStreamArtistOwner(address(this)).deploymentChainId() != e.chainId
                || IStreamArtistOwner(address(this)).artistRegistry() != e.registry
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);

        f.cause = resolutions.causes[causeHash];
        _cause(e, f.cause, artistId, causeHash);
        (bytes32 noticeHash, uint8 phase, bytes32 terminalHash) =
            IStreamArtistDormancyOwner(address(this)).dormancyResolutionState(artistId, causeHash);
        if (
            noticeHash == 0 || noticeHash == currentNotice.recordHash || phase != 2
                || terminalHash == 0
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        (f.notice, phase, f.cancellation) =
            IStreamArtistDormancyOwner(address(this)).dormancyRecord(noticeHash);
        if (
            phase != 2 || f.notice.recordHash != noticeHash
                || f.cancellation.recordHash != terminalHash
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        f.activityCount = _noticeAndCancellation(e, currentNotice, f.notice, f.cancellation);
        if (
            f.cause.facts.incumbent != f.notice.incumbent
                || f.cause.facts.enteredAt < f.notice.initiatedAt
                || f.cause.facts.enteredAt > f.cancellation.observedAt
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);

        f.dismissal = resolutions.records[resolutionHash];
        _dismissal(e, f.cause, f.dismissal, resolutionHash, nextAt);
        if (
            f.dismissal.dismissedAt > currentNotice.initiatedAt
                || (f.dismissal.restoredStatus == 2
                        ? f.dismissal.dismissedAt > f.cancellation.observedAt
                        : f.dismissal.dismissedAt < f.cancellation.observedAt)
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        f.contest = _contest(resolutions, e, f.cause);
        f.proof = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_CANCELLED_NOTICE_EPISODE_V1"),
                e.chainId,
                e.registry,
                address(this),
                currentNotice,
                nextAt,
                f.notice,
                f.cancellation,
                f.cause,
                f.dismissal,
                f.contest,
                f.activityCount
            )
        );
    }

    function _noticeAndCancellation(
        StreamArtistHashes.Environment memory e,
        Dorm.Notice memory current,
        Dorm.Notice memory n,
        Dorm.Terminal memory t
    ) private view returns (uint256 count) {
        if (
            n.terms.artistId != current.terms.artistId || n.incumbent == address(0)
                || n.terms.evidenceHash == 0 || bytes(n.terms.reasonURI).length == 0
                || bytes(n.terms.reasonURI).length > 2048 || n.initiatedAt == 0
                || n.inactivitySeconds < 365 days || n.noticeSeconds < 180 days
                || n.timingRevision == 0 || n.actionId == 0 || n.witnessHash == 0
                || uint256(n.noticeEndsAt) != uint256(n.initiatedAt) + n.noticeSeconds
                || uint256(n.initiatedAt) < uint256(n.priorLivenessAt) + n.inactivitySeconds
                || n.priorActivity >= current.priorActivity || n.recordHash != _noticeHash(e, n)
                || t.noticeHash != n.recordHash || t.actor == address(0)
                || (t.authorityClass != 1 && t.authorityClass != 2 && t.authorityClass != 3)
                || (t.authorityClass == 1 && t.actor != n.incumbent) || t.observedAt < n.initiatedAt
                || t.observedAt > current.initiatedAt
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(current.terms.artistId);
        }
        // The strict activity comparison also excludes uint256 overflow before this addition.
        // A phase-1 notice is cancelled by its first activity, which increments exactly once.
        count = n.priorActivity + 1;
        Dorm.Terminal memory canonical;
        canonical.noticeHash = n.recordHash;
        canonical.actor = t.actor;
        canonical.authorityClass = t.authorityClass;
        canonical.observedAt = t.observedAt;
        canonical.recordHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DORMANCY_CANCELLATION_V1"),
                e.chainId,
                e.registry,
                address(this),
                canonical,
                count
            )
        );
        // All completion-only fields stay zero, including plan, action and delegation epoch.
        if (keccak256(abi.encode(t)) != keccak256(abi.encode(canonical))) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(current.terms.artistId);
        }
    }

    function _noticeHash(StreamArtistHashes.Environment memory e, Dorm.Notice memory n)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DORMANCY_NOTICE_V1"),
                e.chainId,
                e.registry,
                address(this),
                n.terms,
                n.incumbent,
                n.initiatedAt,
                n.noticeEndsAt,
                n.inactivitySeconds,
                n.noticeSeconds,
                n.timingRevision,
                n.priorLivenessAt,
                n.priorActivity,
                n.actionId,
                n.witnessHash
            )
        );
    }

    function _cause(
        StreamArtistHashes.Environment memory e,
        D.Cause memory cause,
        bytes32 artistId,
        bytes32 expected
    ) private view {
        if (
            expected == 0 || cause.causeHash != expected || cause.facts.artistId != artistId
                || cause.facts.kind != 1 || cause.facts.authorityClass != 1
                || cause.facts.priorStatus != 2 || cause.facts.pendingTransitionHash != 0
                || cause.facts.incumbent == address(0) || cause.facts.actor == address(0)
                || cause.facts.referenceHash == 0 || cause.facts.evidenceHash == 0
                || cause.facts.reasonHash == 0 || cause.facts.enteredAt == 0
                || cause.causeHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_IDENTITY_CONTEST_CAUSE_V1"),
                            e.chainId,
                            e.registry,
                            address(this),
                            cause.facts
                        )
                    )
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
    }

    function _dismissal(
        StreamArtistHashes.Environment memory e,
        D.Cause memory cause,
        D.Record memory r,
        bytes32 expected,
        uint64 nextAt
    ) private view {
        if (
            expected == 0 || r.recordHash != expected || r.terms.artistId != cause.facts.artistId
                || r.terms.expectedCauseHash != cause.causeHash
                || r.terms.expectedResolutionHash != cause.facts.previousResolutionHash
                || r.terms.evidenceHash == 0 || r.terms.reasonHash == 0 || r.executor == address(0)
                || r.proposer == address(0) || (r.actionClass != 1 && r.actionClass != 2)
                || r.actionId == 0 || r.incumbent != cause.facts.incumbent || r.authorityClass != 1
                || (r.restoredStatus != 1 && r.restoredStatus != 2)
                || r.dismissedAt < cause.facts.enteredAt || r.dismissedAt > nextAt
                || r.cohortHash == 0 || r.governanceWitnessHash == 0
                || (r.terms.removePriorStanding
                        ? r.terms.expectedRetirementHash == 0
                        || r.terms.expectedRetirementHash != cause.facts.actorRetirementHash
                        : r.terms.expectedRetirementHash != 0)
                || r.recordHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_IDENTITY_DISMISSAL_RECORD_V1"),
                            e.chainId,
                            e.registry,
                            address(this),
                            r.terms,
                            r.executor,
                            r.proposer,
                            r.actionClass,
                            r.actionId,
                            r.incumbent,
                            r.authorityClass,
                            r.restoredStatus,
                            r.dismissedAt,
                            r.cohortHash,
                            r.governanceWitnessHash
                        )
                    )
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(cause.facts.artistId);
        }
    }

    function _contest(
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        D.Cause memory cause
    ) private view returns (Cont.Record memory c) {
        c = IStreamArtistIdentityContestOwner(address(this))
            .identityContestRecord(cause.facts.referenceHash);
        if (
            c.recordHash != cause.facts.referenceHash || c.terms.artistId != cause.facts.artistId
                || c.terms.evidenceHash != cause.facts.evidenceHash
                || c.terms.reasonHash != cause.facts.reasonHash || c.contester != cause.facts.actor
                || c.contestedAt != cause.facts.enteredAt || c.priorStatus != 2
                || c.pendingTransitionRecordHash != 0
                || c.executedTransitionRecordHash != cause.facts.executedTransitionHash
                || c.recordHash
                    != keccak256(
                        abi.encode(
                            bytes32(
                                0x26a4221cd1625ab88b1ac279e1708a73efa176e486242b26832cdc94fe25e6bb
                            ),
                            e.chainId,
                            e.registry,
                            c.terms.artistId,
                            c.contester,
                            c.terms.subjectRecordHash,
                            c.terms.evidenceHash,
                            c.terms.reasonHash,
                            c.contestedAt
                        )
                    )
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(cause.facts.artistId);
        if (c.terms.subjectRecordHash != 0) {
            R.TransitionState memory subject = IStreamArtistRotationReads(address(this))
                .artistTransitionState(c.terms.subjectRecordHash);
            if (
                subject.recordHash != c.terms.subjectRecordHash
                    || subject.artistId != cause.facts.artistId
                    || (subject.phase != 2 && subject.phase != 3) || subject.stagedAt == 0
                    || subject.stagedAt > cause.facts.enteredAt
            ) revert Recovery.UnsupportedIdentityRecoveryProfile(cause.facts.artistId);
            _subjectMarker(resolutions, cause, subject);
        }
    }

    function _subjectMarker(
        Resolution.State storage resolutions,
        D.Cause memory cause,
        R.TransitionState memory subject
    ) private view {
        R.RotationRecord memory rotation = IStreamArtistRotationReads(address(this))
            .rotationRecord(subject.recordHash);
        if (rotation.recordHash != subject.recordHash) {
            Recovery.Record memory recovered = IStreamArtistIdentityRecoveryOwner(address(this))
                .identityRecoveryRecord(subject.recordHash);
            if (recovered.recordHash != subject.recordHash) return;
        }
        if (subject.contestedAt > cause.facts.enteredAt) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(cause.facts.artistId);
        }
        D.Closure memory closed = resolutions.closures[subject.recordHash];
        D.Closure memory empty;
        if (keccak256(abi.encode(closed)) == keccak256(abi.encode(empty))) {
            if (subject.contestedAt == 0) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(cause.facts.artistId);
            }
            return;
        }
        D.Record memory dismissal = resolutions.records[closed.dismissalRecordHash];
        uint64 ends = subject.phase == 2 ? subject.postWindowEndsAt : subject.contestEndsAt;
        bool abandoned = subject.phase == 3
            || (subject.phase == 2
                && subject.contestedAt != 0
                && subject.contestedAt < subject.postWindowEndsAt);
        if (
            closed.dismissalRecordHash == 0 || closed.artistId != subject.artistId
                || closed.transitionRecordHash != subject.recordHash || closed.windowEndsAt != ends
                || closed.contestedAt != subject.contestedAt || closed.abandoned != abandoned
                || dismissal.recordHash != closed.dismissalRecordHash
                || dismissal.terms.artistId != subject.artistId
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(cause.facts.artistId);
        // A mature standing closure legitimately preserves a zero marker on later filings.
    }
}
