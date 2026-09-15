// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRotationState as RotationState } from "./StreamArtistRotationState.sol";
import {
    StreamArtistIdentityResolutionState as Resolution
} from "./StreamArtistIdentityResolutionState.sol";
import {
    StreamArtistIdentityContestState as ContestState
} from "./StreamArtistIdentityContestState.sol";
import { StreamArtistRecoveryEstateClosed as Closed } from "./StreamArtistRecoveryEstateClosed.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as I
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";

/// @notice Original appointed-principal closure before admitted successor rotation history.
/// @dev The caller separately authenticates the op43 notice/plan/vesting and actual terminal chain.
/// The immutable original dismissal is never replaced with today's different incumbent's resolution.
library StreamArtistRecoveryDormancyRotationOrigin {
    function proof(
        RotationState.State storage rotations,
        Resolution.State storage resolutions,
        ContestState.State storage contests,
        StreamArtistHashes.Environment memory e,
        R.TransitionState memory origin,
        address appointed,
        uint64 terminalStagedAt
    ) public view returns (bytes32) {
        D.Closure memory closed = resolutions.closures[origin.recordHash];
        D.Closure memory empty;
        if (keccak256(abi.encode(closed)) == keccak256(abi.encode(empty))) {
            if (origin.contestedAt != 0) {
                revert I.UnsupportedIdentityRecoveryProfile(origin.artistId);
            }
            return 0;
        }
        D.Record memory first = resolutions.records[closed.dismissalRecordHash];
        D.Cause memory cause = resolutions.causes[first.terms.expectedCauseHash];
        // Preserve the first designated-dormancy closure's complete prior-episode boundary and
        // actual actor-retirement removal terms. Canonical class/kind/record/timing follows below.
        if (
            cause.facts.previousCauseHash != 0 || cause.facts.previousResolutionHash != 0
                || (first.terms.removePriorStanding
                        ? first.terms.expectedRetirementHash == 0
                        || first.terms.expectedRetirementHash != cause.facts.actorRetirementHash
                        : first.terms.expectedRetirementHash != 0)
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(origin.artistId);
        }
        bytes32 original = Closed.beforeNext(
            rotations, resolutions, contests, e, origin, appointed, terminalStagedAt
        );
        if (original == 0) revert I.UnsupportedIdentityRecoveryProfile(origin.artistId);
        return keccak256(
            abi.encode(keccak256("6529STREAM_ARTIST_DORMANCY_ROTATION_ORIGIN_CLOSURE_V1"), original)
        );
    }
}
