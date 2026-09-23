// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveryEvidenceTypes as E
} from "../../interfaces/stream/artist/StreamArtistRecoveryEvidenceTypes.sol";

/// @notice Supplemental V2 evidence coordinates, appended after every original Identity root.
/// @dev Original operation35 records, receipts, action associations and supersession status remain
/// in their existing owner state. These mappings bind the new evidence to those immutable facts.
library StreamArtistRecoveryAdjudicationState {
    struct State {
        mapping(bytes32 => E.EvidenceStateV2) actions;
        mapping(bytes32 => bytes32) manifestActions;
    }
}
