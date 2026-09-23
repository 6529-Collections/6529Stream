// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistAuthorityCheckpoint.sol";
import { StreamArtistAuthorityPreimages } from "./StreamArtistAuthorityPreimages.sol";
import {
    StreamArtistRecoveryEstateGuardians as EstateGuardians
} from "./StreamArtistRecoveryEstateGuardians.sol";
import {
    StreamArtistIdentityRecoveryState as RecoveryState
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistSuccessionState } from "./StreamArtistSuccessionState.sol";
import { StreamArtistIdentityContestState } from "./StreamArtistIdentityContestState.sol";
import {
    StreamArtistGuardianAppealTypes as Appeal
} from "../../interfaces/stream/artist/StreamArtistGuardianAppealTypes.sol";
import { StreamArtistGuardianAppealReads } from "./StreamArtistGuardianAppealReads.sol";
import {
    StreamArtistGuardianSupersession as GuardianSupersession
} from "./StreamArtistGuardianSupersession.sol";
import { StreamArtistGuardianVestingHistory } from "./StreamArtistGuardianVestingHistory.sol";
import {
    StreamArtistRecoveryHistoricalPredecessor as HistoricalPredecessor
} from "./StreamArtistRecoveryHistoricalPredecessor.sol";
import {
    StreamArtistRecoveryPredecessor as Predecessor
} from "./StreamArtistRecoveryPredecessor.sol";
import { StreamArtistGuardianHistory as GuardianHistory } from "./StreamArtistGuardianHistory.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";

import {
    StreamArtistRecoveryActionTypes as A
} from "../../interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import { StreamArtistRotationHashes } from "./StreamArtistRotationHashes.sol";
import { StreamArtistIdentityState } from "./StreamArtistIdentityState.sol";
import { StreamArtistRotationState } from "./StreamArtistRotationState.sol";
import { StreamArtistIdentityResolutionState } from "./StreamArtistIdentityResolutionState.sol";
import { StreamArtistEstateState } from "./StreamArtistEstateState.sol";
import {
    StreamArtistIdentityRecoveryReceipts as Receipts
} from "./StreamArtistIdentityRecoveryReceipts.sol";
import { StreamArtistIdentityRecoveryHashes as H } from "./StreamArtistIdentityRecoveryHashes.sol";
import {
    StreamArtistIdentityRecoveryTypes as Permanent
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as Dismissal
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "../../interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

import {
    StreamArtistRecoveryContinuation as Continuation
} from "./StreamArtistRecoveryContinuation.sol";

/// @notice Same-owner recovery mutations after the fixed State wrapper derives the full context.
/// @notice Original read-only preparation checks over the unchanged owner storage roots.
library StreamArtistIdentityRecoveryPreparationReads {
    function requireAppealWitness(
        RecoveryState.State storage s,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityState.OwnerContext memory o,
        Recovery.Request memory p,
        address proposer,
        bytes32 mutation,
        uint64 revision
    ) public view {
        if (
            p.supersededRecordHashes.length != 0
                && GuardianSupersession.authorityRole(
                        s.guardianSupersession,
                        s.guardianHistory,
                        s.vestingHistory,
                        rotations,
                        p.artistId,
                        p.supersededRecordHashes,
                        s.guardianRecordsSeen[p.artistId]
                    ) == Appeal.APPEAL
        ) {
            StreamArtistGuardianAppealReads.requireWitness(
                o.environment, proposer, mutation, revision
            );
        }
    }

    function guardian(
        RecoveryState.State storage s,
        StreamArtistRotationState.State storage r,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes32 artistId,
        address incumbent
    ) public view returns (R.GuardianRecord memory g) {
        if (r.latestExecution[artistId] != bytes32(0)) {
            return Predecessor.guardian(
                s.guardianHistory, r, o.environment, artistId, s.guardianRecordsSeen[artistId]
            );
        }
        bytes32 head = r.stableGuardian[artistId];
        uint64 count = s.guardianRecordsSeen[artistId];
        if (head == bytes32(0)) {
            if (count != 0) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            return g;
        }
        GuardianHistory.requireComplete(s.guardianHistory, artistId, count);
        g = r.guardians[head];
        if (
            count == 0 || g.recordHash != head || g.terms.artistId != artistId
                || g.authorityClass != 1 || g.signer != incumbent
                || g.provisional.transitionRecordHash != bytes32(0)
                || g.provisional.windowEndsAt != 0 || g.terms.guardians.length > 8
                || g.terms.minContestSeconds > 30 days
                || StreamArtistRotationHashes.guardianRecord(
                        o.environment, g.terms, T.Authorization(g.nonce, g.signedAt, bytes(""))
                    ) != head
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        }
    }
}
