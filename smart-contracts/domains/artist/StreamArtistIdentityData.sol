// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistContentHashes.sol";

import "./StreamArtistEconomicsHashes.sol";

import "./StreamArtistOwner.sol";
import "./StreamArtistNonceAvailability.sol";
import "./StreamArtistDelegationState.sol";
import "./StreamArtistIdentityState.sol";
import "./StreamArtistBindingOperations.sol";
import "./StreamArtistCollaboratorIdentityState.sol";
import "./StreamArtistAuthorizationState.sol";
import "./StreamArtistIdentityRevisionState.sol";
import "./StreamArtistIdentityConsentState.sol";
import "./StreamArtistRotationState.sol";
import "./StreamArtistIdentityContestState.sol";
import "./StreamArtistSuccessionState.sol";
import "./StreamArtistIdentityResolutionState.sol";
import "./StreamArtistTimingState.sol";
import "./StreamArtistEstateState.sol";
import "./StreamArtistUnavailabilityState.sol";
import "./StreamArtistIdentityActivity.sol";
import "../../interfaces/stream/artist/IStreamArtistRotationOwner.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @dev Exact shared physical Identity storage. Owner prefix precedes this base.
abstract contract StreamArtistIdentityData {
    // Struct members preserve the exact six preexisting physical slots in declaration order.
    StreamArtistIdentityState.State internal _identity;
    StreamArtistDelegationState.State internal _delegations;
    StreamArtistCollaboratorIdentityState.State internal _collaboratorAccounts;
    StreamArtistIdentityRevisionState.State internal _identityRevisions;
    StreamArtistRotationState.State internal _rotations;
    StreamArtistIdentityContestState.State internal _identityContests;
    StreamArtistSuccessionState.State internal _succession;
    StreamArtistIdentityResolutionState.State internal _resolutions;
    // Estate state is appended after every prior Identity root; existing nested structs stay fixed.
    StreamArtistEstateState.State internal _estate;
    StreamArtistUnavailabilityState.State internal _unavailability;

    function _noteLiving(
        StreamArtistIdentityState.OwnerContext memory o,
        mapping(bytes32 => T.ReplayCell) storage replay,
        bytes32 artistId,
        address signer,
        uint16 operation,
        StreamArtistIdentityState.Mutation memory m
    ) internal {
        (bytes32 stateDelta, bytes32 replayDelta, bytes32 findingDelta) = StreamArtistIdentityActivity.note(
            _estate, _identity, _unavailability, replay, o, artistId, signer, operation
        );
        if (stateDelta != bytes32(0)) m.state = keccak256(abi.encode(m.state, stateDelta));
        if (replayDelta != bytes32(0)) m.replay = keccak256(abi.encode(m.replay, replayDelta));
        if (findingDelta != bytes32(0)) m.state = keccak256(abi.encode(m.state, findingDelta));
    }

    /// @dev Separate from the estate living-only predicate. The original callback must have
    ///      authenticated this current principal and rolls the delta back on any later failure.
    function _noteCurrentAuthority(
        bytes32 artistId,
        address signer,
        uint16 operation,
        StreamArtistIdentityState.Mutation memory m
    ) internal {
        bytes32 delta = StreamArtistUnavailabilityState.notePrincipalActivity(
            _unavailability, _identity.identities[artistId], artistId, signer, operation
        );
        if (delta != bytes32(0)) m.state = keccak256(abi.encode(m.state, delta));
    }

    function _noteFindingActivity(
        bytes32 artistId,
        address signer,
        uint8 authorityClass,
        uint16 operation,
        StreamArtistIdentityState.Mutation memory m
    ) internal {
        bytes32 delta =
            StreamArtistUnavailabilityState.noteActivity(
                _unavailability, artistId, signer, authorityClass, operation
            );
        if (delta != bytes32(0)) m.state = keccak256(abi.encode(m.state, delta));
    }

    function _identityContestResolution(bytes32 artistId, bytes32 subject)
        internal
        view
        returns (Dismissal.ContestResolutionFacts memory facts)
    {
        facts.subjectClosure = _resolutions.closures[subject];
        facts.executedClosure = _resolutions.closures[_rotations.latestExecution[artistId]];
        facts.currentCauseHash = _resolutions.currentCause[artistId];
        facts.currentResolutionHash = _resolutions.latestResolution[artistId];
    }

    function _currentIdentityClosure(bytes32 artistId)
        internal
        view
        returns (Dismissal.Closure memory)
    {
        return _resolutions.closures[_rotations.latestExecution[artistId]];
    }
}
