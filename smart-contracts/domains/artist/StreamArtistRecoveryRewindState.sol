// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";

/// @notice Separate appended Identity roots for explicitly selected V3 recovery.
/// @dev Original nested owner structs, keyed records and replay cells retain their layout.
library StreamArtistRecoveryRewindState {
    struct State {
        mapping(bytes32 => W.EvidenceStateV3) actions;
        mapping(bytes32 => bytes32) manifestActions;
        // Guardian supersession continues to use its original authoritative status map.
        mapping(bytes32 => W.StatusV3) statuses;
        mapping(bytes32 => bytes32) statusCommitments;
        mapping(bytes32 => W.RevisionContinuationV3) revisionContinuations;
        mapping(bytes32 => bytes32) revisionHead;
        mapping(bytes32 => bytes32) revisionRecordContinuations;
        mapping(bytes32 => W.StandingContinuationV3) standingContinuations;
        // Keyed by exact (artistId, priorAddress, retirementHash), never address alone.
        mapping(bytes32 => bytes32) standingHeads;
        mapping(bytes32 => bytes32) standingRecordContinuations;
        mapping(bytes32 => W.CapabilityContinuationV3) capabilityContinuations;
        mapping(bytes32 => bytes32) capabilityHead;
    }

    function standingScope(bytes32 artistId, address priorAddress, bytes32 retirement)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(artistId, priorAddress, retirement));
    }
}
