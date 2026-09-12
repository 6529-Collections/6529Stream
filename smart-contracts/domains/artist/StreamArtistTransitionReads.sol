// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistRotationState.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import "../../interfaces/stream/artist/IStreamArtistEstateOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistRotationOwner.sol";

/// @notice Linked actual-transition reads; estate fallback is hardwired to the same Identity.
library StreamArtistTransitionReads {
    function pendingTransition(StreamArtistRotationState.State storage s, bytes32 artistId)
        public
        view
        returns (bytes32 record)
    {
        record = s.pending[artistId];
        if (record == bytes32(0)) record = s.latestTransition[artistId];
        if (record == bytes32(0)) return record;
        R.TransitionState memory t = transitionState(s, record);
        if (t.artistId != artistId) revert T.InvalidIdentity(artistId);
        if (t.phase != 1) return bytes32(0);
    }

    function transitionStanding(StreamArtistRotationState.State storage s, bytes32 record)
        public
        view
        returns (address priorAddress, bytes32 guardianRecord, uint64 standingTail)
    {
        if (record == bytes32(0)) return (address(0), bytes32(0), 0);
        if (s.rotations[record].recordHash != bytes32(0)) {
            R.RotationRecord storage r = s.rotations[record];
            return (r.terms.oldAddress, r.guardianSetRecordHash, r.standingTail);
        }
        bytes memory data =
            abi.encodeCall(IStreamArtistEstateOwner.estateTransitionStanding, (record));
        bytes memory result = new bytes(96);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), address(), add(data, 32), mload(data), add(result, 32), 96)
            size := returndatasize()
        }
        if (!ok || size != 96) revert R.InvalidRotation(record);
        return abi.decode(result, (address, bytes32, uint64));
    }

    function transitionState(StreamArtistRotationState.State storage s, bytes32 record)
        public
        view
        returns (R.TransitionState memory t)
    {
        if (record == bytes32(0)) return t;
        R.RotationRecord storage rotation = s.rotations[record];
        if (rotation.recordHash != bytes32(0)) {
            t = rotation.transition;
        } else {
            bytes memory data =
                abi.encodeCall(IStreamArtistRotationReads.artistTransitionState, (record));
            bytes memory result = new bytes(256);
            bool ok;
            uint256 size;
            assembly ("memory-safe") {
                ok := staticcall(gas(), address(), add(data, 32), mload(data), add(result, 32), 256)
                size := returndatasize()
            }
            if (!ok || size != 256) revert R.InvalidRotation(record);
            t = abi.decode(result, (R.TransitionState));
        }
        if (t.recordHash != record || t.artistId == bytes32(0) || t.phase == 0) {
            revert R.InvalidRotation(record);
        }
    }

    function activeWindow(StreamArtistRotationState.State storage s, bytes32 artistId)
        public
        view
        returns (bytes32 record, uint64 endsAt, bool contested)
    {
        record = pendingTransition(s, artistId);
        if (record != bytes32(0)) {
            R.TransitionState memory pending_ = transitionState(s, record);
            if (pending_.artistId != artistId) revert T.InvalidIdentity(artistId);
            return (record, pending_.contestEndsAt, pending_.contestedAt != 0);
        }
        record = s.latestExecution[artistId];
        if (record == bytes32(0)) return (bytes32(0), 0, false);
        R.TransitionState memory executed = transitionState(s, record);
        if (executed.artistId != artistId) revert T.InvalidIdentity(artistId);
        if (
            (executed.contestedAt != 0 && executed.contestedAt < executed.postWindowEndsAt)
                || block.timestamp < executed.postWindowEndsAt
        ) {
            return (record, executed.postWindowEndsAt, executed.contestedAt != 0);
        }
        return (bytes32(0), 0, false);
    }
}
