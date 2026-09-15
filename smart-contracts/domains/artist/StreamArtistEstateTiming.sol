// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistEstateState.sol";
import "./StreamArtistTimingState.sol";

/// @notice Estate notice configuration shares the canonical timing context, with its own revision.
library StreamArtistEstateTiming {
    event ArtistWindowChanged(
        uint16 schemaVersion,
        bytes32 indexed parameter,
        uint64 oldValue,
        uint64 newValue,
        uint64 floor,
        uint64 revision,
        bytes32 indexed actionId
    );

    function configure(
        StreamArtistEstateState.State storage s,
        address executor,
        address actor,
        uint64 value,
        uint64 expectedRevision
    ) public {
        bytes32 parameter = keccak256("ARTIST_ESTATE_ACTIVATION_NOTICE_SECONDS");
        if (actor != executor || executor == address(0)) revert T.Unauthorized(actor);
        (uint64 prior, uint64 floor, uint64 revision) = StreamArtistEstateState.timing(s);
        if (
            revision != expectedRevision || revision == type(uint64).max || value == prior
                || value < floor || block.timestamp > type(uint64).max
                || uint256(value) + block.timestamp > type(uint64).max
        ) {
            revert R.InvalidArtistWindow(parameter);
        }
        (
            bool executing,
            bytes32 actionId,
            uint8 actionClass,
            bytes32 scope,
            bytes32 oldHash,
            bytes32 newHash
        ) = IStreamGovernedParameterAuthority(executor).currentAction();
        if (
            !executing || actionId == bytes32(0)
                || (value < prior ? actionClass != 1 : actionClass > 1)
                || scope != StreamArtistTimingState.scope(parameter)
                || oldHash != StreamArtistTimingState.stateHash(parameter, prior, floor, revision)
                || newHash
                    != StreamArtistTimingState.stateHash(parameter, value, floor, revision + 1)
        ) {
            revert R.InvalidArtistWindowContext();
        }
        bytes32 key = keccak256(abi.encode(actionId, parameter, oldHash, newHash));
        if (s.timingActions[key]) revert R.InvalidArtistWindowContext();
        s.timingActions[key] = true;
        s.noticeSeconds = value;
        s.noticeRevision = revision + 1;
        emit ArtistWindowChanged(1, parameter, prior, value, floor, revision + 1, actionId);
    }
}
