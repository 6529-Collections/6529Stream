// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRecoveryRewindState as Rewind } from "./StreamArtistRecoveryRewindState.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistIdentityRecoveryState as Recovery
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistRotationState as Rotations } from "./StreamArtistRotationState.sol";
import {
    StreamArtistIdentityRevisionState as Revisions
} from "./StreamArtistIdentityRevisionState.sol";
import { StreamArtistSuccessionState as Succession } from "./StreamArtistSuccessionState.sol";
import { StreamArtistStewardSanctionState as Grants } from "./StreamArtistStewardSanctionState.sol";
import {
    StreamArtistIdentityResolutionState as Resolutions
} from "./StreamArtistIdentityResolutionState.sol";
import {
    StreamArtistGuardianSupersessionTypes as G
} from "../../interfaces/stream/artist/StreamArtistGuardianSupersessionTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";

/// @notice Exact raw pointer and supplemental evidence reads for the fixed V3 selector.
library StreamArtistRecoveryRewindInventory {
    function inventory(
        Rewind.State storage rewind,
        Rotations.State storage rotations,
        Revisions.State storage revisions,
        Succession.State storage succession,
        Grants.State storage grants,
        bytes32 id
    ) public view returns (W.IdentityInventoryV3 memory f) {
        f.guardians = W.FamilyPointers(
            rotations.stableGuardian[id], rotations.provisionalGuardian[id]
        );
        f.designations =
            W.FamilyPointers(succession.stableDesignation[id], succession.candidateDesignation[id]);
        f.directives =
            W.FamilyPointers(succession.stableDirective[id], succession.candidateDirective[id]);
        f.revisions = W.FamilyPointers(revisions.latestRecord[id], revisions.pendingRecord[id]);
        f.sanctionGrants = W.FamilyPointers(grants.stable[id], grants.candidate[id]);
        f.revisionContinuationHash = rewind.revisionHead[id];
        f.supersessionStateCommitment = rewind.statusCommitments[id];
    }

    function status(
        Rewind.State storage rewind,
        Recovery.State storage recovery,
        W.RecordKind kind,
        bytes32 hash
    ) public view returns (W.StatusV3 memory f) {
        if (kind == W.RecordKind.GUARDIAN_SET) {
            G.Status memory original = recovery.guardianSupersession.statuses[hash];
            if (original.recoveryRecordHash == 0) return f;
            f = W.StatusV3(
                original.artistId,
                kind,
                original.recoveryRecordHash,
                original.actionId,
                rewind.actions[original.actionId].selectionCommitment
            );
        } else {
            f = rewind.statuses[hash];
            if (f.recoveryRecordHash != 0 && f.kind != kind) {
                revert W.InvalidRecoveryRewindRecord(hash);
            }
        }
    }

    function standing(
        Rewind.State storage rewind,
        Rotations.State storage rotations,
        Resolutions.State storage resolutions,
        bytes32 id,
        address account
    )
        public
        view
        returns (bytes32 retirement, bytes32 revocation, bytes32 judgment, bytes32 continuation)
    {
        retirement = rotations.retirement[id][account];
        revocation = rotations.standingRevocation[id][account];
        D.StandingJudgment memory original = resolutions.standingJudgments[id][account];
        // Include the full retained judgment even when a later retirement makes it inactive.
        // Restoring op51 never rewrites that independent historical judgment.
        judgment = keccak256(abi.encode(original));
        continuation = rewind.standingHeads[Rewind.standingScope(id, account, retirement)];
    }
}
