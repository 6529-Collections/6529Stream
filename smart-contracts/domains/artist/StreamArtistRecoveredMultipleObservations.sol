// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredExternalGuards as External
} from "./StreamArtistRecoveredExternalGuards.sol";

/// @notice Original complete external-observation merge shared by both explicit aggregate profiles.
library StreamArtistRecoveredMultipleObservations {
    function collect(External.Snapshot[] memory all)
        public
        pure
        returns (External.Snapshot memory result)
    {
        result.schema = all[0].schema;
        result.provenanceCommitment = all[0].provenanceCommitment;
        result.artistId = all[0].artistId;
        uint256 a;
        uint256 f;
        uint256 e;
        for (uint256 i; i < all.length; ++i) {
            if (
                all[i].schema != result.schema
                    || all[i].provenanceCommitment != result.provenanceCommitment
                    || all[i].artistId == 0
            ) revert RH.InvalidRecoveredHydrationProfile();
            a += all[i].actions.length;
            f += all[i].finality.length;
            e += all[i].entropy.length;
        }
        if (a > RH.MAX_REPLAY_ALIASES || f + e > RH.MAX_JOURNAL_ENTRIES) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        result.actions = new External.ActionGuard[](a);
        result.finality = new External.FinalityGuard[](f);
        result.entropy = new External.EntropyGuard[](e);
        a = 0;
        f = 0;
        e = 0;
        for (uint256 i; i < all.length; ++i) {
            for (uint256 j; j < all[i].actions.length; ++j) {
                result.actions[a++] = all[i].actions[j];
            }
            for (uint256 j; j < all[i].finality.length; ++j) {
                result.finality[f++] = all[i].finality[j];
            }
            for (uint256 j; j < all[i].entropy.length; ++j) {
                result.entropy[e++] = all[i].entropy[j];
            }
        }
    }
}
