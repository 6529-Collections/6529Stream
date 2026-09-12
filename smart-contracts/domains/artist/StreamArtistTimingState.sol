// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistRotationState.sol";
import "../../interfaces/stream/artist/IStreamArtistManagerBinding.sol";
import "../mint/StreamMintArtistConsent.sol";
import "../../interfaces/stream/parameters/IStreamGovernedParameterAuthority.sol";

/// @notice AA-owned operational windows, deliberately outside the GGP/GTP models.
library StreamArtistTimingState {
    event ArtistWindowChanged(
        uint16 schemaVersion,
        bytes32 indexed parameter,
        uint64 oldValue,
        uint64 newValue,
        uint64 floor,
        uint64 revision,
        bytes32 indexed actionId
    );

    function canonicalAuthority(address core, address manager)
        public
        view
        returns (address authority)
    {
        if (manager.code.length == 0 || IStreamArtistManagerBinding(manager).core() != core) {
            revert T.InvalidBinding();
        }
        authority = StreamMintArtistConsent.governance(
            core, IStreamArtistManagerBinding(manager).moduleRegistry()
        );
        if (
            IStreamArtistManagerBinding(manager).governanceAuthority() != authority
                || !IStreamGovernedParameterAuthority(authority)
                    .isStreamGovernedParameterAuthority()
        ) revert T.InvalidBinding();
    }

    function info(StreamArtistRotationState.State storage s, bytes32 parameter)
        public
        view
        returns (uint64 value, uint64 floor, uint64 revision)
    {
        if (parameter == keccak256("ARTIST_ROTATION_CONTEST_SECONDS")) {
            value = StreamArtistRotationState.rotationSeconds(s);
            floor = 72 hours;
        } else if (parameter == keccak256("ARTIST_PRIOR_ADDRESS_STANDING_TAIL_SECONDS")) {
            value = StreamArtistRotationState.standingSeconds(s);
            floor = 30 days;
        } else {
            revert R.InvalidArtistWindow(parameter);
        }
        revision = s.timingRevision == 0 ? 1 : s.timingRevision;
    }

    function scope(bytes32 parameter) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_WINDOW_SCOPE_V1"),
                block.chainid,
                address(this),
                parameter
            )
        );
    }

    function stateHash(bytes32 parameter, uint64 value, uint64 floor, uint64 revision)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_WINDOW_STATE_V1"),
                block.chainid,
                address(this),
                parameter,
                value,
                floor,
                revision
            )
        );
    }

    function configure(
        StreamArtistRotationState.State storage s,
        address authority,
        address actor,
        bytes32 parameter,
        uint64 newValue,
        uint64 expectedRevision
    ) public {
        if (actor != authority || authority == address(0)) {
            revert T.Unauthorized(actor);
        }
        (uint64 oldValue, uint64 floor, uint64 revision) = info(s, parameter);
        if (
            revision != expectedRevision || revision == type(uint64).max || newValue == oldValue
                || newValue < floor || block.timestamp > type(uint64).max
                || uint256(newValue) + block.timestamp > type(uint64).max
        ) revert R.InvalidArtistWindow(parameter);
        (
            bool executing,
            bytes32 actionId,
            uint8 actionClass,
            bytes32 scopeHash,
            bytes32 oldHash,
            bytes32 newHash
        ) = IStreamGovernedParameterAuthority(authority).currentAction();
        uint64 nextRevision = revision + 1;
        if (
            !executing || actionId == bytes32(0)
                || (newValue < oldValue ? actionClass != 1 : actionClass > 1)
                || scopeHash != scope(parameter)
                || oldHash != stateHash(parameter, oldValue, floor, revision)
                || newHash != stateHash(parameter, newValue, floor, nextRevision)
        ) revert R.InvalidArtistWindowContext();
        bytes32 actionKey = keccak256(abi.encode(actionId, parameter, oldHash, newHash));
        if (s.timingActions[actionKey]) revert R.InvalidArtistWindowContext();
        s.timingActions[actionKey] = true;
        s.timingRevision = nextRevision;
        if (parameter == keccak256("ARTIST_ROTATION_CONTEST_SECONDS")) {
            s.rotationContestSeconds = newValue;
        } else {
            s.priorStandingTailSeconds = newValue;
        }
        // Operational configuration has its own exact revision; it never updates artist liveness or records.
        emit ArtistWindowChanged(1, parameter, oldValue, newValue, floor, nextRevision, actionId);
    }
}
