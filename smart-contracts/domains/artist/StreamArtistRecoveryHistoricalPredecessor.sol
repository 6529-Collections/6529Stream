// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRotationState as RotationState } from "./StreamArtistRotationState.sol";
import {
    StreamArtistIdentityResolutionState as Resolution
} from "./StreamArtistIdentityResolutionState.sol";
import { StreamArtistRotationHashes } from "./StreamArtistRotationHashes.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";

/// @notice Original ordinary-rotation history, including a permanently resolved contested window.
/// @dev Reads only the caller's admitted owner state. Current identity, empty supersession and no prior
/// recovery are enforced by the caller; a dismissal is not appeal authority or guardian disqualification.
library StreamArtistRecoveryHistoricalPredecessor {
    function rotation(
        RotationState.State storage rotations,
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory environment,
        D.CauseFacts memory cause,
        address incumbent
    ) public view returns (bytes32) {
        bytes32 artistId = cause.artistId;
        bytes32 head = rotations.latestExecution[artistId];
        R.RotationRecord memory r = rotations.rotations[head];
        R.TransitionState memory t = r.transition;
        bytes32 retirement = rotations.retirement[artistId][r.terms.oldAddress];
        _record(environment, r, head, artistId);
        if (
            incumbent == address(0) || r.terms.newAddress != incumbent
                || rotations.latestTransition[artistId] != head || rotations.pending[artistId] != 0
                || retirement != head || cause.executedTransitionHash != head
                || cause.pendingTransitionHash != 0 || t.phase != 2 || t.executedAt == 0
                || t.executedAt < t.stagedAt
                || (t.executedAt < t.contestEndsAt
                    && (r.approvalThreshold == 0 || r.guardianApprovals < r.approvalThreshold))
                || uint256(t.postWindowEndsAt) != uint256(t.executedAt) + r.effectiveWindow
                || cause.enteredAt < t.executedAt || block.timestamp < cause.enteredAt
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);

        bytes32 previous;
        bytes32 priorHash = r.terms.expectedPreviousTransitionRecordHash;
        if (priorHash != 0) {
            R.RotationRecord memory prior = rotations.rotations[priorHash];
            _record(environment, prior, priorHash, artistId);
            if (
                priorHash == head || prior.transition.stagedAt > t.stagedAt
                    || !((prior.transition.phase == 2
                            && prior.transition.executedAt != 0
                            && prior.terms.newAddress == r.terms.oldAddress
                            && prior.transition.executedAt <= t.stagedAt)
                        || (prior.transition.phase == 3
                            && prior.transition.executedAt == 0
                            && prior.transition.postWindowEndsAt == 0
                            && prior.terms.oldAddress == r.terms.oldAddress))
            ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            previous = keccak256(abi.encode(prior));
        }

        bytes32 resolution;
        if (t.contestedAt != 0 && t.contestedAt < t.postWindowEndsAt) {
            resolution = _resolved(resolutions, environment, cause, r);
        } else if (cause.enteredAt < t.postWindowEndsAt || block.timestamp < t.postWindowEndsAt) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_HISTORICAL_ROTATION_FACTS_V1"),
                r,
                retirement,
                previous,
                resolution
            )
        );
    }

    function _record(
        StreamArtistHashes.Environment memory environment,
        R.RotationRecord memory r,
        bytes32 hash,
        bytes32 artistId
    ) private pure {
        if (
            hash == 0 || r.recordHash != hash || r.terms.artistId != artistId
                || r.terms.oldAddress == address(0) || r.terms.newAddress == address(0)
                || r.terms.oldAddress == r.terms.newAddress || r.terms.reasonHash == 0
                || r.transition.artistId != artistId || r.transition.recordHash != hash
                || r.transition.stagedAt == 0 || r.transition.contestEndsAt < r.transition.stagedAt
                || r.effectiveWindow < 72 hours || r.standingTail < 30 days
                || StreamArtistRotationHashes.rotationRecord(
                        environment,
                        r.terms,
                        r.oldNonce,
                        r.transition.stagedAt,
                        r.transition.contestEndsAt
                    ) != hash
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
    }

    function _resolved(
        Resolution.State storage s,
        StreamArtistHashes.Environment memory environment,
        D.CauseFacts memory current,
        R.RotationRecord memory r
    ) private view returns (bytes32) {
        D.Closure memory closed = s.closures[r.recordHash];
        D.Record memory record = s.records[closed.dismissalRecordHash];
        D.Cause memory original = s.causes[record.terms.expectedCauseHash];
        if (
            closed.artistId != current.artistId || closed.transitionRecordHash != r.recordHash
                || closed.dismissalRecordHash == 0 || !closed.abandoned
                || closed.windowEndsAt != r.transition.postWindowEndsAt
                || closed.contestedAt != r.transition.contestedAt
                || closed.contestedAt < r.transition.executedAt
                || record.recordHash != closed.dismissalRecordHash
                || record.terms.artistId != current.artistId || record.terms.evidenceHash == 0
                || record.terms.reasonHash == 0 || record.executor == address(0)
                || record.proposer == address(0)
                || (record.actionClass != 1 && record.actionClass != 2) || record.actionId == 0
                || record.incumbent != current.incumbent || record.authorityClass != 1
                || record.restoredStatus != 1 || record.dismissedAt == 0
                || record.dismissedAt > current.enteredAt || record.cohortHash == 0
                || record.governanceWitnessHash == 0
                || record.recordHash != _dismissalHash(environment, record)
                || original.causeHash == 0 || original.causeHash != record.terms.expectedCauseHash
                || original.causeHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_IDENTITY_CONTEST_CAUSE_V1"),
                            environment.chainId,
                            environment.registry,
                            address(this),
                            original.facts
                        )
                    ) || original.facts.artistId != current.artistId
                || original.facts.executedTransitionHash != r.recordHash
                || original.facts.incumbent != current.incumbent
                || original.facts.authorityClass != 1 || original.facts.priorStatus != 1
                || (original.facts.kind != 1 && original.facts.kind != 2)
                || original.facts.referenceHash == 0 || original.facts.actor == address(0)
                || original.facts.enteredAt < r.transition.executedAt
                || original.facts.enteredAt < closed.contestedAt
                || original.facts.enteredAt > record.dismissedAt
                || original.facts.enteredAt >= r.transition.postWindowEndsAt
                || original.facts.previousResolutionHash != record.terms.expectedResolutionHash
                || current.previousResolutionHash == 0
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(current.artistId);
        return keccak256(abi.encode(closed, record, original));
    }

    function _dismissalHash(StreamArtistHashes.Environment memory e, D.Record memory r)
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
