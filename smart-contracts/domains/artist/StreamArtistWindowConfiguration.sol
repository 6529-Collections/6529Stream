// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistEstateTiming.sol";
import "./StreamArtistUnavailabilityState.sol";

/// @notice Fixed Identity window dispatch over its actual owner storage roots.
library StreamArtistWindowConfiguration {
    event ArtistWindowChanged(
        uint16 schemaVersion,
        bytes32 indexed parameter,
        uint64 oldValue,
        uint64 newValue,
        uint64 floor,
        uint64 revision,
        bytes32 indexed actionId
    );

    function info(
        StreamArtistRotationState.State storage rotations,
        StreamArtistEstateState.State storage estate,
        StreamArtistUnavailabilityState.State storage findings,
        bytes32 parameter
    ) public view returns (uint64, uint64, uint64) {
        if (parameter == keccak256("ARTIST_ESTATE_ACTIVATION_NOTICE_SECONDS")) {
            return StreamArtistEstateState.timing(estate);
        }
        if (parameter == keccak256("ARTIST_UNAVAILABILITY_RECOVERY_NOTICE_SECONDS")) {
            return StreamArtistUnavailabilityState.timing(findings);
        }
        return StreamArtistTimingState.info(rotations, parameter);
    }

    function scope(
        StreamArtistRotationState.State storage rotations,
        StreamArtistEstateState.State storage estate,
        StreamArtistUnavailabilityState.State storage findings,
        bytes32 parameter
    ) public view returns (bytes32) {
        info(rotations, estate, findings, parameter);
        return StreamArtistTimingState.scope(parameter);
    }

    function stateHash(
        StreamArtistRotationState.State storage rotations,
        StreamArtistEstateState.State storage estate,
        StreamArtistUnavailabilityState.State storage findings,
        bytes32 parameter,
        uint64 value,
        uint64 revision
    ) public view returns (bytes32) {
        (, uint64 floor,) = info(rotations, estate, findings, parameter);
        return StreamArtistTimingState.stateHash(parameter, value, floor, revision);
    }

    function configure(
        StreamArtistRotationState.State storage rotations,
        StreamArtistEstateState.State storage estate,
        StreamArtistUnavailabilityState.State storage findings,
        address executor,
        address actor,
        bytes32 parameter,
        uint64 value,
        uint64 expectedRevision
    ) public {
        if (parameter == keccak256("ARTIST_ESTATE_ACTIVATION_NOTICE_SECONDS")) {
            StreamArtistEstateTiming.configure(estate, executor, actor, value, expectedRevision);
        } else if (parameter == keccak256("ARTIST_UNAVAILABILITY_RECOVERY_NOTICE_SECONDS")) {
            _configureFinding(findings, executor, actor, value, expectedRevision);
        } else {
            StreamArtistTimingState.configure(
                rotations, executor, actor, parameter, value, expectedRevision
            );
        }
    }

    function _configureFinding(
        StreamArtistUnavailabilityState.State storage s,
        address executor,
        address actor,
        uint64 value,
        uint64 expectedRevision
    ) private {
        bytes32 parameter = keccak256("ARTIST_UNAVAILABILITY_RECOVERY_NOTICE_SECONDS");
        if (actor != executor || executor == address(0)) revert T.Unauthorized(actor);
        (uint64 prior, uint64 floor, uint64 revision) = StreamArtistUnavailabilityState.timing(s);
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
            !executing || actionId == bytes32(0)
                || (value < prior ? actionClass != 1 : actionClass > 1)
                || scope_ != StreamArtistTimingState.scope(parameter)
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
        s.timingRevision = revision + 1;
        emit ArtistWindowChanged(1, parameter, prior, value, floor, revision + 1, actionId);
    }
}
