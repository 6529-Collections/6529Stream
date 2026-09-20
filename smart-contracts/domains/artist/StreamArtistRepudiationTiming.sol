// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveredTimingInventory } from "./StreamArtistRecoveredTimingInventory.sol";
import {
    StreamArtistRecoveredTimingTypes
} from "../../interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";
import "./StreamArtistTimingState.sol";

/// @notice Original AA-owned repudiation seconds in Identity's dedicated storage namespace.
library StreamArtistRepudiationTiming {
    bytes32 internal constant PARAMETER = keccak256("ARTIST_REPUDIATION_CONTEST_SECONDS");
    bytes32 private constant SLOT = keccak256("6529STREAM_ARTIST_REPUDIATION_TIMING_V1");

    struct State {
        uint64 seconds_;
        uint64 revision;
        mapping(bytes32 => bool) actions;
    }
    event ArtistWindowChanged(
        uint16 schemaVersion,
        bytes32 indexed parameter,
        uint64 oldValue,
        uint64 newValue,
        uint64 floor,
        uint64 revision,
        bytes32 indexed actionId
    );

    function _state() private pure returns (State storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function info() public view returns (uint64, uint64, uint64) {
        State storage s = _state();
        return (s.seconds_ == 0 ? 7 days : s.seconds_, 3 days, s.revision == 0 ? 1 : s.revision);
    }

    function configure(address executor, address actor, uint64 value, uint64 expectedRevision)
        public
    {
        if (actor != executor || executor == address(0)) revert T.Unauthorized(actor);
        (uint64 prior, uint64 floor, uint64 revision) = info();
        if (
            revision != expectedRevision || revision == type(uint64).max || value == prior
                || value < floor || block.timestamp > type(uint64).max
                || uint256(value) + block.timestamp > type(uint64).max
        ) revert R.InvalidArtistWindow(PARAMETER);
        (
            bool executing,
            bytes32 actionId,
            uint8 class_,
            bytes32 scope_,
            bytes32 oldHash,
            bytes32 newHash
        ) = IStreamGovernedParameterAuthority(executor).currentAction();
        if (
            !executing || actionId == 0 || (value < prior ? class_ != 1 : class_ > 1)
                || scope_ != StreamArtistTimingState.scope(PARAMETER)
                || oldHash != StreamArtistTimingState.stateHash(PARAMETER, prior, floor, revision)
                || newHash
                    != StreamArtistTimingState.stateHash(PARAMETER, value, floor, revision + 1)
        ) revert R.InvalidArtistWindowContext();
        State storage s = _state();
        bytes32 key = keccak256(abi.encode(actionId, PARAMETER, oldHash, newHash));
        if (s.actions[key]) revert R.InvalidArtistWindowContext();
        s.actions[key] = true;
        s.seconds_ = value;
        s.revision = revision + 1;
        StreamArtistRecoveredTimingInventory.note(
            StreamArtistRecoveredTimingTypes.Input(
                PARAMETER,
                actionId,
                key,
                oldHash,
                newHash,
                prior,
                value,
                floor,
                revision,
                revision + 1
            )
        );
        emit ArtistWindowChanged(1, PARAMETER, prior, value, floor, revision + 1, actionId);
    }
}
