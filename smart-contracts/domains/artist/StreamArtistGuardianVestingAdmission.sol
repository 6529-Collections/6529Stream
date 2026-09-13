// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistGuardianVestingHistory as History
} from "./StreamArtistGuardianVestingHistory.sol";
import {
    StreamArtistIdentityRecoveryState as RecoveryState
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistIdentityState } from "./StreamArtistIdentityState.sol";
import { StreamArtistRotationState } from "./StreamArtistRotationState.sol";
import { StreamArtistEstateState } from "./StreamArtistEstateState.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistEstateTypes as Estate
} from "../../interfaces/stream/artist/StreamArtistEstateTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";

/// @notice Authenticates the fixed owner's just-executed original record before saving its prefix.
library StreamArtistGuardianVestingAdmission {
    function record(
        RecoveryState.State storage recovery,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistEstateState.State storage estate,
        StreamArtistHashes.Environment memory environment,
        V.Input memory input
    ) public returns (bytes32) {
        V.Snapshot memory item;
        item.artistId = input.artistId;
        item.transitionRecordHash = input.transitionRecordHash;
        item.previousTransitionRecordHash = input.previousTransitionRecordHash;
        item.ownerRevision = input.ownerRevision;
        item.operationId = input.operationId;
        R.TransitionState memory transition;
        if (input.operationId == 32) {
            R.RotationRecord storage original = rotations.rotations[input.transitionRecordHash];
            if (
                original.recordHash != input.transitionRecordHash
                    || original.terms.artistId != input.artistId
            ) {
                revert V.InvalidGuardianVesting(input.transitionRecordHash);
            }
            item.oldAddress = original.terms.oldAddress;
            item.newAddress = original.terms.newAddress;
            transition = original.transition;
        } else if (input.operationId == 40) {
            Estate.RequestRecord storage original = estate.requests[input.transitionRecordHash];
            if (
                original.recordHash != input.transitionRecordHash
                    || original.terms.artistId != input.artistId
                    || estate.phases[input.transitionRecordHash] != 2
                    || estate.executions[input.transitionRecordHash].activationRecordHash
                        != input.transitionRecordHash
            ) {
                revert V.InvalidGuardianVesting(input.transitionRecordHash);
            }
            item.oldAddress = original.incumbent;
            item.newAddress = original.terms.successor;
            transition = estate.transitions[input.transitionRecordHash];
        } else if (input.operationId == 35) {
            Recovery.Record storage original = recovery.records[input.transitionRecordHash];
            if (
                original.recordHash != input.transitionRecordHash
                    || original.fields.artistId != input.artistId
                    || recovery.latest[input.artistId] != input.transitionRecordHash
                    || original.fields.vestedAuthorityClass
                        != identity.identities[input.artistId].authorityClass
            ) {
                revert V.InvalidGuardianVesting(input.transitionRecordHash);
            }
            item.oldAddress = original.fields.oldAddress;
            item.newAddress = original.fields.newAddress;
            transition = recovery.transitions[input.transitionRecordHash];
        } else {
            revert V.InvalidGuardianVesting(input.transitionRecordHash);
        }
        T.Identity storage principal = identity.identities[input.artistId];
        item.authorityClass = principal.authorityClass;
        item.executedAt = transition.executedAt;
        if (
            transition.artistId != input.artistId
                || transition.recordHash != input.transitionRecordHash || transition.phase != 2
                || rotations.latestExecution[input.artistId] != input.transitionRecordHash
                || principal.authorityAddress != item.newAddress
                || identity.activeIdentity[item.newAddress] != input.artistId
                || identity.activeIdentity[item.oldAddress] != 0
                || rotations.retirement[input.artistId][item.oldAddress]
                    != input.transitionRecordHash
                || !((principal.authorityClass == 1 && principal.status == 1)
                    || (principal.authorityClass == 3 && principal.status == 3))
                || (recovery.guardianRecordsSeen[input.artistId] == 0
                    && (rotations.stableGuardian[input.artistId] != 0
                        || rotations.provisionalGuardian[input.artistId] != 0))
        ) {
            revert V.InvalidGuardianVesting(input.transitionRecordHash);
        }
        return History.record(
            recovery.vestingHistory,
            recovery.guardianHistory,
            environment,
            item,
            recovery.guardianRecordsSeen[input.artistId]
        );
    }
}
