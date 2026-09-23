// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";

import {
    IStreamArtistRotationReads
} from "../../interfaces/stream/artist/IStreamArtistRotation.sol";
import {
    IStreamArtistGuardianHistory
} from "../../interfaces/stream/artist/IStreamArtistGuardianHistory.sol";

import {
    IStreamArtistGuardianVestingHistory
} from "../../interfaces/stream/artist/IStreamArtistGuardianVestingHistory.sol";

import {
    IStreamArtistIdentityRecoveryOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamArtistIdentityRecoveryOwnerV2
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecoveryV2.sol";
import {
    IStreamArtistIdentityRecoveryOwnerV3
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";
import {
    IStreamArtistRecoveryActionOwner
} from "../../interfaces/stream/artist/IStreamArtistRecoveryAction.sol";

import {
    IStreamArtistGuardianSelectionOwner
} from "../../interfaces/stream/artist/IStreamArtistGuardianSelectionPreparation.sol";
import {
    StreamArtistGuardianSelectionTypes as Selection
} from "../../interfaces/stream/artist/StreamArtistGuardianSelectionTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";

import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistRecoveryActionTypes as A
} from "../../interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";

/// @notice Original complete Identity recovery getter comparisons.
library StreamArtistRecoveredIdentityRecordRecovery {
    function validate(address owner, IH.Bundle calldata b) public view {
        for (uint256 i; i < b.recoveries.length; ++i) {
            IH.RecoveryRow calldata r = b.recoveries[i];
            if (r.record.fields.artistId != b.artistId) {
                revert IH.InvalidRecoveredIdentity(r.record.recordHash);
            }
            _same(
                abi.encode(r.record),
                abi.encode(
                    IStreamArtistIdentityRecoveryOwner(owner)
                        .identityRecoveryRecord(r.record.recordHash)
                ),
                r.record.recordHash
            );
            _same(
                abi.encode(r.transition),
                abi.encode(
                    IStreamArtistRotationReads(owner).artistTransitionState(r.record.recordHash)
                ),
                r.record.recordHash
            );
            (bytes32 primary, bytes32 occurrence, bytes32 secondary) = IStreamArtistIdentityRecoveryOwner(
                    owner
                ).identityRecoveryReceipts(r.record.recordHash);
            _same(
                abi.encode(r.primaryReceipt, r.secondaryOccurrence, r.secondaryReceipt),
                abi.encode(primary, occurrence, secondary),
                r.record.recordHash
            );
            (, bytes32 guardian,) = IStreamArtistIdentityRecoveryOwner(owner)
                .recoveryTransitionStanding(r.record.recordHash);
            if (guardian != r.guardian) revert IH.InvalidRecoveredIdentity(r.record.recordHash);
        }
        for (uint256 i; i < b.vestings.length; ++i) {
            IH.VestingRow calldata r = b.vestings[i];
            _same(
                abi.encode(r.snapshot),
                abi.encode(
                    IStreamArtistGuardianVestingHistory(owner)
                        .guardianVestingSnapshot(b.artistId, r.snapshot.transitionRecordHash)
                ),
                r.snapshot.transitionRecordHash
            );
        }
        for (uint256 i; i < b.actions.length; ++i) {
            IH.ActionRow calldata r = b.actions[i];
            bytes32 action = r.association.action.actionId;
            if (action == 0 || r.association.artistId != b.artistId) {
                revert IH.InvalidRecoveredIdentity(action);
            }
            (
                A.Association memory association,
                A.Veto memory veto,
                bytes32 execution,
                uint64 count
            ) = IStreamArtistRecoveryActionOwner(owner)
                .identityRecoveryActionState(b.artistId, action);
            _same(
                abi.encode(r.association, r.veto, r.execution),
                abi.encode(association, veto, execution),
                action
            );
            (Selection.Result memory election, R.GuardianRecord memory restored) =
                IStreamArtistGuardianSelectionOwner(owner).guardianRecoverySelection(action);
            _same(
                abi.encode(r.election, r.restoredGuardian), abi.encode(election, restored), action
            );
            if (count != b.heads.guardianRecordsSeen) revert IH.InvalidRecoveredIdentity(action);
            (,, GH.Snapshot memory frozen,) = IStreamArtistGuardianHistory(owner)
                .guardianHistoryState(b.artistId, 0, address(0), action);
            _same(abi.encode(r.guardianSnapshot), abi.encode(frozen), action);
            _same(
                abi.encode(r.evidenceV2),
                abi.encode(
                    IStreamArtistIdentityRecoveryOwnerV2(owner)
                        .identityRecoveryEvidenceState(b.artistId, action)
                ),
                action
            );
            _same(
                abi.encode(r.evidenceV3),
                abi.encode(
                    IStreamArtistIdentityRecoveryOwnerV3(owner)
                        .identityRecoveryEvidenceStateV3(b.artistId, action)
                ),
                action
            );
        }
    }

    function _same(bytes memory a, bytes memory b, bytes32 key) private pure {
        if (keccak256(a) != keccak256(b)) revert IH.InvalidRecoveredIdentity(key);
    }
}
