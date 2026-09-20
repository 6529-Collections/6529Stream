// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveryRewindSelectionState as Store
} from "./StreamArtistRecoveryRewindSelectionState.sol";
import {
    StreamArtistRecoveryRewindSelectionFinish as Finish
} from "./StreamArtistRecoveryRewindSelectionFinish.sol";
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

import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";

/// @notice Bounded original-journal visits and constant/bounded final selection.
/// @dev Predecessor fallback is accumulated during admission order, avoiding lifetime finish walks.
library StreamArtistRecoveryRewindSelectionScan {
    function identity(Store.State storage s, bytes32 key, uint256 index) public {
        W.EnvironmentV3 memory e = s.environments[key];
        bytes32 artistId = s.bases[key].identity.artistId;
        N.Receipt memory row = _row(e, 2, index);
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
        N.Receipt memory row = _row(e, 5, index);
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
        Finish.finish(s, key);
    }

    function _record(Store.State storage s, bytes32 key, W.RecordKind kind, Records.Facts memory f)
        private
        returns (bytes32 commitment)
    {
        bytes32 hash = f.selected.recordHash;
        if (
            hash == 0 || s.admitted[key][hash] || f.admissionRevision == 0
                || (!Recovered.active(s.environments[key].identityOwner)
                    && f.admissionRevision > s.bases[key].identity.identity.snapshot.revision)
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
        bool imported = Recovered.active(e.identityOwner);
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
                || (!imported
                    && (entry.ownerRevision <= s.guardianRevision[key]
                        || entry.ownerRevision > b.identity.identity.snapshot.revision))
                || (!imported
                    && entry.commitment
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
                        ))
        ) revert W.InvalidRecoveryRewindSelection(key);
        R.GuardianRecord memory record =
            IStreamArtistRotationReads(e.identityOwner).guardianSetRecord(row.recordHash);
        if (imported) {
            Runtime.Context memory clock = Runtime.load(e, 2);
            Runtime.OriginFact memory origin = Recovered.guardian(clock, entry, record);
            Runtime.ReceiptFact memory occurrence = Runtime.receiptAt(clock, nativeIndex);
            if (!Recovered.samePoint(origin.point, occurrence.position.point)) {
                revert W.InvalidRecoveryRewindSelection(key);
            }
            if (index > 1) {
                (, GH.Entry memory previous,,) = IStreamArtistGuardianHistory(e.identityOwner)
                    .guardianHistoryState(b.identity.artistId, index - 1, address(0), 0);
                Runtime.OriginFact memory earlier = Recovered.guardianEntry(clock, previous);
                if (
                    previous.ownerRevision != s.guardianRevision[key]
                        || previous.commitment != s.guardianTip[key]
                        || !Runtime.before(clock, earlier.point, origin.point)
                ) {
                    revert W.InvalidRecoveryRewindSelection(key);
                }
            }
        }
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

    function _row(W.EnvironmentV3 memory e, uint8 ownerIndex, uint256 index)
        private
        view
        returns (N.Receipt memory)
    {
        address target = ownerIndex == 2 ? e.identityOwner : e.payoutOwner;
        if (!Recovered.active(target)) {
            return IStreamArtistNativeReceipts(target).artistNativeReceiptAt(index);
        }
        return Runtime.receiptAt(Runtime.load(e, ownerIndex), index).receipt;
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
