// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRotationState as RotationState } from "./StreamArtistRotationState.sol";
import { StreamArtistRotationHashes } from "./StreamArtistRotationHashes.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import { StreamArtistGuardianHistory as History } from "./StreamArtistGuardianHistory.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";

/// @notice Actual owner-local predecessor proof for first-rotation living recovery.
/// @dev The caller separately authenticates current identity/cause, no prior recovery, and the governed request.
library StreamArtistRecoveryPredecessor {
    function firstRotation(
        RotationState.State storage s,
        StreamArtistHashes.Environment memory environment,
        D.CauseFacts memory cause,
        address incumbent
    ) public view returns (bytes32 commitment) {
        bytes32 artistId = cause.artistId;
        bytes32 head = s.latestExecution[artistId];
        R.RotationRecord memory r = s.rotations[head];
        R.TransitionState memory t = r.transition;
        bytes32 retirement = s.retirement[artistId][r.terms.oldAddress];
        if (
            head == bytes32(0) || r.recordHash != head || r.terms.artistId != artistId
                || r.terms.oldAddress == address(0) || r.terms.oldAddress == incumbent
                || r.terms.newAddress != incumbent || incumbent == address(0)
                || r.terms.expectedPreviousTransitionRecordHash != bytes32(0)
                || s.latestTransition[artistId] != head || s.pending[artistId] != bytes32(0)
                || retirement != head || cause.executedTransitionHash != head
                || cause.pendingTransitionHash != bytes32(0) || cause.enteredAt < t.postWindowEndsAt
                || t.artistId != artistId || t.recordHash != head || t.phase != 2 || t.stagedAt == 0
                || t.contestEndsAt < t.stagedAt || t.executedAt < t.stagedAt || t.executedAt == 0
                || r.effectiveWindow < 72 hours || r.standingTail < 30 days
                || uint256(t.postWindowEndsAt) != uint256(t.executedAt) + r.effectiveWindow
                || block.timestamp < t.postWindowEndsAt
                || (t.contestedAt != 0 && t.contestedAt < t.postWindowEndsAt)
                || StreamArtistRotationHashes.rotationRecord(
                        environment, r.terms, r.oldNonce, t.stagedAt, t.contestEndsAt
                    ) != head
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        commitment = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_FIRST_ROTATION_FACTS_V1"), r, retirement
            )
        );
    }

    function guardian(
        History.State storage history,
        RotationState.State storage rotations,
        StreamArtistHashes.Environment memory environment,
        bytes32 artistId,
        uint64 count
    ) public view returns (R.GuardianRecord memory g) {
        GH.Head memory complete = History.requireComplete(history, artistId, count);
        bytes32 head = RotationState.operativeGuardian(rotations, artistId);
        if (head == bytes32(0)) {
            if (
                count != 0 || rotations.stableGuardian[artistId] != bytes32(0)
                    || rotations.provisionalGuardian[artistId] != bytes32(0)
            ) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            }
            return g;
        }
        g = rotations.guardians[head];
        GH.Entry storage entry = history.entries[head];
        if (
            count == 0 || g.recordHash != head || g.terms.artistId != artistId
                || g.authorityClass != 1 || g.signer == address(0) || g.terms.guardians.length > 8
                || g.terms.minContestSeconds > 30 days
                || !RotationState.eligible(rotations, artistId, g.provisional)
                || entry.artistId != artistId || entry.recordHash != head || entry.index == 0
                || entry.index > complete.count || entry.ownerRevision == 0
                || entry.ownerRevision > complete.ownerRevision || entry.commitment == bytes32(0)
                || entry.recordDataHash != keccak256(abi.encode(g))
                || history.records[artistId][entry.index] != head
                || StreamArtistRotationHashes.guardianRecord(
                        environment, g.terms, T.Authorization(g.nonce, g.signedAt, bytes(""))
                    ) != head
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
    }
}
