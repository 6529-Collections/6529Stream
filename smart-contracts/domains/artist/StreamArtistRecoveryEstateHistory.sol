// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistIdentityRecoveryState as RecoveryState
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistRotationState as RotationState } from "./StreamArtistRotationState.sol";
import {
    StreamArtistIdentityResolutionState as Resolution
} from "./StreamArtistIdentityResolutionState.sol";
import { StreamArtistRotationHashes } from "./StreamArtistRotationHashes.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistEstateTypes as Estate
} from "../../interfaces/stream/artist/StreamArtistEstateTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";

/// @notice Fixed-library authentication of admitted living vesting and post-estate standing history.
/// @dev Immutable owner records retain their producer's authorization. No historical action is replayed.
library StreamArtistRecoveryEstateHistory {
    function previous(
        RecoveryState.State storage recovery,
        RotationState.State storage rotations,
        StreamArtistHashes.Environment memory e,
        Estate.RequestRecord memory request,
        V.Snapshot memory estate
    ) public view returns (bytes32) {
        bytes32 head = estate.previousTransitionRecordHash;
        if (head == 0) {
            if (estate.previousCommitment != 0) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(estate.artistId);
            }
            return 0;
        }
        V.Snapshot memory prior = recovery.vestingHistory.snapshots[head];
        R.RotationRecord memory r = rotations.rotations[head];
        _rotation(e, r, estate.artistId, head);
        if (
            head == estate.transitionRecordHash || prior.artistId != estate.artistId
                || prior.transitionRecordHash != head || prior.operationId != 32
                || prior.authorityClass != 1 || prior.oldAddress != r.terms.oldAddress
                || prior.newAddress != r.terms.newAddress || prior.newAddress != request.incumbent
                || prior.executedAt != r.transition.executedAt || prior.executedAt == 0
                || prior.executedAt > request.requestedAt || prior.ownerRevision == 0
                || prior.ownerRevision >= estate.ownerRevision
                || prior.ownerRevision <= prior.guardians.ownerRevision
                || prior.guardians.count > estate.guardians.count || prior.commitment == 0
                || prior.commitment != estate.previousCommitment
                || prior.commitment != _vesting(e, prior)
                || (prior.previousTransitionRecordHash == 0) != (prior.previousCommitment == 0)
                || r.transition.phase != 2 || r.transition.executedAt < r.transition.stagedAt
                || (r.transition.executedAt < r.transition.contestEndsAt
                    && (r.approvalThreshold == 0 || r.guardianApprovals < r.approvalThreshold))
                || uint256(r.transition.postWindowEndsAt)
                    != uint256(r.transition.executedAt) + r.effectiveWindow
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(estate.artistId);
        }
        // The original vesting producer linked its then-current immutable parent. Bind that same
        // immediate parent again; the admitted chain commitment does not need an unbounded walk.
        V.Snapshot memory earlier;
        if (prior.previousTransitionRecordHash != 0) {
            earlier = recovery.vestingHistory.snapshots[prior.previousTransitionRecordHash];
            if (
                earlier.artistId != estate.artistId
                    || earlier.transitionRecordHash != prior.previousTransitionRecordHash
                    || earlier.operationId != 32 || earlier.authorityClass != 1
                    || earlier.commitment == 0 || earlier.commitment != prior.previousCommitment
                    || earlier.commitment != _vesting(e, earlier)
                    || earlier.newAddress != prior.oldAddress
                    || earlier.ownerRevision >= prior.ownerRevision
                    || earlier.executedAt > r.transition.stagedAt
            ) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(estate.artistId);
            }
        }
        GH.Head memory h = prior.guardians;
        if (h.count == 0) {
            if (h.ownerRevision != 0 || h.commitment != 0) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(estate.artistId);
            }
        } else {
            bytes32 last = recovery.guardianHistory.records[estate.artistId][h.count];
            GH.Entry memory entry = recovery.guardianHistory.entries[last];
            if (
                last == 0 || entry.artistId != estate.artistId || entry.recordHash != last
                    || entry.index != h.count || entry.ownerRevision != h.ownerRevision
                    || entry.commitment != h.commitment || h.commitment == 0
            ) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(estate.artistId);
            }
        }
        return keccak256(abi.encode(prior, r, earlier));
    }

    function standing(
        RotationState.State storage rotations,
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        D.Cause memory cause,
        D.Record memory dismissal,
        R.TransitionState memory estate
    ) public view returns (bytes32) {
        bytes32 hash = cause.facts.referenceHash;
        R.RotationRecord memory r = rotations.rotations[hash];
        _rotation(e, r, cause.facts.artistId, hash);
        D.Closure memory closed = resolutions.closures[hash];
        if (
            cause.facts.kind != 2 || cause.facts.authorityClass != 3 || cause.facts.priorStatus != 3
                || cause.facts.evidenceHash != 0 || cause.facts.pendingTransitionHash != hash
                || cause.facts.executedTransitionHash != estate.recordHash
                || r.terms.oldAddress != cause.facts.incumbent || r.transition.phase != 3
                || r.transition.executedAt != 0 || r.transition.postWindowEndsAt != 0
                || r.transition.contestedAt != cause.facts.enteredAt
                || r.transition.contestedAt < r.transition.stagedAt
                || r.transition.stagedAt < estate.executedAt
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

    function _vesting(StreamArtistHashes.Environment memory e, V.Snapshot memory v)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            bytes.concat(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_GUARDIAN_VESTING_V1"),
                    e.chainId,
                    e.registry,
                    address(this)
                ),
                abi.encode(
                    v.artistId,
                    v.transitionRecordHash,
                    v.operationId,
                    v.ownerRevision,
                    v.executedAt,
                    v.oldAddress,
                    v.newAddress,
                    v.authorityClass,
                    v.guardians,
                    v.previousTransitionRecordHash,
                    v.previousCommitment
                )
            )
        );
    }
}
