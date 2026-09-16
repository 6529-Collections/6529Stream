// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistIdentityActivity.sol";
import { StreamArtistDormancyState } from "./StreamArtistDormancyState.sol";

/// @notice Fixed activity-delta worker; admission stays in each original owner recipe.
library StreamArtistIdentityActivityMutation {
    function noteLiving(
        StreamArtistEstateState.State storage _estate,
        StreamArtistIdentityState.State storage _identity,
        StreamArtistUnavailabilityState.State storage _unavailability,
        StreamArtistDormancyState.State storage _dormancy,
        StreamArtistIdentityState.OwnerContext memory o,
        mapping(bytes32 => T.ReplayCell) storage replay,
        bytes32 artistId,
        address signer,
        uint16 operation,
        StreamArtistIdentityState.Mutation memory m
    ) public returns (bytes32, bytes32) {
        (bytes32 stateDelta, bytes32 replayDelta, bytes32 findingDelta) = StreamArtistIdentityActivity.note(
            _estate, _identity, _unavailability, replay, o, artistId, signer, operation
        );
        if (stateDelta != bytes32(0)) m.state = keccak256(abi.encode(m.state, stateDelta));
        if (replayDelta != bytes32(0)) m.replay = keccak256(abi.encode(m.replay, replayDelta));
        if (findingDelta != bytes32(0)) m.state = keccak256(abi.encode(m.state, findingDelta));
        (m.state, m.replay) = noteDormancy(_dormancy, _identity, o, replay, artistId, signer, 1, m);

        return (m.state, m.replay);
    }

    function noteCurrentAuthority(
        StreamArtistIdentityState.State storage _identity,
        StreamArtistUnavailabilityState.State storage _unavailability,
        StreamArtistDormancyState.State storage _dormancy,
        StreamArtistIdentityState.OwnerContext memory o,
        mapping(bytes32 => T.ReplayCell) storage replay,
        bytes32 artistId,
        address signer,
        uint16 operation,
        StreamArtistIdentityState.Mutation memory m
    ) public returns (bytes32, bytes32) {
        bytes32 delta = StreamArtistUnavailabilityState.notePrincipalActivity(
            _unavailability, _identity.identities[artistId], artistId, signer, operation
        );
        if (delta != bytes32(0)) m.state = keccak256(abi.encode(m.state, delta));
        (m.state, m.replay) = noteDormancy(_dormancy, _identity, o, replay, artistId, signer, 1, m);

        return (m.state, m.replay);
    }

    function noteDormancy(
        StreamArtistDormancyState.State storage _dormancy,
        StreamArtistIdentityState.State storage _identity,
        StreamArtistIdentityState.OwnerContext memory o,
        mapping(bytes32 => T.ReplayCell) storage replay,
        bytes32 id,
        address signer,
        uint8 class_,
        StreamArtistIdentityState.Mutation memory m
    ) public returns (bytes32, bytes32) {
        (bytes32 delta, bytes32 replayDelta) = StreamArtistDormancyState.activity(
            _dormancy, _identity, replay, o, id, signer, class_
        );
        if (delta != 0) m.state = keccak256(abi.encode(m.state, delta));
        if (replayDelta != 0) m.replay = keccak256(abi.encode(m.replay, replayDelta));

        return (m.state, m.replay);
    }
}
