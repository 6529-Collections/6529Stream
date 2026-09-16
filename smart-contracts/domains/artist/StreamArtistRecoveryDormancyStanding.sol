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

/// @notice First designated-dormancy recovery after admitted standing-contest dismissals.
/// @dev The caller independently authenticates the unchanged original op43 execution, vesting,
/// plan, capabilities, epoch and full guardian history. No executed rotation or prior recovery
/// is admitted here. Historical producer authority is retained rather than authorized again.
library StreamArtistRecoveryDormancyStanding {
    function proof(
        RotationState.State storage rotations,
        Resolution.State storage resolutions,
        ContestState.State storage contests,
        StreamArtistHashes.Environment memory e,
        R.TransitionState memory terminal,
        D.Cause memory current
    ) public view returns (bytes32) {
        bytes32 artistId = terminal.artistId;
        bytes32 latestTransition = rotations.latestTransition[artistId];
        D.Closure memory original = resolutions.closures[terminal.recordHash];
        D.Record memory first = resolutions.records[original.dismissalRecordHash];
        D.Cause memory firstCause = resolutions.causes[first.terms.expectedCauseHash];
        if (
            latestTransition == 0 || latestTransition == terminal.recordHash
                || original.dismissalRecordHash == 0 || firstCause.facts.previousCauseHash != 0
                || firstCause.facts.previousResolutionHash != 0
        ) revert I.UnsupportedIdentityRecoveryProfile(artistId);

        // Retain the existing dormancy profile's exact retirement/removal relation for every
        // separately selected dismissal. The common reader reconstructs their canonical hashes.
        _retirement(resolutions, first, artistId);
        _retirement(
            resolutions, resolutions.records[current.facts.previousResolutionHash], artistId
        );
        _retirement(
            resolutions,
            resolutions.records[resolutions.closures[latestTransition].dismissalRecordHash],
            artistId
        );

        // This admitted class-3 transition reader already distinguishes kind1 op33 records from
        // kind2 op31 pending rotations, including zero evidence/reason for standing vetoes.
        // It independently binds the first executed-window closure, the latest veto's abandoned
        // pending closure, and the current latest dismissal. Neither closure may stand in for
        // the other; all chronology, actual record hashes and current previous pointers remain.
        bytes32 closed = Closed.proof(rotations, resolutions, contests, e, current, terminal);
        if (closed == 0) revert I.UnsupportedIdentityRecoveryProfile(artistId);
        return keccak256(
            abi.encode(keccak256("6529STREAM_ARTIST_ADMITTED_DORMANCY_STANDING_V1"), closed)
        );
    }

    function _retirement(Resolution.State storage resolutions, D.Record memory r, bytes32 artistId)
        private
        view
    {
        D.Cause memory cause = resolutions.causes[r.terms.expectedCauseHash];
        bool invalid = r.terms.removePriorStanding
            ? r.terms.expectedRetirementHash == 0
                || r.terms.expectedRetirementHash != cause.facts.actorRetirementHash
            : r.terms.expectedRetirementHash != 0;
        if (invalid) revert I.UnsupportedIdentityRecoveryProfile(artistId);
    }
}
