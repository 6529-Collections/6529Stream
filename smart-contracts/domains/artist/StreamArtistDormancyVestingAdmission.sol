// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistDormancyState.sol";
import { StreamArtistIdentityRecoveryState } from "./StreamArtistIdentityRecoveryState.sol";
import {
    StreamArtistGuardianVestingHistory as History
} from "./StreamArtistGuardianVestingHistory.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";

/// @notice Original complete guardian-prefix admission for actual op43 successor/steward vesting.
library StreamArtistDormancyVestingAdmission {
    function record(
        StreamArtistDormancyState.State storage s,
        StreamArtistIdentityRecoveryState.State storage recovery,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistEstateState.State storage estate,
        StreamArtistHashes.Environment memory e,
        V.Input memory input
    ) public returns (bytes32) {
        Dorm.Terminal storage t = s.terminals[input.transitionRecordHash];
        Dorm.Notice storage n = s.notices[t.noticeHash];
        R.TransitionState storage transition = s.transitions[input.transitionRecordHash];
        T.Identity storage principal = identity.identities[input.artistId];
        if (
            input.operationId != 43 || t.recordHash != input.transitionRecordHash
                || n.terms.artistId != input.artistId || s.phases[t.noticeHash] != 3
                || s.terminalForNotice[t.noticeHash] != input.transitionRecordHash
                || s.activation[input.artistId] != input.transitionRecordHash
                || t.delegationEpoch != estate.delegationEpoch[input.artistId]
                || transition.recordHash != input.transitionRecordHash
                || transition.artistId != input.artistId || transition.phase != 2
                || transition.executedAt != block.timestamp
                || rotations.latestExecution[input.artistId] != input.transitionRecordHash
                || rotations.latestTransition[input.artistId] != input.transitionRecordHash
                || principal.authorityAddress != t.plan.authority
                || principal.authorityClass != t.plan.authorityClass
                || (principal.authorityClass != 3 && principal.authorityClass != 4)
                || principal.status != 3
                || identity.activeIdentity[t.plan.authority] != input.artistId
                || identity.activeIdentity[n.incumbent] != 0
                || rotations.retirement[input.artistId][n.incumbent] != input.transitionRecordHash
                || (recovery.guardianRecordsSeen[input.artistId] == 0
                    && (rotations.stableGuardian[input.artistId] != 0
                        || rotations.provisionalGuardian[input.artistId] != 0))
        ) revert V.InvalidGuardianVesting(input.transitionRecordHash);
        V.Snapshot memory item;
        item.artistId = input.artistId;
        item.transitionRecordHash = input.transitionRecordHash;
        item.operationId = 43;
        item.ownerRevision = input.ownerRevision;
        item.executedAt = transition.executedAt;
        item.oldAddress = n.incumbent;
        item.newAddress = t.plan.authority;
        item.authorityClass = t.plan.authorityClass;
        item.previousTransitionRecordHash = input.previousTransitionRecordHash;
        return History.record(
            recovery.vestingHistory,
            recovery.guardianHistory,
            e,
            item,
            recovery.guardianRecordsSeen[input.artistId]
        );
    }
}
