// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistIdentityRecoveryState as Recovery
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistRotationState as Rotation } from "./StreamArtistRotationState.sol";
import { StreamArtistIdentityState as Identity } from "./StreamArtistIdentityState.sol";
import { StreamArtistGuardianHistory as History } from "./StreamArtistGuardianHistory.sol";
import {
    StreamArtistGuardianSupersession as Supersession
} from "./StreamArtistGuardianSupersession.sol";

/// @notice Original op28 history bookkeeping, delegated after the owner's authenticated guardian mutation.
/// @dev The owner retains its single commit, original semantic record and late Archive rollback boundary.
library StreamArtistGuardianAdmissionMutation {
    function record(
        Recovery.State storage recovery,
        Rotation.State storage rotations,
        Identity.OwnerContext memory owner,
        bytes32 artistId,
        bytes32 recordHash,
        bytes32 priorState
    ) public returns (bytes32 state) {
        uint64 admitted = ++recovery.guardianRecordsSeen[artistId];
        bytes32 historyCommitment = History.append(
            recovery.guardianHistory,
            owner.environment,
            rotations.guardians[recordHash],
            admitted,
            owner.revision + 1
        );
        bytes32 membershipCommitment = Supersession.indexAdmission(
            recovery.guardianSupersession,
            recovery.guardianHistory.entries[recordHash],
            rotations.guardians[recordHash]
        );
        state = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_GUARDIAN_ADMISSION_COUNT_V1"),
                priorState,
                artistId,
                admitted,
                historyCommitment
            )
        );
        state = keccak256(abi.encode(state, membershipCommitment));
    }
}
