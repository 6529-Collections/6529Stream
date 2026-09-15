// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistStewardCapabilityState.sol";
import { StreamArtistDormancyState } from "./StreamArtistDormancyState.sol";
import { StreamArtistStewardSanctionState } from "./StreamArtistStewardSanctionState.sol";
import { StreamArtistGuardianVestingAdmission } from "./StreamArtistGuardianVestingAdmission.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";

import "./StreamArtistContentHashes.sol";

import "./StreamArtistEconomicsHashes.sol";

import "./StreamArtistOwner.sol";
import "./StreamArtistNonceAvailability.sol";
import "./StreamArtistDelegationState.sol";
import "./StreamArtistIdentityState.sol";
import { StreamArtistIdentityRecoveryState } from "./StreamArtistIdentityRecoveryState.sol";
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
    // Operation35 appends its own history/receipt roots after every existing Identity field.
    StreamArtistIdentityRecoveryState.State internal _identityRecovery;
    // Dormancy and original op19 append roots after every accepted Identity field.
    StreamArtistDormancyState.State internal _dormancy;
    StreamArtistStewardSanctionState.State internal _stewardGrants;
    // Explicit additive operation59; original appointment records and prior roots stay fixed.
    StreamArtistStewardCapabilityState.State internal _stewardCapabilityGrants;

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
        _noteDormancy(o, replay, artistId, signer, 1, m);
    }

    /// @dev Separate from the estate living-only predicate. The original callback must have
    ///      authenticated this current principal and rolls the delta back on any later failure.
    function _noteCurrentAuthority(
        StreamArtistIdentityState.OwnerContext memory o,
        mapping(bytes32 => T.ReplayCell) storage replay,
        bytes32 artistId,
        address signer,
        uint16 operation,
        StreamArtistIdentityState.Mutation memory m
    ) internal {
        bytes32 delta = StreamArtistUnavailabilityState.notePrincipalActivity(
            _unavailability, _identity.identities[artistId], artistId, signer, operation
        );
        if (delta != bytes32(0)) m.state = keccak256(abi.encode(m.state, delta));
        _noteDormancy(o, replay, artistId, signer, 1, m);
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

    function _noteGuardianVesting(
        StreamArtistHashes.Environment memory environment,
        V.Input memory input,
        StreamArtistIdentityState.Mutation memory mutation
    ) internal {
        bytes32 commitment = StreamArtistGuardianVestingAdmission.record(
            _identityRecovery, _identity, _rotations, _estate, environment, input
        );
        mutation.state = keccak256(abi.encode(mutation.state, commitment));
    }

    function _noteDormancy(
        StreamArtistIdentityState.OwnerContext memory o,
        mapping(bytes32 => T.ReplayCell) storage replay,
        bytes32 id,
        address signer,
        uint8 class_,
        StreamArtistIdentityState.Mutation memory m
    ) internal {
        (bytes32 delta, bytes32 replayDelta) = StreamArtistDormancyState.activity(
            _dormancy, _identity, replay, o, id, signer, class_
        );
        if (delta != 0) m.state = keccak256(abi.encode(m.state, delta));
        if (replayDelta != 0) m.replay = keccak256(abi.encode(m.replay, replayDelta));
    }
}
