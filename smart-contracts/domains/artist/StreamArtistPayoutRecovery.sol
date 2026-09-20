// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistPayoutRecoveryState as S } from "./StreamArtistPayoutRecoveryState.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    IStreamArtistIdentityRecoveryOwnerV3
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";
import {
    IStreamArtistIdentityRecoveryOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamArtistRecoveryRewindEvidence
} from "../../interfaces/stream/artist/IStreamArtistRecoveryRewindEvidence.sol";
import {
    IStreamArtistRecoveryRewindSelection
} from "../../interfaces/stream/artist/IStreamArtistRecoveryRewindSelection.sol";
import {
    IStreamArtistNativeReceipts,
    StreamArtistHistoryTypes as History
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistGuardianVestingHistory
} from "../../interfaces/stream/artist/IStreamArtistGuardianVestingHistory.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    StreamArtistAuthorityCheckpoint as Checkpoint
} from "./StreamArtistAuthorityCheckpoint.sol";
import {
    StreamArtistIdentityRecoveryHashes as Hashes
} from "./StreamArtistIdentityRecoveryHashes.sol";

/// @notice Fixed Coordinator's Payout portion of one already-authenticated original35.
/// @dev Reads fixed cross-owner facts before mutation; no cross-owner mutation or synthetic native row.
library StreamArtistPayoutRecovery {
    struct Mutation {
        bytes32 action;
        bytes32 state;
        bytes32 replay;
        bytes32 commitment;
    }

    struct Checked {
        W.ResultV3 result;
        W.ResolutionManifestV3 manifest;
        W.EvidenceStateV3 evidence;
        W.PreparationSealV3 seal;
        uint64 identityRevision;
    }

    function inventory(
        S.State storage s,
        mapping(bytes32 => T.Payout) storage stable,
        mapping(bytes32 => T.Payout) storage candidate,
        bytes32 artistId
    ) public view returns (W.PayoutInventoryV3 memory) {
        return W.PayoutInventoryV3(
            stable[artistId],
            candidate[artistId],
            s.statusCommitments[artistId],
            s.continuationHeads[artistId]
        );
    }

    function applyRewind(
        S.State storage s,
        mapping(bytes32 => T.Payout) storage stable,
        mapping(bytes32 => T.Payout) storage candidate,
        mapping(bytes32 => T.PayoutDesignation) storage records,
        mapping(bytes32 => T.ReplayCell) storage replay,
        W.EnvironmentV3 memory e,
        T.ActionContext calldata context,
        W.PayoutApplyV3 calldata p
    ) public returns (Mutation memory m) {
        if (
            e.payoutOwner != address(this) || context.operationId != 35
                || msg.sender != e.coordinator || p.artistId == 0 || p.recoveryRecordHash == 0
                || p.supersededPayoutRecordHashes.length == 0
                || s.appliedRecoveries[p.recoveryRecordHash] != 0
                || keccak256(abi.encode(context.expected))
                    != keccak256(abi.encode(p.source.snapshot))
                || p.source.receiptCount
                    != IStreamArtistNativeReceipts(address(this)).artistNativeReceiptCount()
                || keccak256(abi.encode(inventory(s, stable, candidate, p.artistId)))
                    != keccak256(abi.encode(p.beforeInventory))
        ) revert W.InvalidRecoveryRewindRecord(p.recoveryRecordHash);
        Checked memory checked = _checked(e, context, p);
        _exclusions(s, records, p, checked.manifest);
        _selection(s, p, checked.result.payout);
        T.Payout memory selected = _payout(records, p.artistId, p.selected.operative.recordHash);
        T.Payout memory retained =
            _payout(records, p.artistId, p.selected.retainedCandidateRecordHash);
        W.PayoutContinuationV3 memory continuation;
        continuation.artistId = p.artistId;
        continuation.recoveryRecordHash = p.recoveryRecordHash;
        continuation.actionId = p.actionId;
        continuation.manifestHash = p.manifestHash;
        continuation.planCommitment = p.planCommitment;
        continuation.identityOwnerRevision = checked.identityRevision;
        continuation.stable = selected;
        continuation.candidate = retained;
        if (_listed(p, p.beforeInventory.candidate.recordHash)) {
            continuation.releasedChildRecordHash = p.beforeInventory.candidate.recordHash;
        } else if (_listed(p, p.beforeInventory.stable.recordHash)) {
            continuation.releasedChildRecordHash = p.beforeInventory.stable.recordHash;
        }
        continuation.previousContinuationHash = s.continuationHeads[p.artistId];
        continuation.payoutOwnerRevision = context.expected.revision + 1;
        continuation.continuationHash = W.payoutContinuationHash(e, continuation);
        if (s.continuations[continuation.continuationHash].continuationHash != 0) {
            revert T.InvalidRecord();
        }
        bytes32 statuses = s.statusCommitments[p.artistId];
        for (uint256 i; i < p.supersededPayoutRecordHashes.length; ++i) {
            bytes32 hash = p.supersededPayoutRecordHashes[i];
            W.StatusV3 memory status = W.StatusV3(
                p.artistId,
                W.RecordKind.PAYOUT_DESIGNATION,
                p.recoveryRecordHash,
                p.actionId,
                p.planCommitment
            );
            s.statuses[hash] = status;
            statuses = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_RECOVERY_PAYOUT_STATUS_V3"),
                    uint16(3),
                    e,
                    statuses,
                    hash,
                    status
                )
            );
        }
        stable[p.artistId] = selected;
        candidate[p.artistId] = retained;
        s.statusCommitments[p.artistId] = statuses;
        s.continuations[continuation.continuationHash] = continuation;
        s.continuationHeads[p.artistId] = continuation.continuationHash;
        bytes32 key = _key(
            e,
            keccak256("payout_lifecycle.replay.designation_chain"),
            keccak256(abi.encode(p.artistId))
        );
        T.ReplayCell memory prior = replay[key];
        bytes32 head = retained.recordHash == 0 ? selected.recordHash : retained.recordHash;
        replay[key] = T.ReplayCell(head, context.expected.revision + 1, 3, 1);
        Checkpoint.noteReplay(key, replay[key]);
        bytes32 recoveryKey =
            _key(e, keccak256("payout_lifecycle.replay.recovery_rewind"), p.recoveryRecordHash);
        if (replay[recoveryKey].status != 0) revert T.Replay(recoveryKey);
        replay[recoveryKey] = T.ReplayCell(p.planCommitment, context.expected.revision + 1, 1, 2);
        Checkpoint.noteReplay(recoveryKey, replay[recoveryKey]);
        m.action = keccak256(
            abi.encode(keccak256("6529STREAM_ARTIST_RECOVERY_PAYOUT_APPLY_V3"), uint16(3), e, p)
        );
        m.state = keccak256(abi.encode(selected, retained, statuses, continuation));
        m.replay = keccak256(abi.encode(key, prior, replay[key], recoveryKey, replay[recoveryKey]));
        m.commitment = keccak256(abi.encode(m.action, m.state, m.replay));
        s.appliedRecoveries[p.recoveryRecordHash] = m.commitment;
        m.state = keccak256(abi.encode(m.state, p.recoveryRecordHash, m.commitment));
    }

    /// @dev Only the first genuine18 from an unoccupied restored branch consumes this scope.
    /// A later original58 sibling retains its own proof and cannot reuse this consumed scope.
    function noteAdmission(
        S.State storage s,
        mapping(bytes32 => T.ReplayCell) storage replay,
        W.EnvironmentV3 memory e,
        uint64 ownerRevision,
        T.PayoutDesignation calldata p,
        bytes32 record
    ) public returns (bytes32 commitment) {
        bytes32 hash = s.continuationHeads[p.artistId];
        if (hash == 0) return 0;
        W.PayoutContinuationV3 memory c = s.continuations[hash];
        if (
            c.continuationHash != hash || c.artistId != p.artistId
                || c.payoutOwnerRevision > ownerRevision || W.payoutContinuationHash(e, c) != hash
        ) revert W.InvalidRecoveryRewindRecord(record);
        if (c.candidate.recordHash != 0 || c.stable.recordHash != p.previousDesignationRecordHash) {
            return 0;
        }
        bytes32 key = _key(
            e,
            keccak256("payout_lifecycle.replay.recovery_continuation"),
            keccak256(abi.encode(p.artistId, hash, p.previousDesignationRecordHash))
        );
        if (replay[key].status != 0) return 0;
        if (s.recordContinuations[record] != 0) revert T.InvalidRecord();
        replay[key] = T.ReplayCell(record, ownerRevision + 1, 1, 2);
        Checkpoint.noteReplay(key, replay[key]);
        s.recordContinuations[record] = hash;
        commitment = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_PAYOUT_ADMISSION_V3"),
                uint16(3),
                e,
                record,
                hash,
                key,
                replay[key]
            )
        );
    }

    function _checked(
        W.EnvironmentV3 memory e,
        T.ActionContext calldata context,
        W.PayoutApplyV3 calldata p
    ) private view returns (Checked memory x) {
        IStreamArtistIdentityRecoveryOwnerV3 owner =
            IStreamArtistIdentityRecoveryOwnerV3(e.identityOwner);
        (address evidence, bytes32 evidenceCode) = owner.recoveryRewindEvidenceBinding();
        (address selection, bytes32 selectionCode) = owner.recoveryRewindSelectionBinding();
        if (
            evidenceCode == 0 || evidence.codehash != evidenceCode || selectionCode == 0
                || selection.codehash != selectionCode
        ) revert W.RecoveryRewindDependencyChanged(e.identityOwner);
        bytes32 identityCode;
        bytes32 payoutCode;
        (x.manifest, identityCode, payoutCode) =
            IStreamArtistRecoveryRewindEvidence(evidence).resolutionManifestV3(p.manifestHash);
        x.evidence = owner.identityRecoveryEvidenceStateV3(p.artistId, p.actionId);
        IStreamArtistRecoveryRewindSelection worker =
            IStreamArtistRecoveryRewindSelection(selection);
        x.result = worker.selectionResultV3(x.evidence.sourceKey);
        x.seal = worker.preparationSealV3(x.evidence.sourceKey);
        (W.BasisV3 memory basis, W.ProgressV3 memory progress) =
            worker.selectionV3(x.evidence.sourceKey);
        if (
            identityCode != e.identityCodeHash || payoutCode != e.payoutCodeHash
                || W.manifestHash(e, x.manifest) != p.manifestHash
                || x.manifest.artistId != p.artistId || x.evidence.manifestHash != p.manifestHash
                || x.evidence.associationHash != p.associationHash || p.associationHash == 0
                || x.evidence.selectionCommitment != p.planCommitment
                || x.result.commitment != p.planCommitment || p.planCommitment == 0
                || x.result.sourceKey != x.evidence.sourceKey
                || x.result.manifestHash != p.manifestHash || !progress.complete
                || progress.resultCommitment != p.planCommitment || x.seal.commitment == 0
                || x.seal.sourceKey != x.result.sourceKey || x.seal.actionId != p.actionId
                || x.seal.associationHash != p.associationHash
                || x.seal.manifestHash != p.manifestHash
                || x.seal.evidenceStateHash != keccak256(abi.encode(x.evidence))
                || keccak256(abi.encode(p.selected)) != keccak256(abi.encode(x.result.payout))
                || keccak256(abi.encode(p.beforeInventory))
                    != keccak256(abi.encode(basis.payoutInventory))
                || keccak256(abi.encode(p.source)) != keccak256(abi.encode(x.manifest.payout))
                || keccak256(abi.encode(p.source)) != keccak256(abi.encode(basis.payout))
                || keccak256(abi.encode(p.source))
                    != keccak256(abi.encode(x.evidence.sources.payout))
                || keccak256(abi.encode(p.source)) != keccak256(abi.encode(x.seal.payout))
        ) {
            revert W.InvalidRecoveryRewindRecord(p.recoveryRecordHash);
        }
        x.identityRevision = _recovery(e, context, p, x);
    }

    function _recovery(
        W.EnvironmentV3 memory e,
        T.ActionContext calldata context,
        W.PayoutApplyV3 calldata p,
        Checked memory x
    ) private view returns (uint64 revision) {
        IStreamArtistIdentityRecoveryOwner owner =
            IStreamArtistIdentityRecoveryOwner(e.identityOwner);
        Recovery.Record memory r = owner.identityRecoveryRecord(p.recoveryRecordHash);
        T.Snapshot memory now_ = IStreamArtistOwner(e.identityOwner).ownerStateSnapshotV2();
        V.Snapshot memory vesting = IStreamArtistGuardianVestingHistory(e.identityOwner)
            .guardianVestingSnapshot(p.artistId, p.recoveryRecordHash);
        if (
            r.recordHash != p.recoveryRecordHash || r.fields.artistId != p.artistId
                || r.fields.governanceActionId != p.actionId || r.executor != context.actor
                || r.contextHash != p.contextHash
                || r.terms.expectedCauseHash != x.manifest.causeHash
                || r.terms.expectedResolutionHash != x.manifest.resolutionHash
                || W.requestCommitment(r.terms) != x.manifest.requestCommitment
                || Hashes.record(e.chainId, e.registry, r.fields) != p.recoveryRecordHash
                || owner.latestIdentityRecovery(p.artistId) != p.recoveryRecordHash
                || now_.revision != x.seal.identityAfterPreparation.revision + 1
                || vesting.ownerRevision != now_.revision || vesting.operationId != 35
                || vesting.transitionRecordHash != p.recoveryRecordHash
                || vesting.artistId != p.artistId
                || r.terms.supersededRecordHashes.length != x.manifest.supersededRecords.length
        ) {
            revert W.InvalidRecoveryRewindRecord(p.recoveryRecordHash);
        }
        for (uint256 i; i < r.terms.supersededRecordHashes.length; ++i) {
            if (r.terms.supersededRecordHashes[i] != x.manifest.supersededRecords[i].recordHash) {
                revert W.InvalidRecoveryRewindRecord(p.recoveryRecordHash);
            }
        }
        uint256 count = IStreamArtistNativeReceipts(e.identityOwner).artistNativeReceiptCount();
        if (count < 2) revert W.InvalidRecoveryRewindRecord(p.recoveryRecordHash);
        History.Receipt memory first =
            IStreamArtistNativeReceipts(e.identityOwner).artistNativeReceiptAt(count - 2);
        History.Receipt memory second =
            IStreamArtistNativeReceipts(e.identityOwner).artistNativeReceiptAt(count - 1);
        if (
            first.operation != 35 || second.operation != 35 || first.artistId != p.artistId
                || second.artistId != p.artistId || first.collectionId != 0
                || second.collectionId != 0 || first.recordHash != p.recoveryRecordHash
                || second.recordHash != r.fields.supersededRecordsHash
        ) {
            revert W.InvalidRecoveryRewindRecord(p.recoveryRecordHash);
        }
        (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
            owner.identityRecoveryReceipts(p.recoveryRecordHash);
        if (primary == 0 || occurrence == 0 || secondary == 0 || primary == secondary) {
            revert W.InvalidRecoveryRewindRecord(p.recoveryRecordHash);
        }
        return now_.revision;
    }

    function _exclusions(
        S.State storage s,
        mapping(bytes32 => T.PayoutDesignation) storage records,
        W.PayoutApplyV3 calldata p,
        W.ResolutionManifestV3 memory manifest
    ) private view {
        uint256 index;
        bytes32 previous;
        for (uint256 i; i < manifest.supersededRecords.length; ++i) {
            W.RecordReference memory ref = manifest.supersededRecords[i];
            if (ref.kind != W.RecordKind.PAYOUT_DESIGNATION) continue;
            if (
                index >= p.supersededPayoutRecordHashes.length || ref.recordHash <= previous
                    || p.supersededPayoutRecordHashes[index++] != ref.recordHash
                    || records[ref.recordHash].artistId != p.artistId
                    || records[ref.recordHash].payoutAccount == address(0)
                    || s.statuses[ref.recordHash].recoveryRecordHash != 0
            ) {
                revert W.InvalidRecoveryRewindRecord(ref.recordHash);
            }
            previous = ref.recordHash;
        }
        if (index != p.supersededPayoutRecordHashes.length) {
            revert W.InvalidRecoveryRewindRecord(p.recoveryRecordHash);
        }
    }

    function _selection(
        S.State storage s,
        W.PayoutApplyV3 calldata p,
        W.FamilySelectionV3 memory selected
    ) private view {
        bytes32 target = selected.operative.recordHash;
        bytes32 retained = selected.retainedCandidateRecordHash;
        if (
            (target != 0 && (s.statuses[target].recoveryRecordHash != 0 || _listed(p, target)))
                || (retained != 0
                    && (retained != p.beforeInventory.candidate.recordHash
                        || retained == target
                        || s.statuses[retained].recoveryRecordHash != 0
                        || _listed(p, retained)))
        ) {
            revert W.InvalidRecoveryRewindRecord(target);
        }
        if (target == 0) {
            W.SelectedRecordV3 memory empty;
            if (keccak256(abi.encode(selected.operative)) != keccak256(abi.encode(empty))) {
                revert W.InvalidRecoveryRewindRecord(target);
            }
        } else {
            if (selected.operative.nativeIndex >= p.source.receiptCount) {
                revert W.InvalidRecoveryRewindRecord(target);
            }
            History.Receipt memory row = IStreamArtistNativeReceipts(address(this))
                .artistNativeReceiptAt(selected.operative.nativeIndex);
            if (
                row.operation != 18 || row.artistId != p.artistId || row.collectionId != 0
                    || row.recordHash != target || selected.operative.originalDataHash == 0
                    || selected.operative.admissionProof == 0
            ) {
                revert W.InvalidRecoveryRewindRecord(target);
            }
        }
        // _checked authenticates the fixed worker's completed result and exact captured
        // inventory. Its branch commitment already covers the original predecessor walk;
        // final atomic apply must not traverse a lifetime-sized chain a second time.
    }

    function _payout(
        mapping(bytes32 => T.PayoutDesignation) storage records,
        bytes32 artistId,
        bytes32 hash
    ) private view returns (T.Payout memory p) {
        if (hash == 0) return p;
        T.PayoutDesignation storage original = records[hash];
        if (original.artistId != artistId || original.payoutAccount == address(0)) {
            revert W.InvalidRecoveryRewindRecord(hash);
        }
        return T.Payout(original.payoutAccount, hash);
    }

    function _listed(W.PayoutApplyV3 calldata p, bytes32 hash) private pure returns (bool) {
        if (hash == 0) return false;
        for (uint256 i; i < p.supersededPayoutRecordHashes.length; ++i) {
            if (p.supersededPayoutRecordHashes[i] == hash) return true;
        }
        return false;
    }

    function _key(W.EnvironmentV3 memory e, bytes32 surface, bytes32 scope)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                e.chainId,
                e.registry,
                e.coordinator,
                e.archive,
                e.payoutOwner,
                keccak256("domain:payout_lifecycle"),
                surface,
                scope
            )
        );
    }
}
