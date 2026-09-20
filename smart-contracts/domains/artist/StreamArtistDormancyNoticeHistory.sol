// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistCurrentNoticeRecoveryReads as CurrentNotice
} from "./StreamArtistCurrentNoticeRecoveryReads.sol";
import {
    StreamArtistIdentityResolutionState as Resolution
} from "./StreamArtistIdentityResolutionState.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
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
    IStreamArtistDormancyOwner,
    StreamArtistDormancyTypes as Dorm
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
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
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";

import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";
import {
    StreamArtistRecoveredHydrationState as Imported
} from "./StreamArtistRecoveredHydrationState.sol";

/// @notice Actual compromise and dismissal episodes during one completed dormancy notice.
/// @dev The caller authenticates the original notice, terminal and vesting snapshot and selects
/// the saved cause/resolution pair. Reads use the fixed Identity owner and its retained storage;
/// historical governance, retirement and the live dismissal context are never replayed.
library StreamArtistDormancyNoticeHistory {
    struct Facts {
        bytes32 proof;
        bytes32 previousCause;
        bytes32 previousResolution;
        bytes32 firstResolution;
        bytes32 closureProof;
    }

    /// @notice An original restored-status2 episode on a running or recovery-cancelled notice.
    /// @dev No completed43 snapshot is synthesized; the full walker supplies actual membership.
    function selectedUncompleted(
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        bytes32 causeHash,
        bytes32 resolutionHash,
        uint64 before
    )
        public
        view
        returns (
            bytes32 proof,
            Cont.Record memory contest,
            Dorm.Notice memory notice,
            Dorm.Terminal memory cancellation
        )
    {
        D.Cause memory cause = resolutions.causes[causeHash];
        CurrentNotice.Facts memory f = CurrentNotice.readCause(e, cause);
        _causeExact(
            e, f.notice, cause.facts.artistId, cause.facts.executedTransitionHash, cause, causeHash
        );
        D.Record memory dismissal = resolutions.records[resolutionHash];
        _dismissal(e, cause, dismissal, resolutionHash, before);
        if (f.phase == 2 && dismissal.dismissedAt > f.cancellation.observedAt) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(cause.facts.artistId);
        }
        contest = _contest(resolutions, e, cause);
        notice = f.notice;
        cancellation = f.cancellation;
        proof = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_UNCOMPLETED_NOTICE_EPISODE_V1"),
                f.proof,
                cause,
                dismissal,
                contest,
                before,
                CurrentNotice.dismissalProof(e, f, cause, dismissal)
            )
        );
    }

    /// @notice One original phase3-notice episode selected by a complete cross-origin walker.
    /// @dev The caller authenticates the notice/completion origin and checks its first closure.
    function selected(
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        Dorm.Notice memory notice,
        Dorm.Terminal memory terminal,
        V.Snapshot memory origin,
        bytes32 causeHash,
        bytes32 resolutionHash,
        uint64 before
    ) public view returns (bytes32 proof, Cont.Record memory contest) {
        D.Cause memory cause = resolutions.causes[causeHash];
        D.Record memory dismissal = resolutions.records[resolutionHash];
        _cause(e, notice, origin, cause, causeHash);
        _dismissal(e, cause, dismissal, resolutionHash, before);
        contest = _contest(resolutions, e, cause);
        (bytes32 savedNotice, uint8 phase, bytes32 savedTerminal) = IStreamArtistDormancyOwner(
                address(this)
            ).dormancyResolutionState(origin.artistId, causeHash);
        if (
            savedNotice != notice.recordHash || phase != 3 || savedTerminal != terminal.recordHash
                || terminal.noticeHash != notice.recordHash
                || origin.transitionRecordHash != terminal.recordHash
                || before > terminal.observedAt
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(origin.artistId);
        proof = keccak256(abi.encode(cause, dismissal, contest, savedNotice, phase, savedTerminal));
    }

    function read(
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        Dorm.Notice memory notice,
        Dorm.Terminal memory terminal,
        V.Snapshot memory origin,
        bytes32 causeHash,
        bytes32 resolutionHash
    ) public view returns (Facts memory f) {
        f.previousCause = causeHash;
        f.previousResolution = resolutionHash;
        if (resolutions.causes[causeHash].facts.priorStatus != 2) return f;
        if (
            e.chainId != block.chainid || e.registry == address(0)
                || IStreamArtistOwner(address(this)).deploymentChainId() != e.chainId
                || IStreamArtistOwner(address(this)).artistRegistry() != e.registry
                || origin.artistId == 0 || notice.terms.artistId != origin.artistId
                || notice.recordHash == 0 || notice.incumbent == address(0)
                || notice.initiatedAt == 0 || terminal.noticeHash != notice.recordHash
                || terminal.recordHash == 0 || terminal.observedAt < notice.initiatedAt
                || origin.transitionRecordHash != terminal.recordHash
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(origin.artistId);

        uint64 nextAt = terminal.observedAt;
        bytes32 episodes;
        bytes32 firstEpisode;
        while (resolutions.causes[f.previousCause].facts.priorStatus == 2) {
            D.Cause memory cause = resolutions.causes[f.previousCause];
            (bytes32 savedNotice, uint8 phase, bytes32 savedTerminal) = IStreamArtistDormancyOwner(
                    address(this)
                ).dormancyResolutionState(origin.artistId, cause.causeHash);
            // A cancelled earlier notice is a distinct historical episode. Leave the exact
            // pair for the cancelled-notice boundary reader rather than relabeling it as43.
            if (savedNotice != notice.recordHash && phase == 2) break;
            D.Record memory dismissal = resolutions.records[f.previousResolution];
            _cause(e, notice, origin, cause, f.previousCause);
            _dismissal(e, cause, dismissal, f.previousResolution, nextAt);
            Cont.Record memory contest = _contest(resolutions, e, cause);
            if (
                savedNotice != notice.recordHash || phase != 3
                    || savedTerminal != terminal.recordHash
            ) revert Recovery.UnsupportedIdentityRecoveryProfile(origin.artistId);
            firstEpisode = keccak256(
                abi.encode(cause, dismissal, contest, savedNotice, phase, savedTerminal)
            );
            episodes = keccak256(abi.encode(episodes, firstEpisode));
            f.firstResolution = dismissal.recordHash;
            nextAt = cause.facts.enteredAt;
            f.previousCause = cause.facts.previousCauseHash;
            f.previousResolution = cause.facts.previousResolutionHash;
            // Canonical immutable hash links cannot cycle. Same-block episodes remain valid.
        }
        if (f.firstResolution == 0) return f;
        f.closureProof = _closure(resolutions, notice, origin, f.firstResolution, firstEpisode);
        f.proof = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DORMANCY_NOTICE_HISTORY_V1"),
                e.chainId,
                e.registry,
                address(this),
                notice,
                terminal,
                origin,
                causeHash,
                resolutionHash,
                episodes,
                f.previousCause,
                f.previousResolution,
                f.firstResolution,
                f.closureProof
            )
        );
    }

    /// @notice Explain a historical subject's late marker using an authenticated notice suffix.
    /// @dev Call only after read() authenticated this exact entryCause and its contiguous status-2
    /// suffix. The caller binds that proof to the original notice and checks the ancestor's window
    /// and absence of closure. This lookup neither admits a new episode nor relaxes early contests.
    function lateSubject(
        Resolution.State storage resolutions,
        bytes32 entryCause,
        bytes32 transitionHash,
        uint64 contestedAt
    ) public view returns (bytes32 proof) {
        if (transitionHash == 0 || contestedAt == 0) return 0;
        D.Cause memory cause = resolutions.causes[entryCause];
        while (cause.facts.priorStatus == 2) {
            if (cause.facts.enteredAt == contestedAt) {
                Cont.Record memory contest = IStreamArtistIdentityContestOwner(address(this))
                    .identityContestRecord(cause.facts.referenceHash);
                if (contest.terms.subjectRecordHash == transitionHash) {
                    return keccak256(abi.encode(cause, contest));
                }
            }
            cause = resolutions.causes[cause.facts.previousCauseHash];
        }
    }

    function _cause(
        StreamArtistHashes.Environment memory e,
        Dorm.Notice memory notice,
        V.Snapshot memory origin,
        D.Cause memory cause,
        bytes32 expected
    ) private view {
        _causeExact(
            e, notice, origin.artistId, origin.previousTransitionRecordHash, cause, expected
        );
    }

    function _causeExact(
        StreamArtistHashes.Environment memory e,
        Dorm.Notice memory notice,
        bytes32 artistId,
        bytes32 execution,
        D.Cause memory cause,
        bytes32 expected
    ) private view {
        address originalOwner;
        (e, originalOwner) = _original(e, 33, cause.facts.artistId, cause.causeHash);
        if (
            expected == 0 || cause.causeHash != expected || cause.facts.artistId != artistId
                || cause.facts.kind != 1 || cause.facts.authorityClass != 1
                || cause.facts.priorStatus != 2 || cause.facts.pendingTransitionHash != 0
                || cause.facts.executedTransitionHash != execution
                || cause.facts.incumbent != notice.incumbent || cause.facts.actor == address(0)
                || cause.facts.referenceHash == 0 || cause.facts.evidenceHash == 0
                || cause.facts.reasonHash == 0 || cause.facts.enteredAt < notice.initiatedAt
                || cause.causeHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_IDENTITY_CONTEST_CAUSE_V1"),
                            e.chainId,
                            e.registry,
                            originalOwner,
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
        address originalOwner;
        (e, originalOwner) = _original(e, 58, r.terms.artistId, r.recordHash);
        if (
            expected == 0 || r.recordHash != expected || r.terms.artistId != cause.facts.artistId
                || r.terms.expectedCauseHash != cause.causeHash
                || r.terms.expectedResolutionHash != cause.facts.previousResolutionHash
                || r.terms.evidenceHash == 0 || r.terms.reasonHash == 0 || r.executor == address(0)
                || r.proposer == address(0) || (r.actionClass != 1 && r.actionClass != 2)
                || r.actionId == 0 || r.incumbent != cause.facts.incumbent || r.authorityClass != 1
                || r.restoredStatus != 2 || r.dismissedAt < cause.facts.enteredAt
                || r.dismissedAt > nextAt || r.cohortHash == 0 || r.governanceWitnessHash == 0
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
                            originalOwner,
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
        (e,) = _original(e, 33, c.terms.artistId, c.recordHash);
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
            // Other admitted transition kinds have different historical-subject writers.
            if (recovered.recordHash != subject.recordHash) return;
        }
        if (subject.contestedAt > cause.facts.enteredAt) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(cause.facts.artistId);
        }
        D.Closure memory closed = resolutions.closures[subject.recordHash];
        D.Closure memory empty;
        if (keccak256(abi.encode(closed)) == keccak256(abi.encode(empty))) {
            // Actual op33 marks every unclosed operation32/35 subject, including older ones.
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
        // A real mature standing closure can retain contestedAt=0; later filings preserve it.
    }

    function _closure(
        Resolution.State storage resolutions,
        Dorm.Notice memory notice,
        V.Snapshot memory origin,
        bytes32 firstResolution,
        bytes32 firstEpisode
    ) private view returns (bytes32) {
        D.Closure memory closed = resolutions.closures[origin.previousTransitionRecordHash];
        D.Closure memory empty;
        if (keccak256(abi.encode(closed)) == keccak256(abi.encode(empty))) {
            // Every admitted notice dismissal closes its captured nonzero execution.
            if (origin.previousTransitionRecordHash != 0) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(origin.artistId);
            }
            return 0;
        }
        if (origin.previousTransitionRecordHash == 0 || closed.dismissalRecordHash == 0) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(origin.artistId);
        }
        D.Record memory dismissal = resolutions.records[closed.dismissalRecordHash];
        D.Cause memory first = resolutions.causes[dismissal.terms.expectedCauseHash];
        if (closed.dismissalRecordHash != firstResolution) {
            // An earlier ACTIVE closure is authenticated by the caller's living boundary.
            // A NOTICE closure must be the first episode on this exact completed notice.
            if (first.facts.priorStatus == 2) {
                (bytes32 oldNotice, uint8 phase,) = IStreamArtistDormancyOwner(address(this))
                    .dormancyResolutionState(origin.artistId, first.causeHash);
                if (oldNotice == notice.recordHash || phase != 2) {
                    revert Recovery.UnsupportedIdentityRecoveryProfile(origin.artistId);
                }
            }
            return 0;
        }
        R.TransitionState memory t = IStreamArtistRotationReads(address(this))
            .artistTransitionState(origin.previousTransitionRecordHash);
        if (
            origin.previousTransitionRecordHash == 0 || closed.artistId != origin.artistId
                || closed.transitionRecordHash != origin.previousTransitionRecordHash
                || closed.abandoned || t.artistId != origin.artistId
                || t.recordHash != origin.previousTransitionRecordHash || t.phase != 2
                || t.executedAt == 0 || t.executedAt > notice.initiatedAt || t.postWindowEndsAt == 0
                || t.postWindowEndsAt > notice.initiatedAt
                || closed.windowEndsAt != t.postWindowEndsAt || closed.contestedAt != t.contestedAt
                || t.contestedAt != first.facts.enteredAt || t.contestedAt < t.executedAt
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(origin.artistId);
        return keccak256(abi.encode(closed, t, first, dismissal, firstEpisode));
    }

    function _original(
        StreamArtistHashes.Environment memory e,
        uint16 operation,
        bytes32 artistId,
        bytes32 record
    ) private view returns (StreamArtistHashes.Environment memory, address) {
        if (Imported.commitment() == 0) return (e, address(this));
        Runtime.ReceiptFact memory row = Recovered.nativeFact(
            Recovered.load(address(this), e.registry, e.chainId), operation, artistId, record
        );
        return (Recovered.hashes(row.environment), row.environment.owners[2]);
    }
}
