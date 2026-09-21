// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRotationState } from "./StreamArtistRotationState.sol";
import {
    StreamArtistIdentityResolutionState as Resolution
} from "./StreamArtistIdentityResolutionState.sol";
import { StreamArtistRotationHashes } from "./StreamArtistRotationHashes.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
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
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as Dismissal
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "../../interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
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
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

import {
    StreamArtistRecoveryRotationClosure as Original
} from "./StreamArtistRecoveryRotationClosure.sol";

/// @notice Fixed typed worker preserving the original validation and caller context.
library StreamArtistRecoveryRotationClosureRecords {
    function _closure(
        StreamArtistRotationState.State storage rotations,
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        Dismissal.Cause memory current,
        R.TransitionState memory t
    ) public view returns (bytes32) {
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
            rotations, resolutions, e, current.facts, t, original, closed.dismissalRecordHash
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
        StreamArtistHashes.Environment memory e,
        Dismissal.CauseFacts memory current,
        R.TransitionState memory t,
        Dismissal.Record memory r,
        bytes32 expected
    ) public view returns (bytes32) {
        Dismissal.Cause memory cause = resolutions.causes[r.terms.expectedCauseHash];
        if (
            (current.authorityClass != 1 && current.authorityClass != 3) || expected == 0
                || r.recordHash != expected || r.terms.artistId != current.artistId
                || r.terms.evidenceHash == 0 || r.terms.reasonHash == 0 || r.executor == address(0)
                || r.proposer == address(0) || (r.actionClass != 1 && r.actionClass != 2)
                || r.actionId == 0 || r.incumbent != current.incumbent
                || r.authorityClass != current.authorityClass
                || r.restoredStatus != current.authorityClass || r.dismissedAt == 0
                || r.dismissedAt > current.enteredAt || r.cohortHash == 0
                || r.governanceWitnessHash == 0
                || (r.terms.removePriorStanding
                        ? r.terms.expectedRetirementHash == 0
                        || r.terms.expectedRetirementHash != cause.facts.actorRetirementHash
                        : r.terms.expectedRetirementHash != 0)
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
            return _standing(rotations, resolutions, e, cause, r, t);
        }
        if (
            cause.facts.pendingTransitionHash != 0 || cause.facts.evidenceHash == 0
                || cause.facts.reasonHash == 0
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(current.artistId);
        }
        Recovery.Request memory historical;
        historical.artistId = current.artistId;
        historical.vestedAuthorityClass = current.authorityClass;
        historical.evidenceHash = cause.facts.evidenceHash;
        historical.reasonHash = cause.facts.reasonHash;
        Contest.Record memory contest = IStreamArtistIdentityContestOwner(address(this))
            .identityContestRecord(cause.facts.referenceHash);
        _contest(e, cause, historical, contest, t.recordHash);
        return keccak256(abi.encode(r, cause, contest));
    }

    function _lastVeto(
        StreamArtistRotationState.State storage rotations,
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        Dismissal.Cause memory current,
        R.TransitionState memory t
    ) public view returns (bytes32) {
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
        return
            _dismissed(rotations, resolutions, e, current.facts, t, r, closed.dismissalRecordHash);
    }

    function _recordEnvironment(
        StreamArtistHashes.Environment memory e,
        bytes32 artistId,
        uint16 operation,
        bytes32 record
    ) public view returns (StreamArtistHashes.Environment memory) {
        if (Imported.commitment() == 0) return e;
        return Recovered.hashes(
            Recovered.nativeFact(
                Recovered.load(address(this), e.registry, e.chainId), operation, artistId, record
            )
            .environment
        );
    }

    function _causeHash(StreamArtistHashes.Environment memory e, Dismissal.Cause memory cause)
        public
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

    function _dismissalHash(StreamArtistHashes.Environment memory e, Dismissal.Record memory r)
        public
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
                revert Recovery.UnsupportedIdentityRecoveryProfile(r.terms.artistId);
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
        e = _recordEnvironment(e, c.terms.artistId, 33, c.recordHash);
        if (
            cause.facts.kind != 1 || cause.facts.authorityClass != p.vestedAuthorityClass
                || cause.facts.priorStatus != p.vestedAuthorityClass || c.recordHash == 0
                || c.recordHash != cause.facts.referenceHash || c.terms.artistId != p.artistId
                || c.terms.subjectRecordHash != head || c.terms.evidenceHash != p.evidenceHash
                || c.terms.reasonHash != p.reasonHash || cause.facts.evidenceHash != p.evidenceHash
                || cause.facts.reasonHash != p.reasonHash || c.contester != cause.facts.actor
                || c.contestedAt != cause.facts.enteredAt || c.priorStatus != p.vestedAuthorityClass
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

    function _standing(
        StreamArtistRotationState.State storage rotations,
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        Dismissal.Cause memory cause,
        Dismissal.Record memory dismissal,
        R.TransitionState memory executed
    ) private view returns (bytes32) {
        bytes32 hash = cause.facts.referenceHash;
        R.RotationRecord memory r = rotations.rotations[hash];
        _rotation(e, r, cause.facts.artistId, hash);
        Dismissal.Closure memory closed = resolutions.closures[hash];
        if (
            cause.facts.kind != 2 || cause.facts.authorityClass != dismissal.authorityClass
                || cause.facts.priorStatus != dismissal.authorityClass
                || cause.facts.evidenceHash != 0 || cause.facts.pendingTransitionHash != hash
                || cause.facts.executedTransitionHash != executed.recordHash
                || r.terms.oldAddress != cause.facts.incumbent || r.transition.phase != 3
                || r.transition.executedAt != 0 || r.transition.postWindowEndsAt != 0
                || r.transition.contestedAt != cause.facts.enteredAt
                || r.transition.contestedAt < r.transition.stagedAt
                || r.transition.stagedAt < executed.executedAt
                || closed.artistId != cause.facts.artistId || closed.transitionRecordHash != hash
                || closed.dismissalRecordHash != dismissal.recordHash || !closed.abandoned
                || closed.windowEndsAt != r.transition.contestEndsAt
                || closed.contestedAt != r.transition.contestedAt
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(cause.facts.artistId);
        }
        // op31 deliberately records zero evidence and permits a zero reason. The full immutable
        // Cause binds both, the original standing actor and retirement fact; op41 supplied evidence.
        return keccak256(abi.encode(dismissal, cause, r, closed));
    }

    function _rotation(
        StreamArtistHashes.Environment memory e,
        R.RotationRecord memory r,
        bytes32 artistId,
        bytes32 hash
    ) public view {
        e = _recordEnvironment(e, artistId, 29, hash);
        if (
            hash == 0 || r.recordHash != hash || r.terms.artistId != artistId
                || r.terms.oldAddress == address(0) || r.terms.newAddress == address(0)
                || r.terms.oldAddress == r.terms.newAddress || r.transition.artistId != artistId
                || r.transition.recordHash != hash || r.transition.stagedAt == 0
                || r.effectiveWindow < 72 hours || r.standingTail < 30 days || r.timingRevision == 0
                || uint256(r.transition.contestEndsAt)
                    != uint256(r.transition.stagedAt) + r.effectiveWindow
                || StreamArtistRotationHashes.rotationRecord(
                        e, r.terms, r.oldNonce, r.transition.stagedAt, r.transition.contestEndsAt
                    ) != hash
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        }
    }
}
