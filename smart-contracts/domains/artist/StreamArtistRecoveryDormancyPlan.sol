// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistLivingDormancyBoundary as LivingBoundary
} from "./StreamArtistLivingDormancyBoundary.sol";

import {
    StreamArtistIdentityRecoveryState as RecoveryState
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistEstateState as EstateState } from "./StreamArtistEstateState.sol";
import {
    StreamArtistIdentityContestState as ContestState
} from "./StreamArtistIdentityContestState.sol";
import {
    StreamArtistIdentityResolutionState as Resolution
} from "./StreamArtistIdentityResolutionState.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import { StreamArtistRotationState } from "./StreamArtistRotationState.sol";
import { StreamArtistSuccessionState } from "./StreamArtistSuccessionState.sol";
import { StreamArtistSuccessionHashes } from "./StreamArtistSuccessionHashes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistSuccessionTypes as Succ
} from "../../interfaces/stream/artist/StreamArtistSuccessionTypes.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "../../interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as Dismissal
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";

import "./StreamArtistDormancyState.sol";
import {
    StreamArtistRecoveryDormancyClosure as DormClosure
} from "./StreamArtistRecoveryDormancyClosure.sol";
import {
    StreamArtistRecoveryDormancyGuardians as DormGuardians
} from "./StreamArtistRecoveryDormancyGuardians.sol";

import {
    StreamArtistRecoveryDormancyStanding as DormStanding
} from "./StreamArtistRecoveryDormancyStanding.sol";

import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";
import {
    StreamArtistRecoveredHydrationState as Imported
} from "./StreamArtistRecoveredHydrationState.sol";

import {
    StreamArtistRecoveryDormancyEvidence as Evidence
} from "./StreamArtistRecoveryDormancyEvidence.sol";

/// @notice Fixed typed recovery read worker; preserves the original host context and checks.
library StreamArtistRecoveryDormancyPlan {
    function _previous(
        RecoveryState.State storage s,
        StreamArtistRotationState.State storage r,
        StreamArtistHashes.Environment memory e,
        Dorm.Notice memory notice,
        V.Snapshot memory vesting,
        V.Snapshot memory previous,
        bool resolvedBoundary
    ) public view returns (V.Snapshot memory) {
        bytes32 prior = vesting.previousTransitionRecordHash;
        if (prior == 0) {
            if (vesting.previousCommitment != 0) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(vesting.artistId);
            }
            return previous;
        }
        previous = s.vestingHistory.snapshots[prior];
        R.RotationRecord memory old = r.rotations[prior];
        if (
            previous.commitment == 0 || previous.commitment != vesting.previousCommitment
                || previous.commitment != Evidence._vestingHash(e, previous)
                || previous.artistId != vesting.artistId || previous.transitionRecordHash != prior
                || previous.operationId != 32 || previous.authorityClass != 1
                || previous.newAddress != notice.incumbent || previous.oldAddress == address(0)
                || previous.oldAddress == previous.newAddress
                || !Evidence._before(e, previous, vesting)
                || previous.executedAt > notice.initiatedAt
                || previous.guardians.count > vesting.guardians.count
                || (Imported.commitment() == 0
                    && previous.guardians.ownerRevision > vesting.guardians.ownerRevision)
                || old.recordHash != prior || old.terms.artistId != vesting.artistId
                || old.terms.oldAddress != previous.oldAddress
                || old.terms.newAddress != previous.newAddress
                || old.transition.artistId != vesting.artistId || old.transition.recordHash != prior
                || old.transition.phase != 2 || old.transition.executedAt != previous.executedAt
                || (!resolvedBoundary
                    && (old.transition.postWindowEndsAt > notice.initiatedAt
                        || (old.transition.contestedAt != 0
                            && old.transition.contestedAt < old.transition.postWindowEndsAt)))
                || StreamArtistRotationHashes.rotationRecord(
                        Evidence._recordEnvironment(e, 29, vesting.artistId, prior),
                        old.terms,
                        old.oldNonce,
                        old.transition.stagedAt,
                        old.transition.contestEndsAt
                    ) != prior
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(vesting.artistId);
        // The fixed producer admitted this same-artist latest-head chain once; no mutable retirement guess.
        return previous;
    }

    function _eligible(
        StreamArtistRotationState.State storage r,
        bytes32 id,
        R.ProvisionalAssociation memory a
    ) public view returns (bool) {
        return a.transitionRecordHash == 0
            ? a.windowEndsAt == 0
            : StreamArtistRotationState.eligible(r, id, a);
    }

    function _directive(
        StreamArtistRotationState.State storage r,
        StreamArtistHashes.Environment memory e,
        Dorm.Notice memory notice,
        V.Snapshot memory vesting,
        Succ.DirectiveRecord memory d,
        bytes32 hash
    ) public view {
        if (hash == 0) {
            Succ.DirectiveRecord memory empty;
            if (keccak256(abi.encode(d)) != keccak256(abi.encode(empty))) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(vesting.artistId);
            }
            return;
        }
        if (
            d.recordHash != hash || d.terms.artistId != vesting.artistId || d.authorityClass != 1
                || d.signer == address(0)
                || (vesting.previousTransitionRecordHash == 0 && d.signer != notice.incumbent)
                || d.signedAt > notice.initiatedAt || !_eligible(r, vesting.artistId, d.provisional)
                || StreamArtistSuccessionHashes.directiveRecord(
                        Evidence._recordEnvironment(e, 37, notice.terms.artistId, hash),
                        d.terms,
                        T.Authorization(d.nonce, d.signedAt, bytes(""))
                    ) != hash
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(vesting.artistId);
    }
}
