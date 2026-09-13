// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistIdentityRecoveryState as RecoveryState
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistRotationState as RotationState } from "./StreamArtistRotationState.sol";
import { StreamArtistEstateState as EstateState } from "./StreamArtistEstateState.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as I
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistRecoveryActionTypes as A
} from "../../interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";

/// @notice Fixed Identity wrappers authenticate the storage supplying these encoded reads.
library StreamArtistRecoveryOwnerReads {
    function record(RecoveryState.State storage s, bytes32 hash)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(s.records[hash]);
    }

    function action(RecoveryState.State storage s, bytes32 artistId, bytes32 actionId)
        public
        view
        returns (bytes memory)
    {
        if (actionId == bytes32(0)) actionId = s.pendingAction[artistId];
        A.Association storage a = s.actions[actionId];
        if (a.associationHash != bytes32(0) && a.artistId != artistId) {
            revert A.InvalidRecoveryAction(actionId);
        }
        return abi.encode(
            a, s.vetoes[actionId], s.actionExecutions[actionId], s.guardianRecordsSeen[artistId]
        );
    }

    function standing(
        RecoveryState.State storage s,
        RotationState.State storage rotations,
        EstateState.State storage estate,
        bytes32 hash
    ) public view returns (address, bytes32, uint64) {
        I.Record storage item = s.records[hash];
        R.TransitionState storage t = s.transitions[hash];
        if (
            hash == bytes32(0) || item.recordHash != hash || item.fields.artistId == bytes32(0)
                || item.fields.oldAddress == address(0) || item.standingTailSeconds < 30 days
                || t.recordHash != hash || t.artistId != item.fields.artistId || t.phase == 0
                || rotations.rotations[hash].recordHash != bytes32(0)
                || estate.requests[hash].recordHash != bytes32(0)
        ) revert R.InvalidRotation(hash);
        bytes32 guardian = s.recoveryGuardians[hash];
        if (guardian != bytes32(0)) {
            A.Association storage a = s.actions[item.fields.governanceActionId];
            if (
                a.associationHash == bytes32(0) || a.artistId != item.fields.artistId
                    || s.actionExecutions[item.fields.governanceActionId] != hash
                    || a.guardian.recordHash != guardian
                    || rotations.guardians[guardian].recordHash != guardian
                    || keccak256(abi.encode(a.guardian))
                        != keccak256(abi.encode(rotations.guardians[guardian]))
            ) {
                revert R.InvalidRotation(hash);
            }
        }
        return (item.fields.oldAddress, guardian, item.standingTailSeconds);
    }
}
