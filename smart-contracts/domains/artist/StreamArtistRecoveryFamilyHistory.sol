// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveryFamilyEligibility as Fixed } from "./StreamArtistRecoveryFamilyEligibility.sol";
import { StreamArtistRecoveryFamilyEpisodes as Worker } from "./StreamArtistRecoveryFamilyEpisodes.sol";

import {
    StreamArtistIdentityRecoveryState as State
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistRotationState as Rotations } from "./StreamArtistRotationState.sol";
import {
    StreamArtistIdentityResolutionState as Resolution
} from "./StreamArtistIdentityResolutionState.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistCurrentNoticeRecoveryReads as CurrentNotice
} from "./StreamArtistCurrentNoticeRecoveryReads.sol";
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
    IStreamArtistIdentityRecoveryOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
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

import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationState as Imported
} from "./StreamArtistRecoveredHydrationState.sol";

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
        if (Imported.commitment() != 0) return true;
        return Profile.required(recovery, rotations, resolutions, e, current);
    }

    struct Episode {
        D.Cause cause;
        D.Record dismissal;
        C.Record contest;
        Dorm.Notice notice;
        Dorm.Terminal cancellation;
        bytes32 proof;
        bytes32 recoveryRecordHash;
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
        I.Record[] recoveries;
        bool adjudication;
        bool withNotice;
    }

    /// @notice Full explicit adjudication history over caller-authenticated complete ancestry.
    /// @dev Original read() remains unchanged. Here successful35s consume actual causes without
    /// inventing dismissals, and an early current33 may exit through recovery itself.
    function readAdjudication(
        State.State storage recovery,
        Rotations.State storage rotations,
        Resolution.State storage resolutions,
        Hashes.Environment memory e,
        D.Cause memory current,
        Ancestry.Facts memory ancestry,
        V.Snapshot memory bridge,
        R.TransitionState memory bridgeTransition
    ) public view returns (bytes32) {
        return _readAdjudication(
            recovery, rotations, resolutions, e, current, ancestry, bridge, bridgeTransition, false
        );
    }

    function readAdjudicationWithNotice(
        State.State storage recovery,
        Rotations.State storage rotations,
        Resolution.State storage resolutions,
        Hashes.Environment memory e,
        D.Cause memory current,
        Ancestry.Facts memory ancestry,
        V.Snapshot memory bridge,
        R.TransitionState memory bridgeTransition
    ) public view returns (bytes32) {
        return _readAdjudication(
            recovery, rotations, resolutions, e, current, ancestry, bridge, bridgeTransition, true
        );
    }

    function _readAdjudication(
        State.State storage recovery,
        Rotations.State storage rotations,
        Resolution.State storage resolutions,
        Hashes.Environment memory e,
        D.Cause memory current,
        Ancestry.Facts memory ancestry,
        V.Snapshot memory bridge,
        R.TransitionState memory bridgeTransition,
        bool withNotice
    ) private view returns (bytes32) {
        Chain memory h;
        h.artistId = current.facts.artistId;
        h.current = current;
        h.bridge = bridge;
        h.bridgeTransition = bridgeTransition;
        h.adjudication = true;
        h.withNotice = withNotice;
        h.members = ancestry.members;
        if (h.members.length == 0 || ancestry.proof == 0) {
            revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
        }
        h.capture = withNotice && current.facts.priorStatus == 2
            ? Current.readNotice(
                address(this), e.registry, e.chainId, current, h.members[0].transition
            )
            : Current.readFamily(
                address(this), e.registry, e.chainId, current, h.members[0].transition
            );
        h.recoveries = new I.Record[](h.members.length);
        for (uint256 i; i < h.members.length; ++i) {
            if (h.members[i].vesting.operationId == 35) {
                h.recoveries[i] = recovery.records[h.members[i].transition.recordHash];
            }
        }
        if (bridge.operationId == 43) {
            (bytes32 noticeHash, uint8 phase, bytes32 terminal) =
                IStreamArtistDormancyOwner(address(this)).dormancyNotice(h.artistId);
            uint8 savedPhase;
            (h.notice, savedPhase, h.completion) =
                IStreamArtistDormancyOwner(address(this)).dormancyRecord(noticeHash);
            if (
                phase != 3 || savedPhase != 3 || terminal != bridge.transitionRecordHash
                    || h.completion.recordHash != terminal || h.completion.noticeHash != noticeHash
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
            }
        }
        bytes32 episodes = _episodes(rotations, resolutions, e, h);
        for (uint256 i; i < h.recoveries.length; ++i) {
            if (h.recoveries[i].recordHash == 0) continue;
            bool found;
            for (uint256 j; j < h.episodes.length; ++j) {
                if (h.episodes[j].recoveryRecordHash == h.recoveries[i].recordHash) found = true;
            }
            if (!found) revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
        }
        bytes32 closures = _closures(rotations, resolutions, e, h);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_COMPLETE_CAUSE_HISTORY_V2"),
                e.chainId,
                e.registry,
                address(this),
                current,
                h.capture.proof,
                ancestry.proof,
                bridge,
                bridgeTransition,
                episodes,
                closures
            )
        );
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
        (proof, h.episodes) = Worker._episodes(rotations, resolutions, e, h);
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
                    if (Imported.commitment() != 0) {
                        stage.boundaryPoint = Stages.compromisePoint(
                            address(this),
                            e.registry,
                            e.chainId,
                            h.artistId,
                            h.current.facts.referenceHash
                        );
                    }
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
                    Fixed._eligibleAt(
                        resolutions,
                        h,
                        m.transition,
                        before,
                        stage.boundaryRevision,
                        stage.boundaryPoint
                    );
                } else if (h.adjudication && child.vesting.operationId == 35) {
                    stage = Stages.beforeRecovery(
                        address(this),
                        e.registry,
                        e.chainId,
                        h.artistId,
                        child.transition.recordHash
                    );
                } else {
                    revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
                }
            }
            if (h.withNotice) {
                D.Cause memory noticeCause;
                if (i == 0 && h.current.facts.priorStatus == 2) {
                    noticeCause = h.current;
                } else if (i != 0 && h.members[i - 1].vesting.operationId == 35) {
                    I.Record memory childRecovery = IStreamArtistIdentityRecoveryOwner(
                            address(this)
                        ).identityRecoveryRecord(h.members[i - 1].transition.recordHash);
                    D.Cause memory consumed =
                        resolutions.causes[childRecovery.terms.expectedCauseHash];
                    if (consumed.facts.priorStatus == 2) noticeCause = consumed;
                }
                if (noticeCause.causeHash != 0) {
                    CurrentNotice.Facts memory notice = CurrentNotice.readCause(e, noticeCause);
                    Stages.Head memory atNotice = Stages.beforeNotice(
                        address(this), e.registry, e.chainId, h.artistId, notice.notice.recordHash
                    );
                    if (
                        stage.recordHash != atNotice.recordHash
                            || stage.operation != atNotice.operation
                            || stage.ownerRevision != atNotice.ownerRevision
                    ) {
                        revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
                    }
                    before = notice.notice.initiatedAt;
                    Fixed._eligibleAt(
                        resolutions,
                        h,
                        m.transition,
                        before,
                        atNotice.boundaryRevision,
                        atNotice.boundaryPoint
                    );
                    stage = atNotice;
                    proof = keccak256(abi.encode(proof, notice.proof));
                }
            }
            bytes32 staging = Fixed._staging(rotations, resolutions, e, h, m, stage, before);
            proof = keccak256(abi.encode(proof, m, closure, staging));
        }
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
                    || (t.postWindowEndsAt > m.before
                        && !(h.adjudication
                            && terminal
                            && h.current.facts.kind == 1
                            && h.capture.pending.recordHash == 0))
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
        if (h.adjudication && x.recoveryRecordHash != 0) {
            D.Closure memory empty;
            if (
                keccak256(abi.encode(c)) != keccak256(abi.encode(empty))
                    || t.contestedAt != (x.cause.facts.kind == 1 ? x.cause.facts.enteredAt : 0)
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
            }
            return keccak256(abi.encode(t, x.proof, m.before));
        }
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

}
