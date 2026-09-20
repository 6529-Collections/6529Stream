// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveryRewindSelectionState as Store
} from "./StreamArtistRecoveryRewindSelectionState.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    IStreamArtistIdentityRecoveryOwnerV3
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";

/// @notice Fixed final selection over the original host's explicit scan state.
/// @dev Owns no state; preserves the original finalization checks and write order.
library StreamArtistRecoveryRewindSelectionFinish {
    function finish(Store.State storage s, bytes32 key) public {
        W.BasisV3 memory b = s.bases[key];
        W.ProgressV3 storage p = s.progress[key];
        if (
            p.identityProcessed != b.identity.identity.receiptCount
                || p.payoutProcessed != b.payout.receiptCount
                || p.guardiansProcessed != b.identity.guardianHistory.count
                || s.guardianTip[key] != b.identity.guardianHistory.commitment
                || s.guardianRevision[key] != b.identity.guardianHistory.ownerRevision
                || p.seenExclusions != (uint256(1) << s.excluded[key].length) - 1
        ) revert W.InvalidRecoveryRewindSelection(key);
        W.ResultV3 storage result = s.results[key];
        result.sourceKey = key;
        result.manifestHash = b.identity.manifestHash;
        result.sourceCommitment = b.sourceCommitment;
        result.inventoryCommitment =
            W.selectionInventoryHash(s.environments[key], b.identity.inventory, b.payoutInventory);
        _nonceResult(
            s,
            key,
            W.RecordKind.SUCCESSOR_DESIGNATION,
            b.identity.inventory.designations,
            result.designation
        );
        _nonceResult(
            s, key, W.RecordKind.ESTATE_DIRECTIVE, b.identity.inventory.directives, result.directive
        );
        _nonceResult(
            s,
            key,
            W.RecordKind.STEWARD_SANCTION_GRANT,
            b.identity.inventory.sanctionGrants,
            result.sanctionGrant
        );
        _chainResult(
            s,
            key,
            W.RecordKind.IDENTITY_REVISION,
            b.identity.inventory.revisions,
            result.identityRevision
        );
        _chainResult(
            s,
            key,
            W.RecordKind.PAYOUT_DESIGNATION,
            W.FamilyPointers(
                b.payoutInventory.stable.recordHash, b.payoutInventory.candidate.recordHash
            ),
            result.payout
        );
        _payoutPointers(s, key, b.payoutInventory);
        _sourcePointer(s, key, W.RecordKind.GUARDIAN_SET, b.identity.inventory.guardians.stable);
        _sourcePointer(s, key, W.RecordKind.GUARDIAN_SET, b.identity.inventory.guardians.candidate);
        _paired(s, key, result.designation.operative.recordHash);
        // Retaining an ineligible candidate also retains its original dependency. It may
        // mature later, so an excluded paired directive cannot be hidden behind that candidate.
        _paired(s, key, result.designation.retainedCandidateRecordHash);
        _standingResult(s, key);
        result.guardians.sourceKey = key;
        result.guardians.commitment = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_REWIND_GUARDIAN_RESULT_V3"),
                uint16(3),
                s.environments[key],
                b.identity.guardianHistory,
                key,
                result.guardians.selectedRecordHash,
                result.guardians.selectedDataHash,
                result.guardians.selectedNonce
            )
        );
        // The empty case still requires this explicit successful finalization write.
        result.commitment = W.selectionResultHash(s.environments[key], result);
        p.resultCommitment = result.commitment;
        p.complete = true;
    }

    function _nonceResult(
        Store.State storage s,
        bytes32 key,
        W.RecordKind kind,
        W.FamilyPointers memory pointers,
        W.FamilySelectionV3 storage result
    ) private {
        _sourcePointer(s, key, kind, pointers.stable);
        _sourcePointer(s, key, kind, pointers.candidate);
        if (
            pointers.candidate != 0 && s.retained[key][pointers.candidate]
                && !s.records[key][pointers.candidate].eligible
        ) {
            result.retainedCandidateRecordHash = pointers.candidate;
        }
        result.branchCommitment = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_REWIND_FAMILY_V3"),
                key,
                kind,
                pointers,
                s.familyCommitments[key][kind],
                result.operative,
                result.retainedCandidateRecordHash
            )
        );
    }

    function _chainResult(
        Store.State storage s,
        bytes32 key,
        W.RecordKind kind,
        W.FamilyPointers memory pointers,
        W.FamilySelectionV3 storage result
    ) private {
        _sourcePointer(s, key, kind, pointers.stable);
        _sourcePointer(s, key, kind, pointers.candidate);
        bytes32 tip = pointers.candidate != 0 ? pointers.candidate : pointers.stable;
        bytes32 selected = s.chainFallback[key][tip];
        if (selected != 0) result.operative = s.records[key][selected].selected;
        if (
            pointers.candidate != 0 && s.retained[key][pointers.candidate]
                && !s.records[key][pointers.candidate].eligible
        ) {
            result.retainedCandidateRecordHash = pointers.candidate;
        }
        result.branchCommitment = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_REWIND_BRANCH_V3"),
                key,
                kind,
                pointers,
                s.familyCommitments[key][kind],
                s.branchCommitments[key][tip],
                result.operative,
                result.retainedCandidateRecordHash
            )
        );
    }

    function _sourcePointer(Store.State storage s, bytes32 key, W.RecordKind kind, bytes32 hash)
        private
        view
    {
        if (
            hash != 0
                && (!s.admitted[key][hash]
                    || s.kinds[key][hash] != kind
                    || s.previouslySuperseded[key][hash])
        ) revert W.InvalidRecoveryRewindSelection(key);
    }

    function _payoutPointers(Store.State storage s, bytes32 key, W.PayoutInventoryV3 memory p)
        private
        view
    {
        if (p.stable.recordHash == 0
                ? p.stable.account != address(0)
                : s.records[key][p.stable.recordHash].account != p.stable.account) revert W.InvalidRecoveryRewindSelection(key);
        if (p.candidate.recordHash == 0
                ? p.candidate.account != address(0)
                : s.records[key][p.candidate.recordHash].account != p.candidate.account) revert W.InvalidRecoveryRewindSelection(key);
    }

    function _paired(Store.State storage s, bytes32 key, bytes32 designation) private view {
        if (designation == 0) return;
        bytes32 paired = s.records[key][designation].pairedDirective;
        if (
            paired != 0
                && (!s.admitted[key][paired]
                    || s.kinds[key][paired] != W.RecordKind.ESTATE_DIRECTIVE
                    || !s.retained[key][paired])
        ) {
            revert W.InvalidRecoveryRewindSelection(key);
        }
        // Class3 eligibility is a stronger context rule; class1 preserves originally admitted pairs.
    }

    function _standingResult(Store.State storage s, bytes32 key) private {
        Store.StandingScope[] memory scopes = s.standingScopes[key];
        for (uint256 i = 1; i < scopes.length; ++i) {
            Store.StandingScope memory item = scopes[i];
            uint256 j = i;
            while (
                j > 0
                    && (scopes[j - 1].account > item.account
                        || (scopes[j - 1].account == item.account
                            && scopes[j - 1].retirement > item.retirement))
            ) {
                scopes[j] = scopes[j - 1];
                --j;
            }
            scopes[j] = item;
        }
        for (uint256 i; i < scopes.length; ++i) {
            Store.StandingScope memory scope = scopes[i];
            (bytes32 current, bytes32 raw, bytes32 judgment, bytes32 continuation) = IStreamArtistIdentityRecoveryOwnerV3(
                    s.environments[key].identityOwner
                ).recoveryStandingScopeV3(s.bases[key].identity.artistId, scope.account);
            bytes32 selected =
                s.standingWinners[key][keccak256(abi.encode(scope.account, scope.retirement))];
            W.SelectedRecordV3 memory retained;
            if (selected != 0) retained = s.records[key][selected].selected;
            // A historical scope binds the raw pointer but must not replace the current retirement.
            s.results[key].standing
                .push(
                    W.StandingSelectionV3(
                        scope.account,
                        scope.retirement,
                        raw,
                        retained,
                        judgment,
                        current == scope.retirement ? continuation : bytes32(0)
                    )
                );
        }
    }
}
