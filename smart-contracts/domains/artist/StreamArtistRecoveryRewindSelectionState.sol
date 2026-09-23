// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistRecoveryRewindRecordReads as Records
} from "./StreamArtistRecoveryRewindRecordReads.sol";

/// @notice Preparation-only storage of one immutable worker; never Artist semantic state.
library StreamArtistRecoveryRewindSelectionState {
    struct StandingScope {
        address account;
        bytes32 retirement;
    }

    struct State {
        mapping(bytes32 => bytes32) manifestKeys;
        mapping(bytes32 => W.EnvironmentV3) environments;
        mapping(bytes32 => W.BasisV3) bases;
        mapping(bytes32 => W.ProgressV3) progress;
        mapping(bytes32 => W.ResultV3) results;
        mapping(bytes32 => W.PreparationSealV3) seals;
        mapping(bytes32 => W.RecordReference[]) excluded;
        mapping(bytes32 => mapping(bytes32 => uint8)) excludedIndex;
        mapping(bytes32 => mapping(bytes32 => Records.Facts)) records;
        mapping(bytes32 => mapping(bytes32 => W.RecordKind)) kinds;
        mapping(bytes32 => mapping(bytes32 => bool)) admitted;
        mapping(bytes32 => mapping(bytes32 => bool)) retained;
        mapping(bytes32 => mapping(bytes32 => bool)) previouslySuperseded;
        mapping(bytes32 => mapping(address => bool)) retainedMembers;
        mapping(bytes32 => mapping(bytes32 => bytes32)) chainFallback;
        mapping(bytes32 => mapping(bytes32 => bytes32)) branchCommitments;
        mapping(bytes32 => mapping(W.RecordKind => bytes32)) familyCommitments;
        mapping(bytes32 => bytes32) originalRevisionContinuation;
        mapping(bytes32 => bytes32) guardianTip;
        mapping(bytes32 => uint64) guardianRevision;
        mapping(bytes32 => StandingScope[]) standingScopes;
        mapping(bytes32 => mapping(bytes32 => bool)) standingScopeSeen;
        mapping(bytes32 => mapping(bytes32 => bytes32)) standingWinners;
        mapping(bytes32 => mapping(bytes32 => uint64)) standingRevisions;
    }
}
