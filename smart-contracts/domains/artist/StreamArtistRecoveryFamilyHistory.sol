// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistIdentityRecoveryState as State
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistRotationState as Rotations } from "./StreamArtistRotationState.sol";
import {
    StreamArtistIdentityResolutionState as Resolution
} from "./StreamArtistIdentityResolutionState.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistRecoveryFamilyProfile as Profile
} from "./StreamArtistRecoveryFamilyProfile.sol";
import {
    StreamArtistCurrentCompromiseReads as Current
} from "./StreamArtistCurrentCompromiseReads.sol";
import {
    StreamArtistRecoveryStagingHistory as Stages
} from "./StreamArtistRecoveryStagingHistory.sol";
import {
    StreamArtistRecoveryFamilyAncestry as Ancestry
} from "./StreamArtistRecoveryFamilyAncestry.sol";
import {
    StreamArtistRecoveryRotationClosure as Closed
} from "./StreamArtistRecoveryRotationClosure.sol";
import {
    StreamArtistCancelledNoticeHistory as Cancelled
} from "./StreamArtistCancelledNoticeHistory.sol";
import {
    StreamArtistDormancyNoticeHistory as NoticeHistory
} from "./StreamArtistDormancyNoticeHistory.sol";
import { StreamArtistLivingRecoveryReads as Living } from "./StreamArtistLivingRecoveryReads.sol";
import {
    StreamArtistRecoveryEstateEpisode as EstateEpisode
} from "./StreamArtistRecoveryEstateEpisode.sol";
import {
    StreamArtistEstateTypes as Estate
} from "../../interfaces/stream/artist/StreamArtistEstateTypes.sol";
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
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistEstateOwner
} from "../../interfaces/stream/artist/IStreamArtistEstateOwner.sol";
import {
    IStreamArtistRotationReads
} from "../../interfaces/stream/artist/IStreamArtistRotation.sol";
import {
    IStreamArtistIdentityContestOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityContest.sol";
import {
    IStreamArtistDormancyOwner,
    StreamArtistDormancyTypes as Dorm
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";

/// @notice Complete original authority, cause, closure and staging history for added recovery profiles.
/// @dev The caller retains origin/capability admission. This proof follows actual records through
/// an optional original40/43 to the latest35 or genuinely empty initial baseline. It writes nothing.
library StreamArtistRecoveryFamilyHistory {
    /// @dev Dispatch only. Authentication remains in read and the original origin readers.
    /// Do not re-encode histories already admitted by the older context paths.
    function required(
        State.State storage recovery,
        Rotations.State storage rotations,
        Resolution.State storage resolutions,
        Hashes.Environment memory e,
        D.Cause memory current
    ) public view returns (bool) {
        return Profile.required(recovery, rotations, resolutions, e, current);
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
        bytes32 artistId;
        D.Cause current;
        Current.Facts capture;
        I.Record root;
        V.Snapshot bridge;
        R.TransitionState bridgeTransition;
        Dorm.Notice notice;
        Dorm.Terminal completion;
        Ancestry.Member[] members;
        Episode[] episodes;
    }

    function read(
        State.State storage recovery,
        Rotations.State storage rotations,
        Resolution.State storage resolutions,
        Hashes.Environment memory e,
        D.Cause memory current,
        V.Snapshot memory bridge,
        R.TransitionState memory bridgeTransition
    ) public view returns (bytes32) {
        Chain memory h;
        h.artistId = current.facts.artistId;
        h.current = current;
        h.bridge = bridge;
        h.bridgeTransition = bridgeTransition;
        R.TransitionState memory executed = IStreamArtistRotationReads(address(this))
            .artistTransitionState(rotations.latestExecution[h.artistId]);
        h.capture = Current.readFamily(address(this), e.registry, e.chainId, current, executed);
        bytes32 latest = recovery.latest[h.artistId];
        V.Snapshot memory origin;
        R.TransitionState memory original;
        bytes32 rootProof;
        if (latest != 0) {
            h.root = recovery.records[latest];
            origin = recovery.vestingHistory.snapshots[latest];
            original = recovery.transitions[latest];
            if (
                h.root.recordHash != latest || h.root.fields.artistId != h.artistId
                    || h.root.terms.expectedCauseHash == 0
            ) revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
            if (h.root.fields.vestedAuthorityClass == 1) {
                rootProof =
                Living.read(address(this), e.registry, e.chainId, h.artistId, latest).proof;
            } else if (h.root.fields.vestedAuthorityClass != 3 || bridge.transitionRecordHash != 0)
            {
                revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
            }
        }
        if (bridge.operationId == 43) {
            (bytes32 noticeHash,, bytes32 terminal) =
                IStreamArtistDormancyOwner(address(this)).dormancyNotice(h.artistId);
            uint8 phase;
            (h.notice, phase, h.completion) =
                IStreamArtistDormancyOwner(address(this)).dormancyRecord(noticeHash);
            if (
                phase != 3 || terminal != bridge.transitionRecordHash
                    || h.completion.recordHash != terminal || h.completion.noticeHash != noticeHash
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
            }
        }
        uint64 before = h.capture.pending.recordHash == 0
            ? current.facts.enteredAt
            : h.capture.pending.transition.stagedAt;
        Ancestry.Facts memory ancestry = Ancestry.readWithBridge(
            recovery, rotations, e, current, origin, original, bridge, bridgeTransition, before
        );
        h.members = ancestry.members;
        bytes32 episodes = _episodes(rotations, resolutions, e, h);
        bytes32 closures = _closures(rotations, resolutions, e, h);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_STAGING_FAMILY_HISTORY_V1"),
                e.chainId,
                e.registry,
                address(this),
                h.root,
                rootProof,
                bridge,
                bridgeTransition,
                current,
                h.capture.proof,
                ancestry.proof,
                episodes,
                closures
            )
        );
    }

    function _episodes(
        Rotations.State storage rotations,
        Resolution.State storage resolutions,
        Hashes.Environment memory e,
        Chain memory h
    ) private view returns (bytes32 proof) {
        bytes32 selected = h.current.facts.previousCauseHash;
        bytes32 baseline = h.root.terms.expectedCauseHash;
        uint256 count;
        while (selected != baseline) {
            D.Cause memory cause = resolutions.causes[selected];
            _cause(e, cause, h.artistId, selected);
            selected = cause.facts.previousCauseHash;
            ++count;
        }
        h.episodes = new Episode[](count);
        selected = h.current.facts.previousCauseHash;
        bytes32 resolution = h.current.facts.previousResolutionHash;
        uint64 nextAt = h.current.facts.enteredAt;
        Dorm.Notice memory newer;
        bool activeBetween;
        for (uint256 i; i < count; ++i) {
            Episode memory x;
            x.cause = resolutions.causes[selected];
            x.dismissal = resolutions.records[resolution];
            Ancestry.Member memory m = _member(h, x.cause.facts.executedTransitionHash);
            uint8 class_ = m.vesting.transitionRecordHash == 0 ? 1 : m.vesting.authorityClass;
            uint64 boundary = nextAt < m.before ? nextAt : m.before;
            if (
                x.cause.facts.authorityClass != class_ || x.cause.facts.incumbent != m.incumbent
                    || x.cause.facts.enteredAt < m.transition.executedAt
                    || x.cause.facts.enteredAt > boundary || x.dismissal.dismissedAt > boundary
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
            }
            if (x.cause.facts.priorStatus == 2) {
                (bytes32 noticeHash, uint8 phase,) = IStreamArtistDormancyOwner(address(this))
                    .dormancyResolutionState(h.artistId, selected);
                if (phase == 3) {
                    if (h.bridge.operationId != 43 || noticeHash != h.notice.recordHash) {
                        revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
                    }
                    (x.proof, x.contest) = NoticeHistory.selected(
                        resolutions,
                        e,
                        h.notice,
                        h.completion,
                        h.bridge,
                        selected,
                        resolution,
                        boundary
                    );
                    x.notice = h.notice;
                } else {
                    Cancelled.Facts memory old = Cancelled.readAt(
                        resolutions, e, h.artistId, selected, resolution, h.current.facts.enteredAt
                    );
                    if (
                        old.notice.incumbent != m.incumbent
                            || old.notice.initiatedAt < m.transition.executedAt
                            || old.cancellation.observedAt > m.before
                            || (h.notice.recordHash != 0
                                && (old.cancellation.observedAt > h.notice.initiatedAt
                                    || old.notice.priorActivity >= h.notice.priorActivity))
                    ) {
                        revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
                    }
                    x.notice = old.notice;
                    x.cancellation = old.cancellation;
                    x.contest = old.contest;
                    x.proof = old.proof;
                }
                if (x.notice.recordHash == newer.recordHash) {
                    if (activeBetween || x.dismissal.restoredStatus != 2) {
                        revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
                    }
                } else if (
                    newer.recordHash != 0
                        && (x.notice.priorActivity >= newer.priorActivity
                            || x.cancellation.recordHash == 0
                            || x.cancellation.observedAt > newer.initiatedAt)
                ) {
                    revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
                }
                newer = x.notice;
                activeBetween = false;
            } else {
                if (x.cause.facts.priorStatus != class_) {
                    revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
                }
                (Estate.RequestRecord memory request,,) = IStreamArtistEstateOwner(address(this))
                    .estateActivationRecord(x.cause.facts.pendingTransitionHash);
                x.proof = request.recordHash != 0
                    && request.recordHash == x.cause.facts.pendingTransitionHash
                    ? EstateEpisode.read(
                        resolutions,
                        e,
                        h.artistId,
                        m.transition,
                        m.incumbent,
                        class_,
                        boundary,
                        selected,
                        resolution
                    )
                    : Closed.selectedFamily(
                        rotations,
                        resolutions,
                        e,
                        h.artistId,
                        m.transition,
                        m.incumbent,
                        class_,
                        boundary,
                        selected,
                        resolution
                    );
                if (x.cause.facts.kind == 1) {
                    x.contest = IStreamArtistIdentityContestOwner(address(this))
                        .identityContestRecord(x.cause.facts.referenceHash);
                }
                activeBetween = true;
            }
            proof = keccak256(abi.encode(proof, x.proof, m.vesting, m.incumbent, m.before));
            h.episodes[i] = x;
            nextAt = x.cause.facts.enteredAt;
            selected = x.cause.facts.previousCauseHash;
            resolution = x.cause.facts.previousResolutionHash;
        }
        if (resolution != h.root.terms.expectedResolutionHash) {
            revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
        }
    }

    function _member(Chain memory h, bytes32 execution)
        private
        pure
        returns (Ancestry.Member memory)
    {
        for (uint256 i; i < h.members.length; ++i) {
            if (h.members[i].transition.recordHash == execution) return h.members[i];
        }
        revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
    }

    function _closures(
        Rotations.State storage rotations,
        Resolution.State storage resolutions,
        Hashes.Environment memory e,
        Chain memory h
    ) private view returns (bytes32 proof) {
        for (uint256 i; i < h.members.length; ++i) {
            Ancestry.Member memory m = h.members[i];
            bytes32 closure = _closure(resolutions, h, m, i == 0);
            Stages.Head memory stage;
            uint64 before = m.before;
            if (i == 0) {
                stage = h.capture.pending.recordHash == 0
                    ? Stages.current(address(this), e.registry, e.chainId, h.artistId)
                    : Stages.beforeRotation(
                        address(this),
                        e.registry,
                        e.chainId,
                        h.artistId,
                        h.capture.pending.recordHash
                    );
                if (h.capture.pending.recordHash == 0) {
                    // Bind cancellation order to the cause, independently of later preparation.
                    stage.boundaryRevision = Stages.compromiseRevision(
                        address(this),
                        e.registry,
                        e.chainId,
                        h.artistId,
                        h.current.facts.referenceHash
                    );
                }
            } else {
                Ancestry.Member memory child = h.members[i - 1];
                if (child.vesting.operationId == 32) {
                    stage = Stages.beforeRotation(
                        address(this),
                        e.registry,
                        e.chainId,
                        h.artistId,
                        child.transition.recordHash
                    );
                } else if (child.vesting.operationId == 40) {
                    stage = Stages.beforeEstate(
                        address(this),
                        e.registry,
                        e.chainId,
                        h.artistId,
                        child.transition.recordHash
                    );
                } else if (child.vesting.operationId == 43) {
                    stage = Stages.beforeNotice(
                        address(this), e.registry, e.chainId, h.artistId, h.notice.recordHash
                    );
                    before = child.transition.stagedAt;
                    _eligibleAt(resolutions, h, m.transition, before, stage.boundaryRevision);
                } else {
                    revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
                }
            }
            bytes32 staging = _staging(rotations, resolutions, e, h, m, stage, before);
            proof = keccak256(abi.encode(proof, m, closure, staging));
        }
    }

    function _staging(
        Rotations.State storage rotations,
        Resolution.State storage resolutions,
        Hashes.Environment memory e,
        Chain memory h,
        Ancestry.Member memory m,
        Stages.Head memory stage,
        uint64 before
    ) private view returns (bytes32 proof) {
        proof = stage.proof;
        while (stage.recordHash != m.transition.recordHash) {
            if (stage.operation == 38) {
                Stages.EstateFacts memory estate = Stages.cancelledEstate(
                    address(this),
                    e.registry,
                    e.chainId,
                    h.artistId,
                    stage.recordHash,
                    stage.boundaryRevision
                );
                if (
                    estate.request.incumbent != m.incumbent
                        || estate.request.requestedAt < m.transition.executedAt
                        || estate.request.requestedAt > before
                ) {
                    revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
                }
                _eligibleAt(
                    resolutions,
                    h,
                    m.transition,
                    estate.request.requestedAt,
                    estate.requestReplay.touchedRevision
                );
                proof = keccak256(
                    abi.encode(
                        proof, estate.proof, _estateClosure(resolutions, h, estate.transition)
                    )
                );
                before = estate.request.requestedAt;
                stage = Stages.beforeEstate(
                    address(this), e.registry, e.chainId, h.artistId, stage.recordHash
                );
            } else if (stage.operation == 29) {
                R.RotationRecord memory pending = rotations.rotations[stage.recordHash];
                bytes32 dismissed =
                    _pending(h, resolutions, m.transition.recordHash, stage.recordHash, before);
                if (
                    pending.terms.oldAddress != m.incumbent
                        || pending.transition.stagedAt < m.transition.executedAt
                ) {
                    revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
                }
                proof = keccak256(abi.encode(proof, dismissed));
                before = pending.transition.stagedAt;
                stage = Stages.beforeRotation(
                    address(this), e.registry, e.chainId, h.artistId, stage.recordHash
                );
                _eligibleAt(resolutions, h, m.transition, before, stage.boundaryRevision);
            } else {
                revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
            }
            proof = keccak256(abi.encode(proof, stage.proof));
        }
    }

    function _pending(
        Chain memory h,
        Resolution.State storage resolutions,
        bytes32 execution,
        bytes32 pending,
        uint64 before
    ) private view returns (bytes32) {
        D.Closure memory closure = resolutions.closures[pending];
        for (uint256 i; i < h.episodes.length; ++i) {
            Episode memory x = h.episodes[i];
            if (x.dismissal.recordHash != closure.dismissalRecordHash) continue;
            if (
                x.cause.facts.executedTransitionHash != execution
                    || x.cause.facts.pendingTransitionHash != pending
                    || x.dismissal.dismissedAt > before
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
            }
            return keccak256(abi.encode(x.proof, closure, pending, execution, before));
        }
        revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
    }

    function _estateClosure(
        Resolution.State storage resolutions,
        Chain memory h,
        R.TransitionState memory t
    ) private view returns (bytes32) {
        D.Closure memory closure = resolutions.closures[t.recordHash];
        D.Closure memory empty;
        if (h.current.facts.pendingTransitionHash == t.recordHash) {
            if (
                h.current.facts.kind != 1 || t.contestedAt != h.current.facts.enteredAt
                    || keccak256(abi.encode(closure)) != keccak256(abi.encode(empty))
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
            }
            return 0;
        }
        for (uint256 i; i < h.episodes.length; ++i) {
            Episode memory x = h.episodes[i];
            if (x.cause.facts.pendingTransitionHash != t.recordHash) continue;
            // The selected Estate episode has already authenticated this original closure.
            if (
                x.cause.facts.kind != 1 || t.contestedAt != x.cause.facts.enteredAt
                    || closure.dismissalRecordHash != x.dismissal.recordHash
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
            }
            return keccak256(abi.encode(x.proof, closure));
        }
        if (t.contestedAt != 0 || keccak256(abi.encode(closure)) != keccak256(abi.encode(empty))) {
            revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
        }
        return 0;
    }

    function _closure(
        Resolution.State storage resolutions,
        Chain memory h,
        Ancestry.Member memory m,
        bool terminal
    ) private view returns (bytes32) {
        R.TransitionState memory t = m.transition;
        if (t.recordHash == 0) {
            D.Closure memory zero;
            if (
                keccak256(abi.encode(resolutions.closures[bytes32(0)]))
                    != keccak256(abi.encode(zero))
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
            }
            return 0;
        }
        D.Closure memory c = resolutions.closures[t.recordHash];
        (bool found, uint256 index) = _first(h, t.recordHash);
        if (!found) {
            D.Closure memory empty;
            if (
                keccak256(abi.encode(c)) != keccak256(abi.encode(empty))
                    || t.postWindowEndsAt > m.before
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
            }
            if (terminal) {
                uint64 expected = h.current.facts.kind == 1 ? h.current.facts.enteredAt : 0;
                if (t.contestedAt != expected) {
                    revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
                }
                return 0;
            }
            if (t.contestedAt == 0) return 0;
            bytes32 late = _lateSubject(h, t.recordHash, t.contestedAt);
            if (late == 0 || t.contestedAt < m.before) {
                revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
            }
            return keccak256(abi.encode(t, late, m.before));
        }
        Episode memory x = h.episodes[index];
        bool abandoned = t.contestedAt != 0 && t.contestedAt < t.postWindowEndsAt;
        if (
            c.artistId != h.artistId || c.transitionRecordHash != t.recordHash
                || c.dismissalRecordHash != x.dismissal.recordHash
                || c.windowEndsAt != t.postWindowEndsAt || c.contestedAt != t.contestedAt
                || c.abandoned != abandoned || x.dismissal.dismissedAt > m.before
                || (!abandoned && x.dismissal.dismissedAt < t.postWindowEndsAt)
                || (t.contestedAt != 0 && t.contestedAt < t.executedAt)
                || (x.cause.facts.kind == 1
                        ? t.contestedAt != x.cause.facts.enteredAt
                        : t.contestedAt != 0 || abandoned
                        || x.cause.facts.enteredAt < t.postWindowEndsAt)
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
        }
        if (
            x.cause.facts.priorStatus == 2
                && (abandoned
                    || x.notice.initiatedAt < t.postWindowEndsAt
                    || x.cancellation.observedAt > m.before)
        ) revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
        return keccak256(abi.encode(c, t, x.proof, m.before));
    }

    function _eligibleAt(
        Resolution.State storage resolutions,
        Chain memory h,
        R.TransitionState memory t,
        uint64 at,
        uint64 revision
    ) private view {
        if (t.recordHash == 0) return;
        if (at < t.executedAt) revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
        if (at >= t.postWindowEndsAt && (t.contestedAt == 0 || t.contestedAt >= t.postWindowEndsAt))
        {
            return;
        }
        (bool found, uint256 index) = _first(h, t.recordHash);
        if (
            !found || h.episodes[index].dismissal.dismissedAt > at
                || resolutions.closures[t.recordHash].dismissalRecordHash
                    != h.episodes[index].dismissal.recordHash
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
        }
        IStreamArtistOwner owner = IStreamArtistOwner(address(this));
        Episode memory x = h.episodes[index];
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                owner.artistRegistry(),
                owner.operationCoordinator(),
                owner.archiveV2(),
                address(this),
                owner.domainId(),
                keccak256("identity_authority.replay.contest_resolution"),
                keccak256(abi.encode(h.artistId, x.cause.causeHash))
            )
        );
        T.ReplayCell memory cell = owner.replayCell(key);
        if (
            cell.commitment != x.dismissal.recordHash || cell.kind != 1 || cell.status != 2
                || cell.touchedRevision == 0 || cell.touchedRevision >= revision
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
        }
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
        if (
            h.current.facts.kind == 1 && h.current.facts.enteredAt == at
                && h.capture.contest.terms.subjectRecordHash == execution
        ) return keccak256(abi.encode(h.current, h.capture.contest));
        for (uint256 i; i < h.episodes.length; ++i) {
            Episode memory x = h.episodes[i];
            if (
                x.cause.facts.kind == 1 && x.cause.facts.enteredAt == at
                    && x.contest.terms.subjectRecordHash == execution
            ) return keccak256(abi.encode(x.cause, x.contest));
        }
        return 0;
    }

    function _cause(Hashes.Environment memory e, D.Cause memory c, bytes32 id, bytes32 expected)
        private
        view
    {
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
        ) revert I.UnsupportedIdentityRecoveryProfile(id);
    }
}
