// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistDormancyVestingReads } from "./StreamArtistDormancyVestingReads.sol";
import {
    StreamArtistGuardianSelectionTypes as S
} from "../../interfaces/stream/artist/StreamArtistGuardianSelectionTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as H
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    IStreamArtistGuardianHistory
} from "../../interfaces/stream/artist/IStreamArtistGuardianHistory.sol";
import {
    IStreamArtistRotationReads
} from "../../interfaces/stream/artist/IStreamArtistRotation.sol";
import {
    IStreamArtistGuardianSupersession
} from "../../interfaces/stream/artist/IStreamArtistGuardianSupersession.sol";
import {
    StreamArtistGuardianSupersessionTypes as Supersession
} from "../../interfaces/stream/artist/StreamArtistGuardianSupersessionTypes.sol";
import {
    IStreamArtistIdentityRecoveryOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";

import {
    IStreamArtistEstateOwner
} from "../../interfaces/stream/artist/IStreamArtistEstateOwner.sol";
import {
    IStreamArtistIdentityDismissalOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";
import {
    StreamArtistEstateTypes as Estate
} from "../../interfaces/stream/artist/StreamArtistEstateTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";

import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";

/// @notice Permissionless, bounded computation; only Identity can admit the resulting election.
/// @dev No scheduled action, guardian authority or owner revision is created by this helper.
contract StreamArtistGuardianSelectionPreparation {
    address public immutable owner;
    address public immutable artistRegistry;
    uint256 public immutable deploymentChainId;
    mapping(bytes32 => S.Basis) private _bases;
    mapping(bytes32 => S.Progress) private _progress;
    mapping(bytes32 => bytes32[]) private _excluded;
    mapping(bytes32 => mapping(bytes32 => uint8)) private _excludedIndex;

    event GuardianSelectionPrepared(bytes32 indexed key, bytes32 indexed artistId, uint64 count);
    event GuardianSelectionProgress(bytes32 indexed key, uint64 processed, bool complete);

    constructor(address owner_, address registry_) {
        // The fixed Identity owner is still under construction when its third child creates us.
        if (owner_ == address(0) || registry_ == address(0) || owner_ == registry_) {
            revert S.InvalidGuardianSelection(bytes32(0));
        }
        owner = owner_;
        artistRegistry = registry_;
        deploymentChainId = block.chainid;
    }

    function begin(bytes32 artistId, bytes32 transition, bytes32[] calldata excluded)
        external
        returns (bytes32 key)
    {
        _shape(excluded);
        (H.Head memory head,,,) = IStreamArtistGuardianHistory(owner)
            .guardianHistoryState(artistId, 0, address(0), bytes32(0));
        R.TransitionState memory state =
            IStreamArtistRotationReads(owner).artistTransitionState(transition);
        S.Basis memory basis =
            S.Basis(artistId, owner.codehash, head, state, keccak256(abi.encode(excluded)));
        _requireBasis(basis);
        key = _key(basis);
        if (_bases[key].artistId != bytes32(0)) return key;
        _bases[key] = basis;
        _excluded[key] = excluded;
        for (uint256 i; i < excluded.length; ++i) {
            _excludedIndex[key][excluded[i]] = uint8(i + 1);
        }
        emit GuardianSelectionPrepared(key, artistId, head.count);
    }

    function continueSelection(bytes32 key, uint64 maximumRecords)
        external
        returns (S.Progress memory progress)
    {
        S.Basis memory basis = _bases[key];
        if (basis.artistId == bytes32(0) || maximumRecords == 0 || _key(basis) != key) {
            revert S.InvalidGuardianSelection(key);
        }
        _requireBasis(basis);
        progress = _progress[key];
        if (progress.complete) return progress;
        uint256 end = uint256(progress.processed) + maximumRecords;
        if (end > basis.history.count) end = basis.history.count;
        for (uint256 index = uint256(progress.processed) + 1; index <= end; ++index) {
            _visit(key, basis, progress, uint64(index));
        }
        if (progress.processed == basis.history.count) {
            uint64 allExcluded = uint64((uint256(1) << _excluded[key].length) - 1);
            if (
                progress.historyTip != basis.history.commitment
                    || progress.lastOwnerRevision != basis.history.ownerRevision
                    || progress.excludedSeen != allExcluded
            ) revert S.InvalidGuardianSelection(key);
            progress.complete = true;
        }
        _progress[key] = progress;
        emit GuardianSelectionProgress(key, progress.processed, progress.complete);
    }

    function selection(bytes32 key) external view returns (S.Basis memory, S.Progress memory) {
        return (_bases[key], _progress[key]);
    }

    function requireSelection(
        bytes32 artistId,
        H.Head calldata history,
        R.TransitionState calldata transition,
        bytes32[] calldata excluded
    ) external view returns (S.Result memory result) {
        _shape(excluded);
        S.Basis memory basis = S.Basis(
            artistId, owner.codehash, history, transition, keccak256(abi.encode(excluded))
        );
        _requireBasis(basis);
        result.sourceKey = _key(basis);
        S.Progress memory p = _progress[result.sourceKey];
        if (!p.complete || p.processed != history.count) {
            revert S.IncompleteGuardianSelection(result.sourceKey, p.processed, history.count);
        }
        if (keccak256(abi.encode(_bases[result.sourceKey])) != keccak256(abi.encode(basis))) {
            revert S.InvalidGuardianSelection(result.sourceKey);
        }
        result.selectedRecordHash = p.selectedRecordHash;
        result.selectedDataHash = p.selectedDataHash;
        result.selectedNonce = p.selectedNonce;
        result.commitment = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_GUARDIAN_SELECTION_RESULT_V1"),
                result.sourceKey,
                basis,
                p
            )
        );
    }

    function _visit(bytes32 key, S.Basis memory basis, S.Progress memory p, uint64 index)
        private
        view
    {
        (H.Head memory current, H.Entry memory entry,,) = IStreamArtistGuardianHistory(owner)
            .guardianHistoryState(basis.artistId, index, address(0), bytes32(0));
        if (
            keccak256(abi.encode(current)) != keccak256(abi.encode(basis.history))
                || entry.artistId != basis.artistId || entry.index != index
                || entry.recordHash == bytes32(0) || entry.previousCommitment != p.historyTip
                || entry.ownerRevision <= p.lastOwnerRevision
                || entry.ownerRevision > basis.history.ownerRevision
                || entry.commitment
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_GUARDIAN_ADMISSION_HISTORY_V1"),
                            deploymentChainId,
                            artistRegistry,
                            owner,
                            entry.artistId,
                            entry.index,
                            entry.ownerRevision,
                            entry.recordHash,
                            entry.recordDataHash,
                            entry.previousCommitment
                        )
                    )
        ) revert S.InvalidGuardianSelection(key);
        R.GuardianRecord memory record =
            IStreamArtistRotationReads(owner).guardianSetRecord(entry.recordHash);
        R.TransitionState memory associated;
        if (record.provisional.transitionRecordHash != 0) {
            associated = IStreamArtistRotationReads(owner)
                .artistTransitionState(record.provisional.transitionRecordHash);
        }
        if (
            record.recordHash != entry.recordHash || record.terms.artistId != basis.artistId
                || entry.recordDataHash != keccak256(abi.encode(record))
                || (record.provisional.transitionRecordHash == 0
                        ? record.provisional.windowEndsAt != 0
                        : associated.recordHash != record.provisional.transitionRecordHash
                        || associated.artistId != basis.artistId
                        || record.provisional.windowEndsAt != associated.postWindowEndsAt)
        ) {
            revert S.InvalidGuardianSelection(key);
        }
        Supersession.Status memory status =
            IStreamArtistGuardianSupersession(owner).guardianRecordSupersession(record.recordHash);
        if (status.recoveryRecordHash == bytes32(0)) {
            if (status.artistId != bytes32(0) || status.actionId != bytes32(0)) {
                revert S.InvalidGuardianSelection(key);
            }
        } else if (status.artistId != basis.artistId || status.actionId == bytes32(0)) {
            revert S.InvalidGuardianSelection(key);
        }
        uint8 excludedIndex = _excludedIndex[key][record.recordHash];
        if (excludedIndex != 0) p.excludedSeen |= uint64(1) << (excludedIndex - 1);
        if (
            excludedIndex == 0 && status.recoveryRecordHash == bytes32(0)
                && R.eligible(basis.artistId, record.provisional, associated, block.timestamp)
                && (p.selectedRecordHash == bytes32(0) || record.nonce > p.selectedNonce)
        ) {
            p.selectedRecordHash = record.recordHash;
            p.selectedDataHash = entry.recordDataHash;
            p.selectedNonce = record.nonce;
        }
        p.processed = index;
        p.lastOwnerRevision = entry.ownerRevision;
        p.historyTip = entry.commitment;
    }

    function _requireBasis(S.Basis memory basis) private view {
        if (
            block.chainid != deploymentChainId || owner.code.length == 0
                || owner.codehash != basis.ownerCodeHash || basis.artistId == bytes32(0)
                || basis.history.count == 0 || basis.history.commitment == bytes32(0)
                || basis.transition.artistId != basis.artistId
                || basis.transition.recordHash == bytes32(0) || basis.transition.phase != 2
                || basis.transition.executedAt == 0
                || (block.timestamp < basis.transition.postWindowEndsAt
                    && !(basis.transition.contestedAt != 0
                        && basis.transition.contestedAt < basis.transition.postWindowEndsAt))
        ) revert S.InvalidGuardianSelection(_key(basis));
        R.RotationRecord memory rotation =
            IStreamArtistRotationReads(owner).rotationRecord(basis.transition.recordHash);
        R.TransitionState memory transition =
            IStreamArtistRotationReads(owner).artistTransitionState(basis.transition.recordHash);
        (H.Head memory head,,,) = IStreamArtistGuardianHistory(owner)
            .guardianHistoryState(basis.artistId, 0, address(0), bytes32(0));
        bytes32 latest = IStreamArtistRotationReads(owner).lastArtistTransition(basis.artistId);
        if (latest != basis.transition.recordHash) {
            D.Cause memory cause = IStreamArtistIdentityDismissalOwner(owner)
                .currentIdentityContestCause(basis.artistId);
            if (
                cause.facts.artistId != basis.artistId || cause.facts.kind != 1
                    || cause.facts.executedTransitionHash != basis.transition.recordHash
                    || cause.facts.pendingTransitionHash != 0
                    || IStreamArtistRotationReads(owner).artistTransitionState(latest).phase != 3
            ) {
                revert S.InvalidGuardianSelection(_key(basis));
            }
        }
        if (rotation.recordHash != 0) {
            if (
                rotation.recordHash != basis.transition.recordHash
                    || rotation.terms.artistId != basis.artistId
                    || keccak256(abi.encode(rotation.transition))
                        != keccak256(abi.encode(basis.transition))
            ) {
                revert S.InvalidGuardianSelection(_key(basis));
            }
        } else if (
            IStreamArtistIdentityRecoveryOwner(owner).latestIdentityRecovery(basis.artistId)
                == basis.transition.recordHash
        ) {
            Recovery.Record memory r = IStreamArtistIdentityRecoveryOwner(owner)
                .identityRecoveryRecord(basis.transition.recordHash);
            if (
                r.recordHash != basis.transition.recordHash || r.fields.artistId != basis.artistId
                    || r.fields.recoveredAt != basis.transition.executedAt
            ) {
                revert S.InvalidGuardianSelection(_key(basis));
            }
        } else {
            (
                Estate.RequestRecord memory request,
                uint8 phase,
                Estate.ExecutionFacts memory execution
            ) = IStreamArtistEstateOwner(owner).estateActivationRecord(basis.transition.recordHash);
            if (request.recordHash == 0) {
                // A current designated op43 has no estate-request record. Authenticate its
                // original owner notice/completion/vesting instead of synthesizing an op40.
                StreamArtistDormancyVestingReads.current(
                    owner, artistRegistry, deploymentChainId, basis.artistId, basis.transition
                );
            } else if (
                request.recordHash != basis.transition.recordHash
                    || request.terms.artistId != basis.artistId || phase != 2
                    || execution.activationRecordHash != request.recordHash
                    || execution.executedAt != basis.transition.executedAt
            ) {
                revert S.InvalidGuardianSelection(_key(basis));
            }
        }
        if (
            keccak256(abi.encode(transition)) != keccak256(abi.encode(basis.transition))
                || keccak256(abi.encode(head)) != keccak256(abi.encode(basis.history))
        ) {
            revert S.InvalidGuardianSelection(_key(basis));
        }
    }

    function _shape(bytes32[] calldata excluded) private pure {
        if (excluded.length == 0 || excluded.length > 64) {
            revert S.InvalidGuardianSelection(bytes32(0));
        }
        bytes32 previous;
        for (uint256 i; i < excluded.length; ++i) {
            if (excluded[i] <= previous) revert S.InvalidGuardianSelection(excluded[i]);
            previous = excluded[i];
        }
    }

    function _key(S.Basis memory basis) private view returns (bytes32) {
        bytes32 original = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_GUARDIAN_SELECTION_SOURCE_V1"),
                deploymentChainId,
                artistRegistry,
                owner,
                basis
            )
        );
        // Permanent exclusions change only during op35. Capture its actual latest head:
        // every continuation and consumption rejects an earlier status generation.
        bytes32 recovery =
            IStreamArtistIdentityRecoveryOwner(owner).latestIdentityRecovery(basis.artistId);
        if (recovery == 0) return original;
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_GUARDIAN_SELECTION_RECOVERY_BASIS_V1"),
                original,
                recovery
            )
        );
    }
}
