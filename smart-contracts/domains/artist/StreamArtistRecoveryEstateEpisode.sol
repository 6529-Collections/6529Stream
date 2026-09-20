// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistIdentityResolutionState as Resolution
} from "./StreamArtistIdentityResolutionState.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistRecoveryStagingHistory as Stages
} from "./StreamArtistRecoveryStagingHistory.sol";
import {
    IStreamArtistRotationReads
} from "../../interfaces/stream/artist/IStreamArtistRotation.sol";
import {
    IStreamArtistIdentityContestOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityContest.sol";
import {
    IStreamArtistIdentityRecoveryOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistIdentityContestTypes as C
} from "../../interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";

/// @notice An original ACTIVE1 compromise and dismissal that cancelled a pending estate request.
/// @dev The caller proves executed ancestry, first execution closure and later staging order.
/// This authenticates the request's own cancellation and closure without inventing a rotation.
library StreamArtistRecoveryEstateEpisode {
    function read(
        Resolution.State storage resolutions,
        Hashes.Environment memory e,
        bytes32 artistId,
        R.TransitionState memory previous,
        address incumbent,
        uint8 authorityClass,
        uint64 boundaryAt,
        bytes32 causeHash,
        bytes32 resolutionHash
    ) public view returns (bytes32) {
        D.Cause memory cause = resolutions.causes[causeHash];
        D.Record memory dismissal = resolutions.records[resolutionHash];
        if (authorityClass != 1) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        _episode(
            e,
            artistId,
            previous,
            incumbent,
            boundaryAt,
            causeHash,
            resolutionHash,
            cause,
            dismissal
        );
        C.Record memory contest = IStreamArtistIdentityContestOwner(address(this))
            .identityContestRecord(cause.facts.referenceHash);
        uint64 revision = Stages.compromiseRevision(
            address(this), e.registry, e.chainId, artistId, cause.facts.referenceHash
        );
        _contest(resolutions, cause, contest);
        Stages.EstateFacts memory estate = Stages.cancelledEstate(
            address(this),
            e.registry,
            e.chainId,
            artistId,
            cause.facts.pendingTransitionHash,
            revision
        );
        R.TransitionState memory pending = estate.transition;
        D.Closure memory closure = resolutions.closures[pending.recordHash];
        if (
            pending.recordHash == previous.recordHash || estate.request.incumbent != incumbent
                || pending.stagedAt < previous.executedAt
                || pending.contestedAt != cause.facts.enteredAt
                || estate.cancellationReplay.touchedRevision != revision
                || contest.capturedGuardianSetRecordHash != estate.request.guardianRecordHash
                || closure.artistId != artistId
                || closure.transitionRecordHash != pending.recordHash
                || closure.dismissalRecordHash != dismissal.recordHash || !closure.abandoned
                || closure.windowEndsAt != pending.contestEndsAt
                || closure.contestedAt != pending.contestedAt
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_SELECTED_ESTATE_COMPROMISE_V1"),
                e.chainId,
                e.registry,
                address(this),
                cause,
                dismissal,
                contest,
                estate.proof,
                closure
            )
        );
    }

    function _episode(
        Hashes.Environment memory e,
        bytes32 artistId,
        R.TransitionState memory previous,
        address incumbent,
        uint64 boundaryAt,
        bytes32 causeHash,
        bytes32 resolutionHash,
        D.Cause memory cause,
        D.Record memory r
    ) private view {
        if (previous.recordHash == 0) {
            R.TransitionState memory empty;
            if (keccak256(abi.encode(previous)) != keccak256(abi.encode(empty))) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            }
        } else if (
            previous.artistId != artistId || previous.phase != 2 || previous.executedAt == 0
                || keccak256(abi.encode(previous))
                    != keccak256(
                        abi.encode(
                            IStreamArtistRotationReads(address(this))
                                .artistTransitionState(previous.recordHash)
                        )
                    )
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        }
        if (
            artistId == 0 || incumbent == address(0) || causeHash == 0 || resolutionHash == 0
                || r.recordHash != resolutionHash || r.terms.artistId != artistId
                || r.terms.expectedCauseHash != causeHash || r.terms.evidenceHash == 0
                || r.terms.reasonHash == 0 || r.executor == address(0) || r.proposer == address(0)
                || (r.actionClass != 1 && r.actionClass != 2) || r.actionId == 0
                || r.incumbent != incumbent || r.authorityClass != 1 || r.restoredStatus != 1
                || r.dismissedAt == 0 || r.dismissedAt > boundaryAt || r.cohortHash == 0
                || r.governanceWitnessHash == 0 || r.recordHash != _dismissalHash(e, r)
                || (r.terms.removePriorStanding
                        ? r.terms.expectedRetirementHash == 0
                        || r.terms.expectedRetirementHash != cause.facts.actorRetirementHash
                        : r.terms.expectedRetirementHash != 0) || cause.causeHash != causeHash
                || causeHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_IDENTITY_CONTEST_CAUSE_V1"),
                            e.chainId,
                            e.registry,
                            address(this),
                            cause.facts
                        )
                    ) || cause.facts.artistId != artistId || cause.facts.kind != 1
                || cause.facts.authorityClass != 1 || cause.facts.priorStatus != 1
                || cause.facts.incumbent != incumbent || cause.facts.actor == address(0)
                || cause.facts.referenceHash == 0 || cause.facts.pendingTransitionHash == 0
                || cause.facts.executedTransitionHash != previous.recordHash
                || cause.facts.enteredAt == 0 || cause.facts.enteredAt < previous.executedAt
                || cause.facts.enteredAt > r.dismissedAt
                || cause.facts.previousResolutionHash != r.terms.expectedResolutionHash
                || cause.facts.evidenceHash == 0 || cause.facts.reasonHash == 0
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
    }

    function _contest(Resolution.State storage resolutions, D.Cause memory cause, C.Record memory c)
        private
        view
    {
        if (
            c.recordHash != cause.facts.referenceHash || c.terms.artistId != cause.facts.artistId
                || c.terms.evidenceHash != cause.facts.evidenceHash
                || c.terms.reasonHash != cause.facts.reasonHash || c.contester != cause.facts.actor
                || c.contestedAt != cause.facts.enteredAt || c.priorStatus != 1
                || c.pendingTransitionRecordHash != cause.facts.pendingTransitionHash
                || c.executedTransitionRecordHash != cause.facts.executedTransitionHash
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(cause.facts.artistId);
        // compromiseRevision has already checked this original subject-bound op33 hash.
        if (c.terms.subjectRecordHash == 0) return;
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
        D.Closure memory closure = resolutions.closures[subject.recordHash];
        D.Closure memory empty;
        if (keccak256(abi.encode(closure)) == keccak256(abi.encode(empty))) {
            if (subject.contestedAt == 0) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(cause.facts.artistId);
            }
            return;
        }
        D.Record memory dismissal = resolutions.records[closure.dismissalRecordHash];
        uint64 ends = subject.phase == 2 ? subject.postWindowEndsAt : subject.contestEndsAt;
        bool abandoned = subject.phase == 3
            || (subject.phase == 2
                && subject.contestedAt != 0
                && subject.contestedAt < subject.postWindowEndsAt);
        if (
            closure.dismissalRecordHash == 0 || closure.artistId != subject.artistId
                || closure.transitionRecordHash != subject.recordHash
                || closure.windowEndsAt != ends || closure.contestedAt != subject.contestedAt
                || closure.abandoned != abandoned
                || dismissal.recordHash != closure.dismissalRecordHash
                || dismissal.terms.artistId != subject.artistId
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(cause.facts.artistId);
    }

    function _dismissalHash(Hashes.Environment memory e, D.Record memory r)
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
}
