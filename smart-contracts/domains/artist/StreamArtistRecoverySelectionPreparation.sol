// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamArtistRecoverySelectionPreparation,
    IStreamArtistRecoverySelectionOwnerV2
} from "../../interfaces/stream/artist/IStreamArtistRecoverySelectionPreparation.sol";
import {
    IStreamArtistRecoveryEvidence,
    IStreamArtistRecoveryEvidenceBinding
} from "../../interfaces/stream/artist/IStreamArtistRecoveryEvidence.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
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
    StreamArtistRecoverySelectionTypesV2 as V2
} from "../../interfaces/stream/artist/StreamArtistRecoverySelectionTypesV2.sol";
import {
    StreamArtistGuardianSelectionTypes as S
} from "../../interfaces/stream/artist/StreamArtistGuardianSelectionTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as H
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistRecoveryEvidenceTypes as E
} from "../../interfaces/stream/artist/StreamArtistRecoveryEvidenceTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistGuardianSupersessionTypes as Supersession
} from "../../interfaces/stream/artist/StreamArtistGuardianSupersessionTypes.sol";

/// @notice Permissionless bounded election over an owner-authenticated V2 adjudication basis.
/// @dev The owner proves the current cause, complete ancestry and temporally stable eligibility.
/// This worker grants no authority, does not change owner revision and accepts no caller history.
contract StreamArtistRecoverySelectionPreparation is IStreamArtistRecoverySelectionPreparation {
    address public immutable override owner;
    address public immutable override artistRegistry;
    uint256 public immutable override deploymentChainId;

    mapping(bytes32 => V2.Basis) private _bases;
    mapping(bytes32 => S.Progress) private _progress;
    mapping(bytes32 => bytes32[]) private _excluded;
    mapping(bytes32 => mapping(bytes32 => uint8)) private _excludedIndex;
    mapping(bytes32 => mapping(address => bool)) private _retainedMembers;

    constructor(address owner_, address registry_) {
        // The owner can still be constructing when the fixed recovery child creates this worker.
        if (owner_ == address(0) || registry_ == address(0) || owner_ == registry_) {
            revert S.InvalidGuardianSelection(bytes32(0));
        }
        owner = owner_;
        artistRegistry = registry_;
        deploymentChainId = block.chainid;
    }

    function beginSelectionV2(bytes32 manifestHash) external override returns (bytes32 key) {
        (V2.Basis memory basis, bytes32[] memory excluded) = _basis(manifestHash);
        key = _key(basis);
        if (_bases[key].artistId != bytes32(0)) {
            _requireStored(key, basis, excluded);
            return key;
        }
        _bases[key] = basis;
        _excluded[key] = excluded;
        for (uint256 i; i < excluded.length; ++i) {
            _excludedIndex[key][excluded[i]] = uint8(i + 1);
        }
        emit RecoverySelectionPrepared(key, manifestHash, basis.history.count);
    }

    function continueSelectionV2(bytes32 key, uint64 maximumRecords)
        external
        override
        returns (S.Progress memory progress)
    {
        V2.Basis memory saved = _bases[key];
        if (saved.artistId == bytes32(0) || maximumRecords == 0) {
            revert S.InvalidGuardianSelection(key);
        }
        (V2.Basis memory basis, bytes32[] memory excluded) = _basis(saved.manifestHash);
        _requireStored(key, basis, excluded);
        progress = _progress[key];
        if (progress.complete) return progress;
        uint256 end = uint256(progress.processed) + maximumRecords;
        if (end > basis.history.count) end = basis.history.count;
        for (uint256 index = uint256(progress.processed) + 1; index <= end; ++index) {
            _visit(key, basis, progress, uint64(index));
        }
        if (progress.processed == basis.history.count) {
            uint64 allExcluded = uint64((uint256(1) << excluded.length) - 1);
            if (
                progress.historyTip != basis.history.commitment
                    || progress.lastOwnerRevision != basis.history.ownerRevision
                    || progress.excludedSeen != allExcluded
            ) revert S.InvalidGuardianSelection(key);
            // This write is required even for a genuinely empty original history.
            progress.complete = true;
        }
        _progress[key] = progress;
        emit RecoverySelectionProgress(key, progress.processed, progress.complete);
    }

    function requireSelectionV2(bytes32 manifestHash)
        external
        view
        override
        returns (S.Result memory result)
    {
        (V2.Basis memory basis, bytes32[] memory excluded) = _basis(manifestHash);
        result.sourceKey = _key(basis);
        S.Progress memory p = _progress[result.sourceKey];
        if (!p.complete || p.processed != basis.history.count) {
            revert S.IncompleteGuardianSelection(result.sourceKey, p.processed, basis.history.count);
        }
        _requireStored(result.sourceKey, basis, excluded);
        result.selectedRecordHash = p.selectedRecordHash;
        result.selectedDataHash = p.selectedDataHash;
        result.selectedNonce = p.selectedNonce;
        result.commitment = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_GUARDIAN_SELECTION_RESULT_V2"),
                result.sourceKey,
                basis,
                p
            )
        );
    }

    function selectionV2(bytes32 key)
        external
        view
        override
        returns (V2.Basis memory, S.Progress memory)
    {
        return (_bases[key], _progress[key]);
    }

    /// @dev Consume the frozen scan, not today's history: a later veto or owner mutation must not
    /// rewrite an earlier prepared action's cohort. The owner binds its saved election source key.
    function retainedMemberV2(bytes32 key, address actor) external view override returns (bool) {
        V2.Basis memory basis = _bases[key];
        if (basis.artistId == bytes32(0) || _key(basis) != key) {
            revert S.InvalidGuardianSelection(key);
        }
        S.Progress memory progress = _progress[key];
        if (!progress.complete || progress.processed != basis.history.count) {
            revert S.IncompleteGuardianSelection(key, progress.processed, basis.history.count);
        }
        return actor != address(0) && _retainedMembers[key][actor];
    }

    function _basis(bytes32 manifestHash)
        private
        view
        returns (V2.Basis memory basis, bytes32[] memory excluded)
    {
        if (
            manifestHash == bytes32(0) || block.chainid != deploymentChainId
                || owner.code.length == 0
                || IStreamArtistOwner(owner).artistRegistry() != artistRegistry
                || IStreamArtistOwner(owner).deploymentChainId() != deploymentChainId
        ) revert S.InvalidGuardianSelection(manifestHash);
        basis = IStreamArtistRecoverySelectionOwnerV2(owner).recoverySelectionBasisV2(manifestHash);
        if (
            basis.manifestHash != manifestHash || basis.artistId == bytes32(0)
                || basis.ownerCodeHash != owner.codehash || basis.sourceCommitment == bytes32(0)
                || (basis.history.count == 0
                        ? basis.history.ownerRevision != 0 || basis.history.commitment != bytes32(0)
                        : basis.history.ownerRevision == 0 || basis.history.commitment == bytes32(0))
        ) revert S.InvalidGuardianSelection(manifestHash);
        (H.Head memory current,,,) = IStreamArtistGuardianHistory(owner)
            .guardianHistoryState(basis.artistId, 0, address(0), bytes32(0));
        if (keccak256(abi.encode(current)) != keccak256(abi.encode(basis.history))) {
            revert S.InvalidGuardianSelection(manifestHash);
        }
        excluded = _manifestExclusions(basis);
    }

    function _manifestExclusions(V2.Basis memory basis)
        private
        view
        returns (bytes32[] memory excluded)
    {
        (address target, bytes32 codeHash) =
            IStreamArtistRecoveryEvidenceBinding(owner).recoveryEvidenceBinding();
        if (target.code.length == 0 || codeHash == bytes32(0) || target.codehash != codeHash) {
            revert S.InvalidGuardianSelection(basis.manifestHash);
        }
        IStreamArtistRecoveryEvidence publisher = IStreamArtistRecoveryEvidence(target);
        if (
            publisher.owner() != owner || publisher.artistRegistry() != artistRegistry
                || publisher.deploymentChainId() != deploymentChainId
        ) revert S.InvalidGuardianSelection(basis.manifestHash);
        (E.ResolutionManifest memory manifest, bytes32 ownerCodeHash) =
            publisher.resolutionManifest(basis.manifestHash);
        if (
            ownerCodeHash != basis.ownerCodeHash || manifest.artistId != basis.artistId
                || E.manifestHash(
                        deploymentChainId,
                        artistRegistry,
                        owner,
                        ownerCodeHash,
                        publisher.coordinator(),
                        publisher.archive(),
                        publisher.core(),
                        publisher.mintManager(),
                        manifest
                    ) != basis.manifestHash
        ) revert S.InvalidGuardianSelection(basis.manifestHash);
        excluded = manifest.supersededRecordHashes;
        if (excluded.length > E.MAX_SUPERSESSIONS) {
            revert S.InvalidGuardianSelection(basis.manifestHash);
        }
        bytes32 previous;
        for (uint256 i; i < excluded.length; ++i) {
            if (excluded[i] <= previous) revert S.InvalidGuardianSelection(basis.manifestHash);
            previous = excluded[i];
        }
    }

    function _visit(bytes32 key, V2.Basis memory basis, S.Progress memory p, uint64 index) private {
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
        if (excludedIndex == 0 && status.recoveryRecordHash == bytes32(0)) {
            // Original historical guardians retain veto even when their record is abandoned or
            // otherwise ineligible to become the operative winner of this election.
            for (uint256 i; i < record.terms.guardians.length; ++i) {
                _retainedMembers[key][record.terms.guardians[i]] = true;
            }
        }
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

    function _requireStored(bytes32 key, V2.Basis memory basis, bytes32[] memory excluded)
        private
        view
    {
        if (
            key != _key(basis) || keccak256(abi.encode(_bases[key])) != keccak256(abi.encode(basis))
                || keccak256(abi.encode(_excluded[key])) != keccak256(abi.encode(excluded))
        ) revert S.InvalidGuardianSelection(key);
    }

    function _key(V2.Basis memory basis) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_GUARDIAN_SELECTION_SOURCE_V2"),
                deploymentChainId,
                artistRegistry,
                owner,
                basis
            )
        );
    }
}
