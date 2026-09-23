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

import {
    StreamArtistRecoveryFamilyHistory as Original
} from "./StreamArtistRecoveryFamilyHistory.sol";

/// @notice Fixed typed worker preserving the original validation and caller context.
library StreamArtistRecoveryFamilyEpisodes {
    function _episodes(
        Rotations.State storage rotations,
        Resolution.State storage resolutions,
        Hashes.Environment memory e,
        Original.Chain memory h
    ) public view returns (bytes32 proof, Original.Episode[] memory episodes) {
        bytes32 selected = h.current.facts.previousCauseHash;
        bytes32 baseline = h.root.terms.expectedCauseHash;
        uint256 count;
        uint256 ceiling = h.adjudication
            ? (Imported.commitment() == 0
                    ? IStreamArtistOwner(address(this)).ownerStateSnapshotV2().revision
                    : Runtime.logicalCount(Recovered.load(address(this), e.registry, e.chainId)))
            : 0;
        while (selected != baseline) {
            D.Cause memory cause = resolutions.causes[selected];
            _cause(e, cause, h.artistId, selected);
            selected = cause.facts.previousCauseHash;
            ++count;
            if (h.adjudication && count > ceiling) {
                revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
            }
        }
        h.episodes = new Original.Episode[](count);
        selected = h.current.facts.previousCauseHash;
        bytes32 resolution = h.current.facts.previousResolutionHash;
        uint64 nextAt = h.current.facts.enteredAt;
        Dorm.Notice memory newer;
        bool activeBetween;
        if (h.withNotice && h.current.facts.priorStatus == 2) {
            newer = CurrentNotice.readCause(e, h.current).notice;
        }
        for (uint256 i; i < count; ++i) {
            Original.Episode memory x;
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
            I.Record memory recovered = _consumed(h, selected);
            if (recovered.recordHash != 0) {
                if (
                    recovered.terms.expectedResolutionHash != resolution
                        || x.cause.facts.previousResolutionHash != resolution
                        || recovered.fields.oldAddress != m.incumbent
                        || recovered.fields.vestedAuthorityClass != class_
                        || recovered.fields.recoveredAt < x.cause.facts.enteredAt
                        || recovered.fields.recoveredAt > boundary
                ) {
                    revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
                }
                Current.Facts memory capture = h.withNotice && x.cause.facts.priorStatus == 2
                    ? Current.readConsumedNotice(
                        address(this), e.registry, e.chainId, x.cause, m.transition
                    )
                    : Current.readConsumed(
                        address(this), e.registry, e.chainId, x.cause, m.transition
                    );
                x.contest = capture.contest;
                x.recoveryRecordHash = recovered.recordHash;
                delete x.dismissal;
                x.proof = keccak256(
                    abi.encode(
                        recovered,
                        capture.proof,
                        _consumption(e, h.artistId, selected, recovered.recordHash)
                    )
                );
                if (h.withNotice && x.cause.facts.priorStatus == 2) {
                    CurrentNotice.Facts memory notice = CurrentNotice.readCause(e, x.cause);
                    if (
                        notice.phase != 2
                            || notice.cancellation.observedAt > recovered.fields.recoveredAt
                    ) {
                        revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
                    }
                    x.notice = notice.notice;
                    x.cancellation = notice.cancellation;
                    if (
                        newer.recordHash != 0 && newer.recordHash != notice.notice.recordHash
                            && (notice.notice.priorActivity >= newer.priorActivity
                                || notice.cancellation.observedAt > newer.initiatedAt)
                    ) {
                        revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
                    }
                    newer = notice.notice;
                    x.proof = keccak256(abi.encode(x.proof, notice.proof));
                }
                proof = keccak256(abi.encode(proof, x.proof, m.vesting, m.incumbent, m.before));
                h.episodes[i] = x;
                nextAt = x.cause.facts.enteredAt;
                selected = x.cause.facts.previousCauseHash;
                resolution = x.cause.facts.previousResolutionHash;
                activeBetween = !(h.withNotice && x.cause.facts.priorStatus == 2);
                continue;
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
                } else if (h.withNotice && (phase == 1 || _recoveryCancelledNotice(noticeHash))) {
                    (x.proof, x.contest, x.notice, x.cancellation) =
                        NoticeHistory.selectedUncompleted(
                            resolutions, e, selected, resolution, boundary
                        );
                    if (
                        x.notice.incumbent != m.incumbent
                            || x.notice.initiatedAt < m.transition.executedAt
                            || x.cancellation.observedAt > m.before
                    ) {
                        revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
                    }
                    if (phase == 1) {
                        (bytes32 currentNotice, uint8 currentPhase,) = IStreamArtistDormancyOwner(
                                address(this)
                            ).dormancyResolutionState(h.artistId, h.current.causeHash);
                        if (
                            h.current.facts.priorStatus != 2 || currentNotice != noticeHash
                                || currentPhase != 1
                        ) {
                            revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
                        }
                    }
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
        episodes = h.episodes;
    }

    function _member(Original.Chain memory h, bytes32 execution)
        private
        pure
        returns (Ancestry.Member memory)
    {
        for (uint256 i; i < h.members.length; ++i) {
            if (h.members[i].transition.recordHash == execution) return h.members[i];
        }
        revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
    }

    function _recoveryCancelledNotice(bytes32 hash) private view returns (bool) {
        (Dorm.Notice memory n, uint8 phase, Dorm.Terminal memory t) =
            IStreamArtistDormancyOwner(address(this)).dormancyRecord(hash);
        return phase == 2 && t.authorityClass == 1 && t.actor != n.incumbent;
    }

    function _cause(Hashes.Environment memory e, D.Cause memory c, bytes32 id, bytes32 expected)
        private
        view
    {
        address originalOwner = address(this);
        Hashes.Environment memory original = e;
        if (Imported.commitment() != 0) {
            Runtime.Context memory clock = Recovered.load(address(this), e.registry, e.chainId);
            Runtime.ReceiptFact memory row =
                Recovered.nativeFact(clock, c.facts.kind == 1 ? 33 : 31, id, expected);
            originalOwner = row.environment.owners[2];
            original = Recovered.hashes(row.environment);
        }
        if (
            expected == 0 || c.causeHash != expected || c.facts.artistId != id
                || c.facts.enteredAt == 0
                || c.causeHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_IDENTITY_CONTEST_CAUSE_V1"),
                            original.chainId,
                            original.registry,
                            originalOwner,
                            c.facts
                        )
                    )
        ) revert I.UnsupportedIdentityRecoveryProfile(id);
    }

    function _consumed(Original.Chain memory h, bytes32 cause)
        private
        pure
        returns (I.Record memory r)
    {
        if (!h.adjudication) return r;
        for (uint256 i; i < h.recoveries.length; ++i) {
            if (h.recoveries[i].recordHash != 0 && h.recoveries[i].terms.expectedCauseHash == cause)
            {
                if (r.recordHash != 0) revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
                r = h.recoveries[i];
            }
        }
    }

    function _consumption(
        Hashes.Environment memory e,
        bytes32 artistId,
        bytes32 cause,
        bytes32 record
    ) private view returns (T.ReplayCell memory cell) {
        IStreamArtistOwner owner = IStreamArtistOwner(address(this));
        if (Imported.commitment() != 0) {
            Runtime.Context memory clock = Recovered.load(address(this), e.registry, e.chainId);
            Runtime.ReplayFact memory replay = Runtime.replay(
                clock,
                RH.originHash(clock.current),
                keccak256("identity_authority.replay.contest_resolution"),
                keccak256(abi.encode(artistId, cause))
            );
            Runtime.ReceiptFact memory original = Recovered.nativeFact(clock, 35, artistId, record);
            if (
                replay.cell.commitment != record || replay.cell.kind != 1 || replay.cell.status != 2
                    || !Recovered.samePoint(replay.admission.point, original.position.point)
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(artistId);
            }
            return replay.cell;
        }
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                e.chainId,
                e.registry,
                owner.operationCoordinator(),
                owner.archiveV2(),
                address(this),
                owner.domainId(),
                keccak256("identity_authority.replay.contest_resolution"),
                keccak256(abi.encode(artistId, cause))
            )
        );
        cell = owner.replayCell(key);
        if (
            cell.commitment != record || cell.kind != 1 || cell.status != 2
                || cell.touchedRevision == 0
                || cell.touchedRevision > owner.ownerStateSnapshotV2().revision
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(artistId);
        }
    }
}
