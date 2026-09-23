// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import { StreamArtistRotationTypes as R } from "./StreamArtistRotationTypes.sol";
import { StreamArtistRecoveryRewindTypes as W } from "./StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "./StreamArtistRecoveredHydrationTypes.sol";

/// @notice Exact Payout state carried by the recovered operation60 profile.
/// @dev Positions retain their ultimate original owner clocks. They are not destination revisions.
library StreamArtistRecoveredPayoutTypes {
    bytes32 internal constant SCHEMA = keccak256("6529STREAM_ARTIST_RECOVERED_PAYOUT_HYDRATION_V1");

    struct RecordRow {
        RH.Position position;
        W.PayoutOriginalV3 original;
        bytes32 evidenceHash;
        R.ProvisionalAssociation association;
        bytes32 abandonedUnder;
        W.StatusV3 status;
        bytes32 continuationHash;
    }

    /// @dev An actual Payout35 has a revision but does not append a native receipt.
    struct ContinuationRow {
        RH.Point point;
        W.PayoutContinuationV3 continuation;
        bytes32 appliedCommitment;
    }

    struct Bundle {
        bytes32 artistId;
        T.Snapshot sourceSnapshot;
        W.PayoutInventoryV3 inventory;
        // Exact flattened logical18 order, never a replacement destination-native journal.
        RecordRow[] records;
        // Oldest apply first, including applies whose released child is zero.
        ContinuationRow[] continuations;
    }

    error InvalidRecoveredPayout(bytes32 recordHash);
}
