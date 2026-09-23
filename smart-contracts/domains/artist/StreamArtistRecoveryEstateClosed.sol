// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationState as Imported
} from "./StreamArtistRecoveredHydrationState.sol";
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
    StreamArtistIdentityRecoveryState as RecoveryState
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistEstateState as EstateState } from "./StreamArtistEstateState.sol";
import { StreamArtistEstateHashes } from "./StreamArtistEstateHashes.sol";
import {
    StreamArtistIdentityContestState as ContestState
} from "./StreamArtistIdentityContestState.sol";
import {
    StreamArtistIdentityResolutionState as Resolution
} from "./StreamArtistIdentityResolutionState.sol";
import {
    StreamArtistRecoveryEstateGuardians as EstateGuardians
} from "./StreamArtistRecoveryEstateGuardians.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistRecoveryEstateHistory as EstateHistory
} from "./StreamArtistRecoveryEstateHistory.sol";
import { StreamArtistRotationState } from "./StreamArtistRotationState.sol";
import { StreamArtistSuccessionState } from "./StreamArtistSuccessionState.sol";
import { StreamArtistSuccessionHashes } from "./StreamArtistSuccessionHashes.sol";
import {
    StreamArtistEstateTypes as Estate
} from "../../interfaces/stream/artist/StreamArtistEstateTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistSuccessionTypes as Succ
} from "../../interfaces/stream/artist/StreamArtistSuccessionTypes.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "../../interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as Dismissal
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";

