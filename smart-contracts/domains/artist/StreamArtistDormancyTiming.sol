// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistDormancyState.sol";
import "./StreamArtistTimingState.sol";

/// @notice Original AA seconds configuration discipline for the two dormant-authority windows.
library StreamArtistDormancyTiming {
    event ArtistWindowChanged(
        uint16 schemaVersion,
        bytes32 indexed parameter,
        uint64 oldValue,
        uint64 newValue,
        uint64 floor,
        uint64 revision,
        bytes32 indexed actionId
    );

    function supported(bytes32 parameter) internal pure returns (bool) {
        return parameter == keccak256("ARTIST_DORMANCY_MIN_INACTIVITY_SECONDS")
            || parameter == keccak256("ARTIST_DORMANCY_NOTICE_SECONDS");
    }

    function info(StreamArtistDormancyState.State storage s, bytes32 parameter)
        public
        view
        returns (uint64, uint64, uint64)
    {
        if (!supported(parameter)) revert R.InvalidArtistWindow(parameter);
        return StreamArtistDormancyState.timing(
            s, parameter == keccak256("ARTIST_DORMANCY_MIN_INACTIVITY_SECONDS")
        );
    }

    function configure(
        StreamArtistDormancyState.State storage s,
        address executor,
        address actor,
        bytes32 parameter,
        uint64 value,
        uint64 expectedRevision
    ) public {
        if (actor != executor || executor == address(0)) {
            revert T.Unauthorized(actor);
        }
        (uint64 prior, uint64 floor, uint64 revision) = info(s, parameter);
        if (
            revision != expectedRevision || revision == type(uint64).max || value == prior
                || value < floor || block.timestamp > type(uint64).max
                || uint256(value) + block.timestamp > type(uint64).max
        ) revert R.InvalidArtistWindow(parameter);
        (
            bool executing,
            bytes32 actionId,
            uint8 actionClass,
            bytes32 scope_,
            bytes32 oldHash,
            bytes32 newHash
        ) = IStreamGovernedParameterAuthority(executor).currentAction();
        if (
            !executing || actionId == 0 || (value < prior ? actionClass != 1 : actionClass > 1)
                || scope_ != StreamArtistTimingState.scope(parameter)
                || oldHash != StreamArtistTimingState.stateHash(parameter, prior, floor, revision)
                || newHash
                    != StreamArtistTimingState.stateHash(parameter, value, floor, revision + 1)
        ) revert R.InvalidArtistWindowContext();
        bytes32 key = keccak256(abi.encode(actionId, parameter, oldHash, newHash));
        if (s.timingActions[key]) revert R.InvalidArtistWindowContext();
        s.timingActions[key] = true;
        s.timingRevision = revision + 1;
        if (parameter == keccak256("ARTIST_DORMANCY_MIN_INACTIVITY_SECONDS")) {
            s.inactivitySeconds = value;
        } else {
            s.noticeSeconds = value;
        }
        emit ArtistWindowChanged(1, parameter, prior, value, floor, revision + 1, actionId);
    }
}
