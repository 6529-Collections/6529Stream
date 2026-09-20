// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveryRewindSelectionState as Store
} from "./StreamArtistRecoveryRewindSelectionState.sol";
import {
    StreamArtistRecoveryRewindRecordReads as Records
} from "./StreamArtistRecoveryRewindRecordReads.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistGuardianSelectionTypes as S
} from "../../interfaces/stream/artist/StreamArtistGuardianSelectionTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamArtistNativeReceipts,
    StreamArtistHistoryTypes as N
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistGuardianHistory
} from "../../interfaces/stream/artist/IStreamArtistGuardianHistory.sol";
import {
    IStreamArtistRotationReads
} from "../../interfaces/stream/artist/IStreamArtistRotation.sol";
import {
    IStreamArtistIdentityOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import {
    IStreamArtistIdentityDismissalOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";
import {
    IStreamArtistIdentityRecoveryOwnerV3
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";
import {
    IStreamArtistRecoveryPayoutOwnerV3
} from "../../interfaces/stream/artist/IStreamArtistRecoveryPayoutOwnerV3.sol";

/// @notice Bounded original-journal visits and constant/bounded final selection.
/// @dev Predecessor fallback is accumulated during admission order, avoiding lifetime finish walks.
library StreamArtistRecoveryRewindSelectionScan {
    function identity(Store.State storage s, bytes32 key, uint256 index) public {
        W.EnvironmentV3 memory e = s.environments[key];
        bytes32 artistId = s.bases[key].identity.artistId;
        N.Receipt memory row =
            IStreamArtistNativeReceipts(e.identityOwner).artistNativeReceiptAt(index);
        bytes32 facts;
        if (row.artistId == artistId) {
            if (row.operation == 28) {
                facts = _guardian(s, key, index, row);
            } else if (row.operation == 58) {
                D.Record memory dismissal = IStreamArtistIdentityDismissalOwner(e.identityOwner)
                    .identityContestDismissalRecord(row.recordHash);
                if (
                    row.collectionId != 0 || row.recordHash == 0
                        || dismissal.recordHash != row.recordHash
                        || dismissal.terms.artistId != artistId
                ) {
                    revert W.InvalidRecoveryRewindSelection(key);
                }
                // This is the actual journal-derived original head; the leaf checks its canonical admission.
                s.originalRevisionContinuation[key] = dismissal.revisionContinuationHead;
                facts = keccak256(abi.encode(dismissal));
            } else {
                (bool relevant, W.RecordKind kind) = _identityKind(row.operation);
                if (relevant) {
                    Records.Facts memory f = kind == W.RecordKind.IDENTITY_REVISION
                        ? Records.readWithRevisionContinuation(
                            e, artistId, index, s.originalRevisionContinuation[key]
                        )
                        : Records.read(e, kind, artistId, index);
                    facts = _record(s, key, kind, f);
                }
            }
        }
        W.ProgressV3 storage p = s.progress[key];
        p.identityScanCommitment =
            _step(e, e.identityOwner, p.identityScanCommitment, index, row, facts);
        p.identityProcessed = index + 1;
    }

    function payout(Store.State storage s, bytes32 key, uint256 index) public {
        W.EnvironmentV3 memory e = s.environments[key];
        bytes32 artistId = s.bases[key].identity.artistId;
        N.Receipt memory row =
            IStreamArtistNativeReceipts(e.payoutOwner).artistNativeReceiptAt(index);
        bytes32 facts;
        if (row.artistId == artistId && row.operation == 18) {
            facts = _record(
                s,
                key,
                W.RecordKind.PAYOUT_DESIGNATION,
                Records.read(e, W.RecordKind.PAYOUT_DESIGNATION, artistId, index)
            );
        }
        W.ProgressV3 storage p = s.progress[key];
        p.payoutScanCommitment = _step(e, e.payoutOwner, p.payoutScanCommitment, index, row, facts);
        p.payoutProcessed = index + 1;
    }

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

    function _record(Store.State storage s, bytes32 key, W.RecordKind kind, Records.Facts memory f)
        private
        returns (bytes32 commitment)
    {
        bytes32 hash = f.selected.recordHash;
        if (
            hash == 0 || s.admitted[key][hash] || f.admissionRevision == 0
                || f.admissionRevision > s.bases[key].identity.identity.snapshot.revision
        ) {
            revert W.InvalidRecoveryRewindSelection(key);
        }
        W.StatusV3 memory status = _status(s, key, kind, hash);
        bool retained = _retained(s, key, kind, hash, status);
        s.admitted[key][hash] = true;
        s.kinds[key][hash] = kind;
        s.records[key][hash] = f;
        s.retained[key][hash] = retained;
        s.previouslySuperseded[key][hash] = status.recoveryRecordHash != 0;
        commitment = keccak256(abi.encode(kind, f, status, retained));
        s.familyCommitments[key][kind] =
            keccak256(abi.encode(s.familyCommitments[key][kind], commitment));
        if (kind == W.RecordKind.IDENTITY_REVISION || kind == W.RecordKind.PAYOUT_DESIGNATION) {
            _chain(s, key, kind, f, retained, commitment);
        } else if (kind == W.RecordKind.PRIOR_ADDRESS_STANDING_REVOCATION) {
            _standing(s, key, f, retained);
        } else if (retained && f.eligible) {
            if (kind == W.RecordKind.SUCCESSOR_DESIGNATION) {
                _winner(key, s.results[key].designation.operative, f.selected);
            } else if (kind == W.RecordKind.ESTATE_DIRECTIVE) {
                _winner(key, s.results[key].directive.operative, f.selected);
            } else {
                _winner(key, s.results[key].sanctionGrant.operative, f.selected);
            }
        }
    }

    function _guardian(
        Store.State storage s,
        bytes32 key,
        uint256 nativeIndex,
        N.Receipt memory row
    ) private returns (bytes32 commitment) {
        W.EnvironmentV3 memory e = s.environments[key];
        W.BasisV3 memory b = s.bases[key];
        uint64 index = s.progress[key].guardiansProcessed + 1;
        (GH.Head memory head, GH.Entry memory entry,,) = IStreamArtistGuardianHistory(
                e.identityOwner
            ).guardianHistoryState(b.identity.artistId, index, address(0), 0);
        if (
            row.collectionId != 0 || row.recordHash == 0 || s.admitted[key][row.recordHash]
                || keccak256(abi.encode(head)) != keccak256(abi.encode(b.identity.guardianHistory))
                || index > head.count || entry.artistId != b.identity.artistId
                || entry.index != index || entry.recordHash != row.recordHash
                || entry.previousCommitment != s.guardianTip[key]
                || entry.ownerRevision <= s.guardianRevision[key]
                || entry.ownerRevision > b.identity.identity.snapshot.revision
                || entry.commitment
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_GUARDIAN_ADMISSION_HISTORY_V1"),
                            e.chainId,
                            e.registry,
                            e.identityOwner,
                            entry.artistId,
                            entry.index,
                            entry.ownerRevision,
                            entry.recordHash,
                            entry.recordDataHash,
                            entry.previousCommitment
                        )
                    )
        ) revert W.InvalidRecoveryRewindSelection(key);
        R.GuardianRecord memory record =
            IStreamArtistRotationReads(e.identityOwner).guardianSetRecord(row.recordHash);
        Records.Facts memory f;
        if (record.provisional.transitionRecordHash != 0) {
            f.transition = IStreamArtistRotationReads(e.identityOwner)
                .artistTransitionState(record.provisional.transitionRecordHash);
        }
        if (
            record.recordHash != row.recordHash || record.terms.artistId != b.identity.artistId
                || entry.recordDataHash != keccak256(abi.encode(record))
                || (record.provisional.transitionRecordHash == 0
                        ? record.provisional.windowEndsAt != 0
                        : f.transition.recordHash != record.provisional.transitionRecordHash
                        || f.transition.artistId != b.identity.artistId
                        || f.transition.postWindowEndsAt != record.provisional.windowEndsAt)
        ) revert W.InvalidRecoveryRewindSelection(key);
        W.StatusV3 memory status = _status(s, key, W.RecordKind.GUARDIAN_SET, row.recordHash);
        bool retained = _retained(s, key, W.RecordKind.GUARDIAN_SET, row.recordHash, status);
        f.selected = W.SelectedRecordV3(
            row.recordHash,
            entry.recordDataHash,
            keccak256(abi.encode(entry, record, f.transition, status)),
            record.nonce,
            nativeIndex
        );
        f.association = record.provisional;
        f.admissionRevision = entry.ownerRevision;
        f.authorityClass = record.authorityClass;
        f.eligible =
            R.eligible(b.identity.artistId, record.provisional, f.transition, block.timestamp);
        s.admitted[key][row.recordHash] = true;
        s.kinds[key][row.recordHash] = W.RecordKind.GUARDIAN_SET;
        s.records[key][row.recordHash] = f;
        s.retained[key][row.recordHash] = retained;
        s.previouslySuperseded[key][row.recordHash] = status.recoveryRecordHash != 0;
        if (retained) {
            for (uint256 i; i < record.terms.guardians.length; ++i) {
                s.retainedMembers[key][record.terms.guardians[i]] = true;
            }
            S.Result storage winner = s.results[key].guardians;
            if (
                f.eligible
                    && (winner.selectedRecordHash == 0 || record.nonce > winner.selectedNonce)
            ) {
                winner.selectedRecordHash = row.recordHash;
                winner.selectedDataHash = entry.recordDataHash;
                winner.selectedNonce = record.nonce;
            } else if (
                f.eligible && winner.selectedRecordHash != 0 && record.nonce == winner.selectedNonce
            ) {
                revert W.InvalidRecoveryRewindSelection(key);
            }
        }
        s.guardianTip[key] = entry.commitment;
        s.guardianRevision[key] = entry.ownerRevision;
        s.progress[key].guardiansProcessed = index;
        commitment = keccak256(abi.encode(entry, f, status, retained));
    }

    function _status(Store.State storage s, bytes32 key, W.RecordKind kind, bytes32 hash)
        private
        view
        returns (W.StatusV3 memory status)
    {
        W.EnvironmentV3 memory e = s.environments[key];
        status = kind == W.RecordKind.PAYOUT_DESIGNATION
            ? IStreamArtistRecoveryPayoutOwnerV3(e.payoutOwner).payoutRecoveryRecordStatusV3(hash)
            : IStreamArtistIdentityRecoveryOwnerV3(e.identityOwner)
                .recoveryRecordStatusV3(kind, hash);
        if (status.recoveryRecordHash == 0) {
            W.StatusV3 memory empty;
            if (keccak256(abi.encode(status)) != keccak256(abi.encode(empty))) {
                revert W.InvalidRecoveryRewindSelection(key);
            }
        } else if (
            status.artistId != s.bases[key].identity.artistId || status.kind != kind
                || status.actionId == 0
                || (kind != W.RecordKind.GUARDIAN_SET && status.planCommitment == 0)
        ) {
            revert W.InvalidRecoveryRewindSelection(key);
        }
    }

    function _retained(
        Store.State storage s,
        bytes32 key,
        W.RecordKind kind,
        bytes32 hash,
        W.StatusV3 memory status
    ) private returns (bool) {
        uint8 excluded = s.excludedIndex[key][hash];
        if (excluded != 0) {
            uint256 bit = uint256(1) << (excluded - 1);
            if (
                s.excluded[key][excluded - 1].kind != kind || status.recoveryRecordHash != 0
                    || s.progress[key].seenExclusions & bit != 0
            ) {
                revert W.InvalidRecoveryRewindSelection(key);
            }
            s.progress[key].seenExclusions |= bit;
        }
        return excluded == 0 && status.recoveryRecordHash == 0;
    }

    function _chain(
        Store.State storage s,
        bytes32 key,
        W.RecordKind kind,
        Records.Facts memory f,
        bool retained,
        bytes32 facts
    ) private {
        bytes32 previous = f.previousRecordHash;
        if (previous != 0) {
            if (
                !s.admitted[key][previous] || s.kinds[key][previous] != kind
                    || s.records[key][previous].admissionRevision >= f.admissionRevision
            ) revert W.InvalidRecoveryRewindSelection(key);
            if (
                kind == W.RecordKind.IDENTITY_REVISION
                    && s.records[key][previous].valueHash != f.previousValueHash
            ) revert W.InvalidRecoveryRewindSelection(key);
        } else if (kind == W.RecordKind.IDENTITY_REVISION) {
            T.Identity memory original = IStreamArtistIdentityOwner(
                    s.environments[key].identityOwner
                ).identity(s.bases[key].identity.artistId);
            if (f.previousValueHash != original.identityRecordHash || f.previousValueHash == 0) {
                revert W.InvalidRecoveryRewindSelection(key);
            }
        }
        bytes32 hash = f.selected.recordHash;
        s.chainFallback[key][hash] = retained && f.eligible && f.abandonmentHash == 0
            ? hash
            : s.chainFallback[key][previous];
        s.branchCommitments[key][hash] =
            keccak256(abi.encode(s.branchCommitments[key][previous], facts));
    }

    function _standing(Store.State storage s, bytes32 key, Records.Facts memory f, bool retained)
        private
    {
        bytes32 scope = keccak256(abi.encode(f.account, f.retirementHash));
        if (
            f.account == address(0) || f.retirementHash == 0
                || f.admissionRevision <= s.standingRevisions[key][scope]
        ) revert W.InvalidRecoveryRewindSelection(key);
        s.standingRevisions[key][scope] = f.admissionRevision;
        if (retained) s.standingWinners[key][scope] = f.selected.recordHash;
        if (s.excludedIndex[key][f.selected.recordHash] != 0 && !s.standingScopeSeen[key][scope]) {
            s.standingScopeSeen[key][scope] = true;
            s.standingScopes[key].push(Store.StandingScope(f.account, f.retirementHash));
        }
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

    function _winner(
        bytes32 key,
        W.SelectedRecordV3 storage current,
        W.SelectedRecordV3 memory proposed
    ) private {
        if (current.recordHash != 0 && proposed.nonce == current.nonce) revert W.InvalidRecoveryRewindSelection(key);
        if (current.recordHash == 0 || proposed.nonce > current.nonce) {
            current.recordHash = proposed.recordHash;
            current.originalDataHash = proposed.originalDataHash;
            current.admissionProof = proposed.admissionProof;
            current.nonce = proposed.nonce;
            current.nativeIndex = proposed.nativeIndex;
        }
    }

    function _identityKind(uint16 operation) private pure returns (bool, W.RecordKind) {
        if (operation == 36) return (true, W.RecordKind.SUCCESSOR_DESIGNATION);
        if (operation == 37) return (true, W.RecordKind.ESTATE_DIRECTIVE);
        if (operation == 25) return (true, W.RecordKind.IDENTITY_REVISION);
        if (operation == 19) return (true, W.RecordKind.STEWARD_SANCTION_GRANT);
        if (operation == 51) return (true, W.RecordKind.PRIOR_ADDRESS_STANDING_REVOCATION);
        return (false, W.RecordKind.GUARDIAN_SET);
    }

    function _step(
        W.EnvironmentV3 memory e,
        address owner,
        bytes32 previous,
        uint256 index,
        N.Receipt memory row,
        bytes32 facts
    ) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_REWIND_RECEIPT_STEP_V3"),
                uint16(3),
                e,
                owner,
                previous,
                index,
                row,
                facts
            )
        );
    }
}
