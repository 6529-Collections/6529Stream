// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistEntropyUnavailabilityTypes as EU
} from "../../interfaces/stream/artist/IStreamArtistEntropyUnavailability.sol";

/// @notice Fixed Identity-owned supplemental admission namespace; ordinary owner layout is unchanged.
library StreamArtistEntropyUnavailabilityStore {
    bytes32 private constant SLOT =
        keccak256("6529STREAM_ARTIST_ENTROPY_UNAVAILABILITY_STORAGE_V1");

    struct State {
        mapping(bytes32 => EU.Admission) admissions;
        mapping(bytes32 => address) origins;
    }

    function state() internal pure returns (State storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function activityEpoch(bytes32 hash, uint256 original) internal view returns (uint256) {
        EU.Admission storage a = state().admissions[hash];
        return a.target.coordinator == address(0) ? original : a.activityEpoch;
    }
}
