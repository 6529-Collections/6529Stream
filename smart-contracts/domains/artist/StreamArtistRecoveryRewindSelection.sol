// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveryRewindSelectionState as Store
} from "./StreamArtistRecoveryRewindSelectionState.sol";
import {
    StreamArtistRecoveryRewindSelectionScan as Scan
} from "./StreamArtistRecoveryRewindSelectionScan.sol";
import {
    StreamArtistRecoveryRewindEnvironment as Environment
} from "./StreamArtistRecoveryRewindEnvironment.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveryActionTypes as A
} from "../../interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import {
    IStreamArtistRecoveryRewindSelection
} from "../../interfaces/stream/artist/IStreamArtistRecoveryRewindSelection.sol";
import {
    IStreamArtistRecoveryRewindEvidence
} from "../../interfaces/stream/artist/IStreamArtistRecoveryRewindEvidence.sol";
import {
    IStreamArtistIdentityRecoveryOwnerV3
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";
import {
    IStreamArtistRecoveryPayoutOwnerV3
} from "../../interfaces/stream/artist/IStreamArtistRecoveryPayoutOwnerV3.sol";
import {
    IStreamArtistRecoveryActionOwner
} from "../../interfaces/stream/artist/IStreamArtistRecoveryAction.sol";
import {
    IStreamArtistGuardianHistory
} from "../../interfaces/stream/artist/IStreamArtistGuardianHistory.sol";
import {
    IStreamArtistNativeReceipts
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";

import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";

/// @notice Resumable fixed-owner election from complete original native receipt prefixes.
/// @dev Preparation facts only. Historical getters preserve the completed scan; requireSelection
/// additionally enforces exact current source snapshots, including the separately sealed op65534.
contract StreamArtistRecoveryRewindSelection is IStreamArtistRecoveryRewindSelection {
    address public immutable override owner;
    address public immutable override artistRegistry;
    address public immutable override coordinator;
    uint256 public immutable override deploymentChainId;
    Store.State private _state;

    event RecoveryRewindSelectionBegun(bytes32 indexed key, bytes32 indexed manifestHash);
    event RecoveryRewindSelectionProgress(
        bytes32 indexed key, uint256 identityProcessed, uint256 payoutProcessed, bool complete
    );
    event RecoveryRewindPreparationSealed(
        bytes32 indexed key, bytes32 indexed actionId, bytes32 commitment
    );

    constructor(address owner_, address registry_, address coordinator_) {
        // The fixed owner and Coordinator can still be constructing.
        if (
            owner_ == address(0) || registry_ == address(0) || coordinator_ == address(0)
                || owner_ == registry_ || owner_ == coordinator_ || registry_ == coordinator_
        ) {
            revert W.InvalidRecoveryRewindSelection(bytes32(0));
        }
        owner = owner_;
        artistRegistry = registry_;
        coordinator = coordinator_;
        deploymentChainId = block.chainid;
    }

    function payoutOwner() external view override returns (address) {
        return _environment().payoutOwner;
    }

    function beginSelectionV3(bytes32 manifestHash) external override returns (bytes32 key) {
        key = _state.manifestKeys[manifestHash];
        if (key != 0) {
            _requireCurrent(key);
            return key;
        }
        W.EnvironmentV3 memory e = _environment();
        W.ResolutionManifestV3 memory m = _manifest(e, manifestHash);
        _prefix(e.identityOwner, m.identity, m.identity.snapshot, manifestHash);
        _prefix(e.payoutOwner, m.payout, m.payout.snapshot, manifestHash);
        W.BasisV3 memory b = _basis(e, manifestHash, m);
        key = W.selectionKey(e, b);
        if (key == 0 || _state.bases[key].identity.artistId != 0) {
            revert W.InvalidRecoveryRewindSelection(key);
        }
        _state.manifestKeys[manifestHash] = key;
        _state.environments[key] = e;
        _state.bases[key] = b;
        _state.excluded[key] = m.supersededRecords;
        for (uint256 i; i < m.supersededRecords.length; ++i) {
            _state.excludedIndex[key][m.supersededRecords[i].recordHash] = uint8(i + 1);
        }
        emit RecoveryRewindSelectionBegun(key, manifestHash);
    }

    function continueSelectionV3(bytes32 key, uint64 maximumRecords)
        external
        override
        returns (W.ProgressV3 memory)
    {
        if (maximumRecords == 0) revert W.InvalidRecoveryRewindSelection(key);
        _requireCurrent(key);
        if (_state.progress[key].complete) return _state.progress[key];
        W.BasisV3 storage b = _state.bases[key];
        uint64 remaining = maximumRecords;
        while (
            remaining != 0
                && _state.progress[key].identityProcessed < b.identity.identity.receiptCount
        ) {
            Scan.identity(_state, key, _state.progress[key].identityProcessed);
            --remaining;
        }
        while (remaining != 0 && _state.progress[key].payoutProcessed < b.payout.receiptCount) {
            Scan.payout(_state, key, _state.progress[key].payoutProcessed);
            --remaining;
        }
        if (
            _state.progress[key].identityProcessed == b.identity.identity.receiptCount
                && _state.progress[key].payoutProcessed == b.payout.receiptCount
        ) Scan.finish(_state, key);
        W.ProgressV3 memory p = _state.progress[key];
        emit RecoveryRewindSelectionProgress(
            key, p.identityProcessed, p.payoutProcessed, p.complete
        );
        return p;
    }

    function requireSelectionV3(bytes32 manifestHash)
        external
        view
        override
        returns (W.ResultV3 memory)
    {
        bytes32 key = _state.manifestKeys[manifestHash];
        if (key == 0) {
            W.EnvironmentV3 memory e = _environment();
            W.ResolutionManifestV3 memory m = _manifest(e, manifestHash);
            _prefix(e.identityOwner, m.identity, m.identity.snapshot, manifestHash);
            _prefix(e.payoutOwner, m.payout, m.payout.snapshot, manifestHash);
            key = W.selectionKey(e, _basis(e, manifestHash, m));
            revert W.InvalidRecoveryRewindSelection(key);
        }
        _requireCurrent(key);
        return _completed(key);
    }

    function selectionV3(bytes32 key)
        external
        view
        override
        returns (W.BasisV3 memory, W.ProgressV3 memory)
    {
        return (_state.bases[key], _state.progress[key]);
    }

    function selectionResultV3(bytes32 key) external view override returns (W.ResultV3 memory) {
        return _completed(key);
    }

    function selectionRecordV3(bytes32 key, bytes32 recordHash)
        external
        view
        override
        returns (W.RecordKind, W.SelectedRecordV3 memory, bool retained, bool eligible)
    {
        _completed(key);
        if (!_state.admitted[key][recordHash]) revert W.InvalidRecoveryRewindSelection(key);
        return (
            _state.kinds[key][recordHash],
            _state.records[key][recordHash].selected,
            _state.retained[key][recordHash],
            _state.records[key][recordHash].eligible
        );
    }

    function retainedMemberV3(bytes32 key, address actor) external view override returns (bool) {
        _completed(key);
        return actor != address(0) && _state.retainedMembers[key][actor];
    }

    function preparationSealV3(bytes32 key)
        external
        view
        override
        returns (W.PreparationSealV3 memory)
    {
        return _state.seals[key];
    }

    function sealPreparationV3(bytes32 manifestHash, bytes32 actionId, bytes32 associationHash)
        external
        override
        returns (bytes32)
    {
        if (msg.sender != coordinator || actionId == 0 || associationHash == 0) {
            revert W.InvalidRecoveryRewindPreparation(actionId);
        }
        bytes32 key = _state.manifestKeys[manifestHash];
        W.ResultV3 memory result = _completed(key);
        W.BasisV3 memory b = _state.bases[key];
        W.EnvironmentV3 memory e = _environment();
        _environmentMatch(key, e);
        _prefix(e.payoutOwner, b.payout, b.payout.snapshot, key);
        if (_count(owner) != b.identity.identity.receiptCount) {
            revert W.InvalidRecoveryRewindPreparation(actionId);
        }
        T.Snapshot memory afterPreparation = IStreamArtistOwner(owner).ownerStateSnapshotV2();
        if (
            b.identity.identity.snapshot.revision == type(uint64).max
                || afterPreparation.revision != b.identity.identity.snapshot.revision + 1
                || afterPreparation.domainId != b.identity.identity.snapshot.domainId
                || afterPreparation.stateRoot == 0 || afterPreparation.recordChainTip == 0
        ) {
            revert W.InvalidRecoveryRewindPreparation(actionId);
        }
        W.ResolutionManifestV3 memory m = _manifest(e, manifestHash);
        _basisMatch(key, e, _basis(e, manifestHash, m), m.supersededRecords);
        W.EvidenceStateV3 memory evidence =
            _prepared(key, actionId, associationHash, result, afterPreparation);
        W.PreparationSealV3 memory seal = W.PreparationSealV3(
            manifestHash,
            key,
            actionId,
            associationHash,
            b.identity.identity,
            afterPreparation,
            b.payout,
            keccak256(abi.encode(evidence)),
            bytes32(0)
        );
        seal.commitment = W.preparationSealHash(e, seal);
        if (_state.seals[key].commitment != 0) {
            if (keccak256(abi.encode(_state.seals[key])) != keccak256(abi.encode(seal))) {
                revert W.InvalidRecoveryRewindPreparation(actionId);
            }
            return seal.commitment;
        }
        _state.seals[key] = seal;
        emit RecoveryRewindPreparationSealed(key, actionId, seal.commitment);
        return seal.commitment;
    }

    function _prepared(
        bytes32 key,
        bytes32 actionId,
        bytes32 associationHash,
        W.ResultV3 memory result,
        T.Snapshot memory afterPreparation
    ) private view returns (W.EvidenceStateV3 memory evidence) {
        W.BasisV3 memory b = _state.bases[key];
        (A.Association memory prepared, A.Veto memory veto, bytes32 executed,) = IStreamArtistRecoveryActionOwner(
                owner
            ).identityRecoveryActionState(b.identity.artistId, bytes32(0));
        A.Veto memory emptyVeto;
        if (
            prepared.artistId != b.identity.artistId || prepared.action.actionId != actionId
                || prepared.associationHash != associationHash
                || prepared.ownerRevision != afterPreparation.revision || prepared.requestHash == 0
                || prepared.acceptanceHash == 0 || prepared.contextHash == 0
                || prepared.preparedBy == address(0) || prepared.preparedAt == 0 || executed != 0
                || keccak256(abi.encode(veto)) != keccak256(abi.encode(emptyVeto))
        ) {
            revert W.InvalidRecoveryRewindPreparation(actionId);
        }
        evidence = IStreamArtistIdentityRecoveryOwnerV3(owner)
            .identityRecoveryEvidenceStateV3(b.identity.artistId, actionId);
        if (
            evidence.manifestHash != b.identity.manifestHash || evidence.sourceKey != key
                || evidence.sourceCommitment != b.sourceCommitment
                || evidence.selectionCommitment != result.commitment
                || evidence.policyCommitment == 0 || evidence.requiredRole == 0
                || evidence.associationHash != associationHash
                || evidence.sources.associationHash != associationHash
                || keccak256(abi.encode(evidence.sources.identityBefore))
                    != keccak256(abi.encode(b.identity.identity))
                || keccak256(abi.encode(evidence.sources.payout)) != keccak256(abi.encode(b.payout))
        ) {
            revert W.InvalidRecoveryRewindPreparation(actionId);
        }
    }

    function _requireCurrent(bytes32 key) private view {
        W.BasisV3 memory saved = _state.bases[key];
        if (key == 0 || saved.identity.artistId == 0) revert W.InvalidRecoveryRewindSelection(key);
        W.EnvironmentV3 memory e = _environment();
        _environmentMatch(key, e);
        W.PreparationSealV3 memory seal = _state.seals[key];
        T.Snapshot memory expected = saved.identity.identity.snapshot;
        if (seal.commitment != 0) {
            if (
                seal.sourceKey != key || seal.manifestHash != saved.identity.manifestHash
                    || seal.commitment != W.preparationSealHash(e, seal)
            ) revert W.InvalidRecoveryRewindSelection(key);
            expected = seal.identityAfterPreparation;
        }
        // Check before calling the owner basis hook so stale known keys have one exact error.
        _prefix(owner, saved.identity.identity, expected, key);
        _prefix(e.payoutOwner, saved.payout, saved.payout.snapshot, key);
        W.ResolutionManifestV3 memory m = _manifest(e, saved.identity.manifestHash);
        _basisMatch(key, e, _basis(e, saved.identity.manifestHash, m), m.supersededRecords);
        if (seal.commitment != 0) {
            W.EvidenceStateV3 memory evidence =
                _prepared(key, seal.actionId, seal.associationHash, _completed(key), expected);
            if (keccak256(abi.encode(evidence)) != seal.evidenceStateHash) {
                revert W.InvalidRecoveryRewindSelection(key);
            }
        }
    }

    function _completed(bytes32 key) private view returns (W.ResultV3 memory result) {
        W.BasisV3 memory b = _state.bases[key];
        W.ProgressV3 memory p = _state.progress[key];
        W.EnvironmentV3 memory e = _environment();
        _environmentMatch(key, e);
        result = _state.results[key];
        if (
            b.identity.artistId == 0 || key != W.selectionKey(e, b) || !p.complete
                || b.sourceCommitment != W.selectionSourceHash(e, b)
                || p.identityProcessed != b.identity.identity.receiptCount
                || p.payoutProcessed != b.payout.receiptCount
                || p.guardiansProcessed != b.identity.guardianHistory.count
                || p.seenExclusions != (uint256(1) << _state.excluded[key].length) - 1
                || result.sourceKey != key || result.manifestHash != b.identity.manifestHash
                || result.sourceCommitment != b.sourceCommitment
                || result.guardians.sourceKey != key
                || result.inventoryCommitment
                    != W.selectionInventoryHash(e, b.identity.inventory, b.payoutInventory)
                || result.commitment == 0 || result.commitment != p.resultCommitment
                || result.commitment != W.selectionResultHash(e, result)
        ) revert W.InvalidRecoveryRewindSelection(key);
    }

    function _basis(W.EnvironmentV3 memory e, bytes32 manifestHash, W.ResolutionManifestV3 memory m)
        private
        view
        returns (W.BasisV3 memory b)
    {
        b.identity = IStreamArtistIdentityRecoveryOwnerV3(owner).recoveryRewindBasisV3(manifestHash);
        b.payoutCodeHash = e.payoutCodeHash;
        b.payout = m.payout;
        b.payoutInventory =
            IStreamArtistRecoveryPayoutOwnerV3(e.payoutOwner).payoutRewindInventoryV3(m.artistId);
        (GH.Head memory head,,,) = IStreamArtistGuardianHistory(owner)
            .guardianHistoryState(m.artistId, 0, address(0), bytes32(0));
        W.IdentityInventoryV3 memory inventory =
            IStreamArtistIdentityRecoveryOwnerV3(owner).recoveryRewindInventoryV3(m.artistId);
        if (
            b.identity.manifestHash != manifestHash || b.identity.artistId != m.artistId
                || m.artistId == 0 || b.identity.ownerCodeHash != e.identityCodeHash
                || b.identity.sourceCommitment == 0
                || keccak256(abi.encode(b.identity.identity)) != keccak256(abi.encode(m.identity))
                || keccak256(abi.encode(head)) != keccak256(abi.encode(b.identity.guardianHistory))
                || keccak256(abi.encode(inventory)) != keccak256(abi.encode(b.identity.inventory))
                || (head.count == 0
                        ? head.commitment != 0 || head.ownerRevision != 0
                        : head.commitment == 0 || head.ownerRevision == 0
                        || (!Recovered.active(owner)
                            && head.ownerRevision > m.identity.snapshot.revision))
        ) {
            revert W.InvalidRecoveryRewindSelection(manifestHash);
        }
        if (head.count != 0 && Recovered.active(owner)) {
            (, GH.Entry memory last,,) = IStreamArtistGuardianHistory(owner)
                .guardianHistoryState(m.artistId, head.count, address(0), 0);
            if (last.commitment != head.commitment || last.ownerRevision != head.ownerRevision) {
                revert W.InvalidRecoveryRewindSelection(manifestHash);
            }
            Recovered.guardianEntry(Runtime.load(e, 2), last);
        }
        b.sourceCommitment = W.selectionSourceHash(e, b);
    }

    function _basisMatch(
        bytes32 key,
        W.EnvironmentV3 memory e,
        W.BasisV3 memory b,
        W.RecordReference[] memory excluded
    ) private view {
        if (
            key != W.selectionKey(e, b)
                || keccak256(abi.encode(_state.bases[key])) != keccak256(abi.encode(b))
                || keccak256(abi.encode(_state.excluded[key])) != keccak256(abi.encode(excluded))
        ) {
            revert W.InvalidRecoveryRewindSelection(key);
        }
    }

    function _prefix(
        address target,
        W.ReceiptPrefix memory prefix,
        T.Snapshot memory expected,
        bytes32 failureKey
    ) private view {
        if (
            keccak256(abi.encode(IStreamArtistOwner(target).ownerStateSnapshotV2()))
                    != keccak256(abi.encode(expected)) || _count(target) != prefix.receiptCount
        ) {
            revert W.InvalidRecoveryRewindSelection(failureKey);
        }
    }

    function _count(address target) private view returns (uint256) {
        if (!Recovered.active(target)) {
            return IStreamArtistNativeReceipts(target).artistNativeReceiptCount();
        }
        W.EnvironmentV3 memory e = _environment();
        return Runtime.logicalCount(Runtime.load(e, target == e.identityOwner ? 2 : 5));
    }

    function _environmentMatch(bytes32 key, W.EnvironmentV3 memory e) private view {
        if (key == 0 || keccak256(abi.encode(_state.environments[key])) != keccak256(abi.encode(e)))
        {
            revert W.InvalidRecoveryRewindSelection(key);
        }
    }

    function _environment() private view returns (W.EnvironmentV3 memory e) {
        if (block.chainid != deploymentChainId || owner.code.length == 0) {
            revert W.RecoveryRewindDependencyChanged(owner);
        }
        IStreamArtistOwner o = IStreamArtistOwner(owner);
        e = Environment.fromFixed(
            owner, artistRegistry, coordinator, o.archiveV2(), o.core(), o.mintManager()
        );
    }

    function _manifest(W.EnvironmentV3 memory e, bytes32 hash)
        private
        view
        returns (W.ResolutionManifestV3 memory m)
    {
        (address target, bytes32 pin) =
            IStreamArtistIdentityRecoveryOwnerV3(owner).recoveryRewindEvidenceBinding();
        if (target.code.length == 0 || pin == 0 || target.codehash != pin) {
            revert W.RecoveryRewindDependencyChanged(target);
        }
        IStreamArtistRecoveryRewindEvidence publisher = IStreamArtistRecoveryRewindEvidence(target);
        if (
            publisher.owner() != owner || publisher.payoutOwner() != e.payoutOwner
                || publisher.artistRegistry() != artistRegistry
                || publisher.deploymentChainId() != deploymentChainId
                || publisher.coordinator() != coordinator || publisher.archive() != e.archive
                || publisher.core() != e.core || publisher.mintManager() != e.manager
        ) revert W.RecoveryRewindDependencyChanged(target);
        bytes32 identityPin;
        bytes32 payoutPin;
        (m, identityPin, payoutPin) = publisher.resolutionManifestV3(hash);
        if (
            hash == 0 || identityPin != e.identityCodeHash || payoutPin != e.payoutCodeHash
                || hash != W.manifestHash(e, m) || m.supersededRecords.length > W.MAX_SUPERSESSIONS
        ) {
            revert W.InvalidRecoveryRewindSelection(hash);
        }
        bytes32 previous;
        for (uint256 i; i < m.supersededRecords.length; ++i) {
            if (m.supersededRecords[i].recordHash <= previous) {
                revert W.InvalidRecoveryRewindSelection(hash);
            }
            previous = m.supersededRecords[i].recordHash;
        }
    }
}