/// @notice Historical closure proof for an admitted class-3 terminal rotation.
/// @dev Consumes canonical owner records; it never replays historical authorization.
library StreamArtistRecoveryEstateClosed {
    function proof(
        StreamArtistRotationState.State storage rotations,
        Resolution.State storage resolutions,
        ContestState.State storage contests,
        StreamArtistHashes.Environment memory e,
        Dismissal.Cause memory current,
        R.TransitionState memory terminal
    ) public view returns (bytes32) {
        bytes32 closureProof = _closure(rotations, resolutions, contests, e, current, terminal);
        bytes32 vetoProof = _lastVeto(rotations, resolutions, contests, e, current, terminal);
        if (vetoProof != 0 && closureProof == 0) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(current.facts.artistId);
        }
        if (closureProof == 0) return 0;
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_ROTATION_CLOSURE_V1"), closureProof, vetoProof
            )
        );
    }

    function beforeNext(
        StreamArtistRotationState.State storage rotations,
        Resolution.State storage resolutions,
        ContestState.State storage contests,
        StreamArtistHashes.Environment memory e,
        R.TransitionState memory previous,
        address incumbent,
        uint64 stagedAt
    ) public view returns (bytes32) {
        Dismissal.Closure memory closed = resolutions.closures[previous.recordHash];
        Dismissal.Closure memory empty;
        if (keccak256(abi.encode(closed)) == keccak256(abi.encode(empty))) {
            if (previous.contestedAt != 0 || stagedAt < previous.postWindowEndsAt) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(previous.artistId);
            }
            return 0;
        }
        Dismissal.Record memory original = resolutions.records[closed.dismissalRecordHash];
        Dismissal.Cause memory atNext;
        atNext.facts.artistId = previous.artistId;
        atNext.facts.incumbent = incumbent;
        atNext.facts.enteredAt = stagedAt;
        atNext.facts.previousResolutionHash = closed.dismissalRecordHash;
        atNext.facts.previousCauseHash = original.terms.expectedCauseHash;
        return _closure(rotations, resolutions, contests, e, atNext, previous);
    }

    function pendingBeforeNext(
        StreamArtistRotationState.State storage rotations,
        Resolution.State storage resolutions,
        ContestState.State storage contests,
        StreamArtistHashes.Environment memory e,
        R.TransitionState memory previous,
        bytes32 pending,
        address incumbent,
        uint64 stagedAt
    ) public view returns (bytes32) {
        Dismissal.Closure memory closed = resolutions.closures[pending];
        Dismissal.Record memory original = resolutions.records[closed.dismissalRecordHash];
        Dismissal.Cause memory cause = resolutions.causes[original.terms.expectedCauseHash];
        if (
            cause.facts.kind != 2 || cause.facts.referenceHash != pending
                || closed.transitionRecordHash != pending
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(previous.artistId);
        }
        Dismissal.CauseFacts memory atNext;
        atNext.artistId = previous.artistId;
        atNext.incumbent = incumbent;
        atNext.enteredAt = stagedAt;
        return _dismissed(
            rotations,
            resolutions,
            contests,
            e,
            atNext,
            previous,
            original,
            closed.dismissalRecordHash
        );
    }

    // Consume authenticated immutable owner records, not a fresh historical governance decision.
    // Original immutable causes distinguish compromise from a pending-rotation standing veto.
    function _closure(
        StreamArtistRotationState.State storage rotations,
        Resolution.State storage resolutions,
        ContestState.State storage contests,
        StreamArtistHashes.Environment memory e,
        Dismissal.Cause memory current,
        R.TransitionState memory t
    ) private view returns (bytes32) {
        Dismissal.Closure memory closed = resolutions.closures[t.recordHash];
        Dismissal.Closure memory empty;
        if (keccak256(abi.encode(closed)) == keccak256(abi.encode(empty))) {
            if (
                current.facts.enteredAt < t.postWindowEndsAt
                    || (t.contestedAt != 0 && t.contestedAt < t.postWindowEndsAt)
            ) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(current.facts.artistId);
            }
            return 0;
        }
        bool abandoned = t.contestedAt != 0 && t.contestedAt < t.postWindowEndsAt;
        if (
            closed.artistId != current.facts.artistId || closed.transitionRecordHash != t.recordHash
                || closed.dismissalRecordHash == 0 || closed.windowEndsAt != t.postWindowEndsAt
                || closed.contestedAt != t.contestedAt
                || (closed.contestedAt != 0 && closed.contestedAt < t.executedAt)
                || closed.abandoned != abandoned || current.facts.previousResolutionHash == 0
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(current.facts.artistId);
        }
        Dismissal.Record memory original = resolutions.records[closed.dismissalRecordHash];
        bytes32 originalProof = _dismissed(
            rotations,
            resolutions,
            contests,
            e,
            current.facts,
            t,
            original,
            closed.dismissalRecordHash
        );
        Dismissal.Cause memory firstCause = resolutions.causes[original.terms.expectedCauseHash];
        if (
            (firstCause.facts.kind == 1
                        ? firstCause.facts.enteredAt != closed.contestedAt
                        : closed.contestedAt != 0 || abandoned
                        || firstCause.facts.enteredAt < t.postWindowEndsAt)
                || (!abandoned && original.dismissedAt < t.postWindowEndsAt)
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(current.facts.artistId);
        }
        // The closure never moves. Today's latest admitted dismissal may be a later episode.
        Dismissal.Record memory latest = resolutions.records[current.facts.previousResolutionHash];
        bytes32 latestProof = _dismissed(
            rotations,
            resolutions,
            contests,
            e,
            current.facts,
            t,
            latest,
            current.facts.previousResolutionHash
        );
        if (
            latest.dismissedAt < original.dismissedAt
                || current.facts.previousCauseHash != latest.terms.expectedCauseHash
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(current.facts.artistId);
        }
        return keccak256(abi.encode(closed, originalProof, latestProof));
    }

    function _dismissed(
        StreamArtistRotationState.State storage rotations,
        Resolution.State storage resolutions,
        ContestState.State storage contests,
        StreamArtistHashes.Environment memory e,
        Dismissal.CauseFacts memory current,
        R.TransitionState memory t,
        Dismissal.Record memory r,
        bytes32 expected
    ) private view returns (bytes32) {
        Dismissal.Cause memory cause = resolutions.causes[r.terms.expectedCauseHash];
        if (
            expected == 0 || r.recordHash != expected || r.terms.artistId != current.artistId
                || r.terms.evidenceHash == 0 || r.terms.reasonHash == 0 || r.executor == address(0)
                || r.proposer == address(0) || (r.actionClass != 1 && r.actionClass != 2)
                || r.actionId == 0 || r.incumbent != current.incumbent || r.authorityClass != 3
                || r.restoredStatus != 3 || r.dismissedAt == 0 || r.dismissedAt > current.enteredAt
                || r.cohortHash == 0 || r.governanceWitnessHash == 0
                || r.recordHash != _dismissalHash(e, r) || cause.causeHash == 0
                || cause.causeHash != r.terms.expectedCauseHash
                || cause.causeHash != _causeHash(e, cause)
                || cause.facts.artistId != current.artistId
                || cause.facts.executedTransitionHash != t.recordHash
                || cause.facts.incumbent != current.incumbent || cause.facts.actor == address(0)
                || cause.facts.referenceHash == 0 || cause.facts.enteredAt < t.executedAt
                || cause.facts.enteredAt > r.dismissedAt
                || cause.facts.previousResolutionHash != r.terms.expectedResolutionHash
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(current.artistId);
        }
        if (cause.facts.kind == 2) {
            return EstateHistory.standing(rotations, resolutions, e, cause, r, t);
        }
        if (
            cause.facts.pendingTransitionHash != 0 || cause.facts.evidenceHash == 0
                || cause.facts.reasonHash == 0
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(current.artistId);
        }
        Recovery.Request memory historical;
        historical.artistId = current.artistId;
        historical.evidenceHash = cause.facts.evidenceHash;
        historical.reasonHash = cause.facts.reasonHash;
        Contest.Record memory contest = contests.records[cause.facts.referenceHash];
        _contest(e, cause, historical, contest, t.recordHash);
        return keccak256(abi.encode(r, cause, contest));
    }

    function _lastVeto(
        StreamArtistRotationState.State storage rotations,
        Resolution.State storage resolutions,
        ContestState.State storage contests,
        StreamArtistHashes.Environment memory e,
        Dismissal.Cause memory current,
        R.TransitionState memory t
    ) private view returns (bytes32) {
        bytes32 latest = rotations.latestTransition[current.facts.artistId];
        if (latest == t.recordHash) return 0;
        Dismissal.Closure memory closed = resolutions.closures[latest];
        Dismissal.Record memory r = resolutions.records[closed.dismissalRecordHash];
        Dismissal.Cause memory cause = resolutions.causes[r.terms.expectedCauseHash];
        if (
            latest == 0 || closed.transitionRecordHash != latest || cause.facts.kind != 2
                || cause.facts.referenceHash != latest
                || r.dismissedAt
                    > resolutions.records[current.facts.previousResolutionHash].dismissedAt
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(current.facts.artistId);
        }
        return _dismissed(
            rotations, resolutions, contests, e, current.facts, t, r, closed.dismissalRecordHash
        );
    }

    function _dismissalHash(StreamArtistHashes.Environment memory e, Dismissal.Record memory r)
        private
        view
        returns (bytes32)
    {
        address originalOwner = address(this);
        if (Imported.commitment() != 0) {
            Runtime.Context memory clock = Recovered.load(address(this), e.registry, e.chainId);
            Runtime.ReceiptFact memory row =
                Recovered.nativeFact(clock, 58, r.terms.artistId, r.recordHash);
            Runtime.ReplayFact memory replay = Runtime.replay(
                clock,
                RH.originHash(clock.current),
                keccak256("identity_authority.replay.contest_resolution"),
                keccak256(abi.encode(r.terms.artistId, r.terms.expectedCauseHash))
            );
            if (
                replay.cell.kind != 1 || replay.cell.status != 2
                    || replay.cell.commitment != r.recordHash
                    || !Recovered.samePoint(replay.admission.point, row.position.point)
            ) {
                revert RH.InvalidRecoveredHydrationProvenance();
            }
            e = Recovered.hashes(row.environment);
            originalOwner = row.environment.owners[2];
        }
        return keccak256(
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
        );
    }

    function _contest(
        StreamArtistHashes.Environment memory e,
        Dismissal.Cause memory cause,
        Recovery.Request memory p,
        Contest.Record memory c,
        bytes32 head
    ) private view {
        if (Imported.commitment() != 0) {
            e = Recovered.hashes(
                Recovered.nativeFact(
                    Recovered.load(address(this), e.registry, e.chainId),
                    33,
                    c.terms.artistId,
                    c.recordHash
                )
                .environment
            );
        }
        if (
            cause.facts.kind != 1 || cause.facts.authorityClass != 3 || cause.facts.priorStatus != 3
                || c.recordHash == 0 || c.recordHash != cause.facts.referenceHash
                || c.terms.artistId != p.artistId || c.terms.subjectRecordHash != head
                || c.terms.evidenceHash != p.evidenceHash || c.terms.reasonHash != p.reasonHash
                || cause.facts.evidenceHash != p.evidenceHash
                || cause.facts.reasonHash != p.reasonHash || c.contester != cause.facts.actor
                || c.contestedAt != cause.facts.enteredAt || c.priorStatus != 3
                || c.pendingTransitionRecordHash != 0 || c.executedTransitionRecordHash != head
                || c.recordHash
                    != keccak256(
                        abi.encode(
                            bytes32(
                                0x26a4221cd1625ab88b1ac279e1708a73efa176e486242b26832cdc94fe25e6bb
                            ),
                            e.chainId,
                            e.registry,
                            p.artistId,
                            c.contester,
                            head,
                            p.evidenceHash,
                            p.reasonHash,
                            c.contestedAt
                        )
                    )
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
    }

    function _causeHash(StreamArtistHashes.Environment memory e, Dismissal.Cause memory cause)
        private
        view
        returns (bytes32)
    {
        address originalOwner = address(this);
        if (Imported.commitment() != 0) {
            Runtime.ReceiptFact memory row = Recovered.nativeFact(
                Recovered.load(address(this), e.registry, e.chainId),
                cause.facts.kind == 1 ? 33 : 31,
                cause.facts.artistId,
                cause.causeHash
            );
            e = Recovered.hashes(row.environment);
            originalOwner = row.environment.owners[2];
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_CONTEST_CAUSE_V1"),
                e.chainId,
                e.registry,
                originalOwner,
                cause.facts
            )
        );
    }
}
