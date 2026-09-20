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

/// @notice Original class-1/3 closures for recovery followed by executed rotations.
/// @dev Fixed-owner records and existing contest getter only; no historical authorization is replayed.
library StreamArtistRecoveryRotationClosure {
    function proof(
        StreamArtistRotationState.State storage rotations,
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        Dismissal.Cause memory current,
        R.TransitionState memory terminal
    ) public view returns (bytes32) {
        bytes32 closureProof = _closure(rotations, resolutions, e, current, terminal);
        bytes32 vetoProof = _lastVeto(rotations, resolutions, e, current, terminal);
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
        StreamArtistHashes.Environment memory e,
        R.TransitionState memory previous,
        address incumbent,
        uint64 stagedAt,
        uint8 authorityClass
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
        atNext.facts.authorityClass = authorityClass;
        atNext.facts.incumbent = incumbent;
        atNext.facts.enteredAt = stagedAt;
        atNext.facts.previousResolutionHash = closed.dismissalRecordHash;
        atNext.facts.previousCauseHash = original.terms.expectedCauseHash;
        return _closure(rotations, resolutions, e, atNext, previous);
    }

    /// @notice Authenticate one actual saved dismissal before a later authority boundary.
    /// @dev The caller proves this execution belongs to the admitted vesting ancestry and
    /// separately checks its first closure. This selects an immutable dismissal, not today's head.
    function resolvedBeforeNext(
        StreamArtistRotationState.State storage rotations,
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        R.TransitionState memory previous,
        address incumbent,
        uint64 boundaryAt,
        bytes32 causeHash,
        bytes32 resolutionHash
    ) public view returns (bytes32) {
        Dismissal.Record memory selected = resolutions.records[resolutionHash];
        if (causeHash == 0 || selected.terms.expectedCauseHash != causeHash) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(previous.artistId);
        }
        Dismissal.Cause memory boundary;
        boundary.facts.artistId = previous.artistId;
        boundary.facts.authorityClass = 1;
        boundary.facts.incumbent = incumbent;
        boundary.facts.enteredAt = boundaryAt;
        boundary.facts.previousCauseHash = causeHash;
        boundary.facts.previousResolutionHash = resolutionHash;
        bytes32 proof = _closure(rotations, resolutions, e, boundary, previous);
        if (proof == 0) revert Recovery.UnsupportedIdentityRecoveryProfile(previous.artistId);
        return proof;
    }

    /// @notice Authenticate the selected ACTIVE dismissal independently of its execution's
    /// immutable first closure. Cancelled-notice ancestry validates that first closure separately.
    function selectedBeforeNext(
        StreamArtistRotationState.State storage rotations,
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        bytes32 artistId,
        R.TransitionState memory previous,
        address incumbent,
        uint64 boundaryAt,
        bytes32 causeHash,
        bytes32 resolutionHash
    ) public view returns (bytes32) {
        Dismissal.Record memory selected = resolutions.records[resolutionHash];
        if (causeHash == 0 || selected.terms.expectedCauseHash != causeHash) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        }
        if (previous.recordHash == 0) {
            R.TransitionState memory empty;
            if (keccak256(abi.encode(previous)) != keccak256(abi.encode(empty))) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            }
        } else if (previous.artistId != artistId || previous.phase != 2 || previous.executedAt == 0)
        {
            revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        }
        Dismissal.CauseFacts memory boundary;
        boundary.artistId = artistId;
        boundary.authorityClass = 1;
        boundary.incumbent = incumbent;
        boundary.enteredAt = boundaryAt;
        if (resolutions.causes[causeHash].facts.kind == 2) {
            return
                _dismissed(rotations, resolutions, e, boundary, previous, selected, resolutionHash);
        }
        return _selectedCompromise(resolutions, e, boundary, previous, selected, resolutionHash);
    }

    /// @notice Authenticate a resolved ACTIVE episode, including an op33-aborted pending rotation.
    /// @dev Existing no-pending and standing-veto episodes retain their original proof bytes.
    /// The caller separately proves the captured execution's ancestry and immutable first closure.
    function selectedHistory(
        StreamArtistRotationState.State storage rotations,
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        bytes32 artistId,
        R.TransitionState memory previous,
        address incumbent,
        uint64 boundaryAt,
        bytes32 causeHash,
        bytes32 resolutionHash
    ) public view returns (bytes32) {
        Dismissal.Cause memory cause = resolutions.causes[causeHash];
        if (cause.facts.pendingTransitionHash == 0 || cause.facts.kind == 2) {
            return selectedBeforeNext(
                rotations,
                resolutions,
                e,
                artistId,
                previous,
                incumbent,
                boundaryAt,
                causeHash,
                resolutionHash
            );
        }
        Dismissal.Record memory selected = resolutions.records[resolutionHash];
        if (causeHash == 0 || selected.terms.expectedCauseHash != causeHash) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        }
        if (previous.recordHash == 0) {
            R.TransitionState memory empty;
            if (keccak256(abi.encode(previous)) != keccak256(abi.encode(empty))) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            }
        } else if (previous.artistId != artistId || previous.phase != 2 || previous.executedAt == 0)
        {
            revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        }
        Dismissal.CauseFacts memory boundary;
        boundary.artistId = artistId;
        boundary.authorityClass = 1;
        boundary.incumbent = incumbent;
        boundary.enteredAt = boundaryAt;
        bytes32 episode = _selectedCompromisePending(
            resolutions,
            e,
            boundary,
            previous,
            selected,
            resolutionHash,
            cause.facts.pendingTransitionHash
        );
        bytes32 pending = _abortedCompromise(rotations, resolutions, e, cause, selected, previous);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_SELECTED_PENDING_COMPROMISE_V1"), episode, pending
            )
        );
    }

    /// @notice The same immutable selected episode for living or designated class3 history.
    /// @dev Profile, actual executed ancestry and the first closure are proved by the caller.
    function selectedFamily(
        StreamArtistRotationState.State storage rotations,
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        bytes32 artistId,
        R.TransitionState memory previous,
        address incumbent,
        uint8 authorityClass,
        uint64 boundaryAt,
        bytes32 causeHash,
        bytes32 resolutionHash
    ) public view returns (bytes32) {
        if (authorityClass == 1) {
            return selectedHistory(
                rotations,
                resolutions,
                e,
                artistId,
                previous,
                incumbent,
                boundaryAt,
                causeHash,
                resolutionHash
            );
        }
        Dismissal.Cause memory cause = resolutions.causes[causeHash];
        Dismissal.Record memory selected = resolutions.records[resolutionHash];
        if (
            authorityClass != 3 || causeHash == 0 || selected.terms.expectedCauseHash != causeHash
                || previous.artistId != artistId || previous.recordHash == 0 || previous.phase != 2
                || previous.executedAt == 0
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        Dismissal.CauseFacts memory boundary;
        boundary.artistId = artistId;
        boundary.authorityClass = authorityClass;
        boundary.incumbent = incumbent;
        boundary.enteredAt = boundaryAt;
        if (cause.facts.kind == 2) {
            return
                _dismissed(rotations, resolutions, e, boundary, previous, selected, resolutionHash);
        }
        bytes32 episode = _selectedCompromisePending(
            resolutions,
            e,
            boundary,
            previous,
            selected,
            resolutionHash,
            cause.facts.pendingTransitionHash
        );
        if (cause.facts.pendingTransitionHash == 0) return episode;
        bytes32 pending = _abortedCompromise(rotations, resolutions, e, cause, selected, previous);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_SELECTED_PENDING_COMPROMISE_V1"), episode, pending
            )
        );
    }

    // Explicitly selected ACTIVE history may retain a zero or older op33 subject independently
    // from the actual execution captured by its cause. Original closure APIs keep their profile.
    /// @notice Read the actual ACTIVE compromise independently of any later dismissal.
    /// @dev The caller authenticates this cause and its captured execution/incumbent. Historical
    /// and zero subjects keep their own original op33 commitment and marker provenance.
    function compromiseRecord(
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        Dismissal.Cause memory cause,
        bytes32 execution
    ) public view returns (Contest.Record memory contest) {
        contest = IStreamArtistIdentityContestOwner(address(this))
            .identityContestRecord(cause.facts.referenceHash);
        _selectedContest(resolutions, e, cause, contest, execution);
    }

    function _selectedCompromise(
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        Dismissal.CauseFacts memory current,
        R.TransitionState memory t,
        Dismissal.Record memory r,
        bytes32 expected
    ) private view returns (bytes32) {
        return _selectedCompromisePending(resolutions, e, current, t, r, expected, bytes32(0));
    }

    function _selectedCompromisePending(
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        Dismissal.CauseFacts memory current,
        R.TransitionState memory t,
        Dismissal.Record memory r,
        bytes32 expected,
        bytes32 pending
    ) private view returns (bytes32) {
        Dismissal.Cause memory cause = resolutions.causes[r.terms.expectedCauseHash];
        if (
            current.artistId == 0 || current.incumbent == address(0) || expected == 0
                || r.recordHash != expected || r.terms.artistId != current.artistId
                || r.terms.evidenceHash == 0 || r.terms.reasonHash == 0 || r.executor == address(0)
                || r.proposer == address(0) || (r.actionClass != 1 && r.actionClass != 2)
                || r.actionId == 0 || r.incumbent != current.incumbent
                || r.authorityClass != current.authorityClass
                || (current.authorityClass != 1 && current.authorityClass != 3)
                || r.restoredStatus != current.authorityClass || r.dismissedAt == 0
                || r.dismissedAt > current.enteredAt || r.cohortHash == 0
                || r.governanceWitnessHash == 0
                || (r.terms.removePriorStanding
                        ? r.terms.expectedRetirementHash == 0
                        || r.terms.expectedRetirementHash != cause.facts.actorRetirementHash
                        : r.terms.expectedRetirementHash != 0)
                || r.recordHash != _dismissalHash(e, r) || cause.causeHash == 0
                || cause.causeHash != r.terms.expectedCauseHash
                || cause.causeHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_IDENTITY_CONTEST_CAUSE_V1"),
                            e.chainId,
                            e.registry,
                            address(this),
                            cause.facts
                        )
                    ) || cause.facts.artistId != current.artistId || cause.facts.kind != 1
                || cause.facts.authorityClass != current.authorityClass
                || cause.facts.priorStatus != current.authorityClass
                || cause.facts.executedTransitionHash != t.recordHash
                || cause.facts.incumbent != current.incumbent || cause.facts.actor == address(0)
                || cause.facts.referenceHash == 0 || cause.facts.enteredAt == 0
                || cause.facts.enteredAt < t.executedAt || cause.facts.enteredAt > r.dismissedAt
                || cause.facts.previousResolutionHash != r.terms.expectedResolutionHash
                || cause.facts.pendingTransitionHash != pending || cause.facts.evidenceHash == 0
                || cause.facts.reasonHash == 0
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(current.artistId);
        Contest.Record memory contest = IStreamArtistIdentityContestOwner(address(this))
            .identityContestRecord(cause.facts.referenceHash);
        _selectedContestPending(resolutions, e, cause, contest, t.recordHash, pending);
        return keccak256(abi.encode(r, cause, contest));
    }

    function _selectedContest(
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        Dismissal.Cause memory cause,
        Contest.Record memory c,
        bytes32 execution
    ) private view {
        _selectedContestPending(resolutions, e, cause, c, execution, bytes32(0));
    }

    function _selectedContestPending(
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        Dismissal.Cause memory cause,
        Contest.Record memory c,
        bytes32 execution,
        bytes32 pending
    ) private view {
        if (
            c.recordHash != cause.facts.referenceHash || c.terms.artistId != cause.facts.artistId
                || c.terms.evidenceHash != cause.facts.evidenceHash
                || c.terms.reasonHash != cause.facts.reasonHash || c.contester != cause.facts.actor
                || c.contestedAt != cause.facts.enteredAt
                || c.priorStatus != cause.facts.priorStatus
                || c.pendingTransitionRecordHash != pending
                || c.executedTransitionRecordHash != execution
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
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(cause.facts.artistId);
        }
        if (c.terms.subjectRecordHash == 0) return;
        R.TransitionState memory subject = IStreamArtistRotationReads(address(this))
            .artistTransitionState(c.terms.subjectRecordHash);
        if (
            subject.recordHash != c.terms.subjectRecordHash
                || subject.artistId != cause.facts.artistId
                || (subject.phase != 2 && subject.phase != 3) || subject.stagedAt == 0
                || subject.stagedAt > cause.facts.enteredAt
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(cause.facts.artistId);
        _selectedSubjectMarker(resolutions, cause, subject);
    }

    function _abortedCompromise(
        StreamArtistRotationState.State storage rotations,
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        Dismissal.Cause memory cause,
        Dismissal.Record memory dismissal,
        R.TransitionState memory executed
    ) private view returns (bytes32) {
        bytes32 hash = cause.facts.pendingTransitionHash;
        R.RotationRecord memory r = rotations.rotations[hash];
        _rotation(e, r, cause.facts.artistId, hash);
        Dismissal.Closure memory closed = resolutions.closures[hash];
        Contest.Record memory contest = IStreamArtistIdentityContestOwner(address(this))
            .identityContestRecord(cause.facts.referenceHash);
        if (
            hash == executed.recordHash || r.terms.oldAddress != cause.facts.incumbent
                || r.transition.phase != 3 || r.transition.executedAt != 0
                || r.transition.postWindowEndsAt != 0
                || r.transition.contestedAt != cause.facts.enteredAt
                || r.transition.contestedAt < r.transition.stagedAt
                || r.transition.stagedAt < executed.executedAt
                || contest.capturedGuardianSetRecordHash != r.guardianSetRecordHash
                || closed.artistId != cause.facts.artistId || closed.transitionRecordHash != hash
                || closed.dismissalRecordHash != dismissal.recordHash || !closed.abandoned
                || closed.windowEndsAt != r.transition.contestEndsAt
                || closed.contestedAt != r.transition.contestedAt
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(cause.facts.artistId);
        return keccak256(abi.encode(dismissal, cause, contest, r, closed));
    }

    function _selectedSubjectMarker(
        Resolution.State storage resolutions,
        Dismissal.Cause memory cause,
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
        Dismissal.Closure memory closed = resolutions.closures[subject.recordHash];
        Dismissal.Closure memory empty;
        if (keccak256(abi.encode(closed)) == keccak256(abi.encode(empty))) {
            if (subject.contestedAt == 0) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(cause.facts.artistId);
            }
            return;
        }
        Dismissal.Record memory dismissal = resolutions.records[closed.dismissalRecordHash];
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
    }

    function pendingBeforeNext(
        StreamArtistRotationState.State storage rotations,
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        R.TransitionState memory previous,
        bytes32 pending,
        address incumbent,
        uint64 stagedAt,
        uint8 authorityClass
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
        atNext.authorityClass = authorityClass;
        atNext.incumbent = incumbent;
        atNext.enteredAt = stagedAt;
        return _dismissed(
            rotations, resolutions, e, atNext, previous, original, closed.dismissalRecordHash
        );
    }

    // Consume authenticated immutable owner records, not a fresh historical governance decision.
    // Original immutable causes distinguish compromise from a pending-rotation standing veto.
    function _closure(
        StreamArtistRotationState.State storage rotations,
        Resolution.State storage resolutions,
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
    ) private view returns (bytes32) {
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
                || cause.causeHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_IDENTITY_CONTEST_CAUSE_V1"),
                            e.chainId,
                            e.registry,
                            address(this),
                            cause.facts
                        )
                    ) || cause.facts.artistId != current.artistId
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
        return
            _dismissed(rotations, resolutions, e, current.facts, t, r, closed.dismissalRecordHash);
    }

    function _dismissalHash(StreamArtistHashes.Environment memory e, Dismissal.Record memory r)
        private
        view
        returns (bytes32)
    {
        return keccak256(
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
        );
    }

    function _contest(
        StreamArtistHashes.Environment memory e,
        Dismissal.Cause memory cause,
        Recovery.Request memory p,
        Contest.Record memory c,
        bytes32 head
    ) private pure {
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
    ) private pure {
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
