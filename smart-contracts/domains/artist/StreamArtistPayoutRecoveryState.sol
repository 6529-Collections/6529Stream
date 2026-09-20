// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";

/// @notice Appended Payout-owned V3 evidence. Original payout records and associations are unchanged.
library StreamArtistPayoutRecoveryState {
    struct State {
        mapping(bytes32 => W.StatusV3) statuses;
        mapping(bytes32 => bytes32) statusCommitments;
        mapping(bytes32 => W.PayoutContinuationV3) continuations;
        mapping(bytes32 => bytes32) continuationHeads;
        mapping(bytes32 => bytes32) recordContinuations;
        mapping(bytes32 => bytes32) appliedRecoveries;
    }
}
