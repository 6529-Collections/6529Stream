// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
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
}
