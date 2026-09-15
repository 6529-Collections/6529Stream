// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistIdentityResolutionState as Resolution
} from "./StreamArtistIdentityResolutionState.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import {
    IStreamArtistIdentityContestOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityContest.sol";
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

/// @notice Admitted op41 closure of the still-current op35, followed by a fresh compromise.
/// @dev No historical authorization is replayed. The caller separately authenticates the original
/// recovery, current vesting/identity/cause, unchanged epoch, capabilities and complete guardian history.
library StreamArtistRecoveryClosedContinuation {
    function proof(
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        I.Record memory prior,
        R.TransitionState memory t,
        D.Cause memory current
    ) public view returns (bytes32) {
        bytes32 artistId = prior.fields.artistId;
        D.Closure memory closed = resolutions.closures[prior.recordHash];
        D.Closure memory empty;
        if (keccak256(abi.encode(closed)) == keccak256(abi.encode(empty))) {
            // Preserve every original immediate-continuation condition and its hash bytes.
            if (
                t.contestedAt != current.facts.enteredAt
                    || current.facts.enteredAt < t.postWindowEndsAt
                    || current.facts.previousCauseHash != prior.terms.expectedCauseHash
                    || current.facts.previousResolutionHash != prior.terms.expectedResolutionHash
            ) revert I.UnsupportedIdentityRecoveryProfile(artistId);
            return 0;
        }
        bool abandoned = t.contestedAt != 0 && t.contestedAt < t.postWindowEndsAt;
        if (
            closed.artistId != artistId || closed.transitionRecordHash != prior.recordHash
                || closed.dismissalRecordHash == 0 || closed.windowEndsAt != t.postWindowEndsAt
                || closed.contestedAt != t.contestedAt || closed.contestedAt < t.executedAt
                || closed.contestedAt == 0 || closed.abandoned != abandoned
                || current.facts.previousResolutionHash == 0
        ) revert I.UnsupportedIdentityRecoveryProfile(artistId);

        D.Record memory original = resolutions.records[closed.dismissalRecordHash];
        bytes32 originalProof =
            _dismissed(resolutions, e, prior, current, original, closed.dismissalRecordHash);
        D.Cause memory firstCause = resolutions.causes[original.terms.expectedCauseHash];
        if (
            firstCause.facts.enteredAt != closed.contestedAt
                || firstCause.facts.previousCauseHash != prior.terms.expectedCauseHash
                || firstCause.facts.previousResolutionHash != prior.terms.expectedResolutionHash
                || (!abandoned && original.dismissedAt < t.postWindowEndsAt)
        ) revert I.UnsupportedIdentityRecoveryProfile(artistId);

        // The first closure never moves. Later admitted dismissals remain independent records.
        D.Record memory latest = resolutions.records[current.facts.previousResolutionHash];
        bytes32 latestProof = _dismissed(
            resolutions, e, prior, current, latest, current.facts.previousResolutionHash
        );
        if (
            latest.dismissedAt < original.dismissedAt
                || current.facts.previousCauseHash != latest.terms.expectedCauseHash
        ) revert I.UnsupportedIdentityRecoveryProfile(artistId);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ADMITTED_RECOVERY_CLOSURE_V1"),
                closed,
                originalProof,
                latestProof
            )
        );
    }

    function _dismissed(
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        I.Record memory prior,
        D.Cause memory current,
        D.Record memory r,
        bytes32 expected
    ) private view returns (bytes32) {
        bytes32 artistId = prior.fields.artistId;
        D.Cause memory cause = resolutions.causes[r.terms.expectedCauseHash];
        if (
            expected == 0 || r.recordHash != expected || r.terms.artistId != artistId
                || r.terms.evidenceHash == 0 || r.terms.reasonHash == 0 || r.executor == address(0)
                || r.proposer == address(0) || (r.actionClass != 1 && r.actionClass != 2)
                || r.actionId == 0 || r.incumbent != prior.fields.newAddress
                || r.authorityClass != prior.fields.vestedAuthorityClass
                || r.restoredStatus != r.authorityClass || r.dismissedAt == 0
                || r.dismissedAt > current.facts.enteredAt || r.cohortHash == 0
                || r.governanceWitnessHash == 0 || r.recordHash != _record(e, r)
                || cause.causeHash == 0 || cause.causeHash != r.terms.expectedCauseHash
                || cause.causeHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_IDENTITY_CONTEST_CAUSE_V1"),
                            e.chainId,
                            e.registry,
                            address(this),
                            cause.facts
                        )
                    ) || cause.facts.artistId != artistId || cause.facts.kind != 1
                || cause.facts.executedTransitionHash != prior.recordHash
                || cause.facts.pendingTransitionHash != 0
                || cause.facts.incumbent != prior.fields.newAddress
                || cause.facts.authorityClass != r.authorityClass
                || cause.facts.priorStatus != r.restoredStatus || cause.facts.actor == address(0)
                || cause.facts.referenceHash == 0 || cause.facts.evidenceHash == 0
                || cause.facts.reasonHash == 0 || cause.facts.enteredAt < prior.fields.recoveredAt
                || cause.facts.enteredAt > r.dismissedAt
                || cause.facts.previousResolutionHash != r.terms.expectedResolutionHash
                || (r.terms.removePriorStanding
                        ? r.terms.expectedRetirementHash == 0
                        || r.terms.expectedRetirementHash != cause.facts.actorRetirementHash
                        : r.terms.expectedRetirementHash != 0)
        ) revert I.UnsupportedIdentityRecoveryProfile(artistId);
        C.Record memory c = IStreamArtistIdentityContestOwner(address(this))
            .identityContestRecord(cause.facts.referenceHash);
        if (
            c.recordHash != cause.facts.referenceHash || c.terms.artistId != artistId
                || c.terms.subjectRecordHash != prior.recordHash
                || c.terms.evidenceHash != cause.facts.evidenceHash
                || c.terms.reasonHash != cause.facts.reasonHash || c.contester != cause.facts.actor
                || c.priorStatus != cause.facts.priorStatus
                || c.contestedAt != cause.facts.enteredAt || c.pendingTransitionRecordHash != 0
                || c.executedTransitionRecordHash != prior.recordHash
                || c.recordHash
                    != keccak256(
                        abi.encode(
                            bytes32(
                                0x26a4221cd1625ab88b1ac279e1708a73efa176e486242b26832cdc94fe25e6bb
                            ),
                            e.chainId,
                            e.registry,
                            artistId,
                            c.contester,
                            prior.recordHash,
                            c.terms.evidenceHash,
                            c.terms.reasonHash,
                            c.contestedAt
                        )
                    )
        ) revert I.UnsupportedIdentityRecoveryProfile(artistId);
        return keccak256(abi.encode(r, cause, c));
    }

    function _record(StreamArtistHashes.Environment memory e, D.Record memory r)
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
