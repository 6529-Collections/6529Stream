// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistIdentityDismissalTypes as Dismissal
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";

/// @dev Appended Identity storage only. Earlier inline state roots cannot expand.
library StreamArtistIdentityResolutionState {
    struct State {
        mapping(bytes32 => Dismissal.Cause) causes;
        mapping(bytes32 => bytes32) currentCause;
        mapping(bytes32 => Dismissal.Record) records;
        mapping(bytes32 => bytes32) latestResolution;
        mapping(bytes32 => Dismissal.Closure) closures;
        mapping(bytes32 => Dismissal.RevisionContinuation) continuations;
        mapping(bytes32 => bytes32) continuationHead;
        mapping(bytes32 => mapping(address => Dismissal.StandingJudgment)) standingJudgments;
    }
}
