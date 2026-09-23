// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistIdentityRecoveryState } from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistEstateState } from "./StreamArtistEstateState.sol";
import "./StreamArtistIdentityDismissalState.sol";

/// @notice Explicit compiler-linked view encoding over the Identity owner's storage.
/// @dev Each result is the canonical public return tuple, without a bytes wrapper.
///      Standalone library calls are not authoritative Identity reads.
library StreamArtistIdentityResolutionReads {
    function identity(StreamArtistIdentityState.State storage s, bytes32 artistId)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(s.identities[artistId]);
    }

    function guardian(StreamArtistRotationState.State storage s, bytes32 hash)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(s.guardians[hash]);
    }

    function rotation(StreamArtistRotationState.State storage s, bytes32 hash)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(s.rotations[hash]);
    }

    function delegation(StreamArtistDelegationState.State storage s, bytes32 hash)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(s.records[hash]);
    }

    function context(
        StreamArtistIdentityResolutionState.State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityRevisionState.State storage revisions,
        StreamArtistSuccessionState.State storage succession,
        StreamArtistHashes.Environment memory e,
        Dismissal.Request memory p
    ) public view returns (bytes memory) {
        return abi.encode(
            StreamArtistIdentityDismissalState.context(
                s, identity, rotations, revisions, succession, e, p
            )
        );
    }

    function currentCause(StreamArtistIdentityResolutionState.State storage s, bytes32 artistId)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(s.causes[s.currentCause[artistId]]);
    }

    function cause(StreamArtistIdentityResolutionState.State storage s, bytes32 hash)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(s.causes[hash]);
    }

    function record(StreamArtistIdentityResolutionState.State storage s, bytes32 hash)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(s.records[hash]);
    }

    function latest(StreamArtistIdentityResolutionState.State storage s, bytes32 artistId)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(s.latestResolution[artistId]);
    }

    function closure(
        StreamArtistIdentityResolutionState.State storage s,
        bytes32 artistId,
        bytes32 transition
    ) public view returns (bytes memory) {
        Dismissal.Closure memory item = s.closures[transition];
        if (item.dismissalRecordHash != bytes32(0) && item.artistId != artistId) {
            revert Dismissal.InvalidClosure(transition);
        }
        return abi.encode(item);
    }

    function continuation(StreamArtistIdentityResolutionState.State storage s, bytes32 hash)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(s.continuations[hash]);
    }

    function pendingRotation(StreamArtistRotationState.State storage rotations, bytes32 artistId)
        public
        view
        returns (bytes memory)
    {
        bytes32 record = rotations.pending[artistId];
        R.RotationRecord storage r = rotations.rotations[record];
        return abi.encode(
            r.terms.oldAddress,
            r.terms.newAddress,
            r.transition.contestEndsAt,
            r.guardianApprovals,
            record
        );
    }

    function standingRevocationRecord(
        StreamArtistRotationState.State storage rotations,
        bytes32 record
    ) public view returns (bytes memory) {
        return abi.encode(rotations.standingRecords[record]);
    }

    function artistTransitionState(
        StreamArtistRotationState.State storage rotations,
        StreamArtistEstateState.State storage estate_,
        StreamArtistIdentityRecoveryState.State storage recovery,
        bytes32 record
    ) public view returns (bytes memory) {
        if (record == bytes32(0)) {
            R.TransitionState memory empty;
            return abi.encode(empty);
        }
        bool rotation = rotations.rotations[record].recordHash == record;
        bool estate = estate_.requests[record].recordHash == record;
        bool recovered = recovery.records[record].recordHash == record;
        if ((rotation ? 1 : 0) + (estate ? 1 : 0) + (recovered ? 1 : 0) != 1) {
            revert R.InvalidRotation(record);
        }
        R.TransitionState memory t = rotation
            ? rotations.rotations[record].transition
            : estate ? estate_.transitions[record] : recovery.transitions[record];
        if (recovered && t.artistId != recovery.records[record].fields.artistId) {
            revert R.InvalidRotation(record);
        }
        if (t.recordHash != record || t.artistId == bytes32(0) || t.phase == 0) {
            revert R.InvalidRotation(record);
        }
        return abi.encode(t);
    }
}
