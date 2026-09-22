// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistPayoutReadEncoding } from "./StreamArtistPayoutReadEncoding.sol";
import { StreamArtistRecoveredPayoutTransport } from "./StreamArtistRecoveredPayoutTransport.sol";
import { StreamArtistRecoveredHydrationCodec } from "./StreamArtistRecoveredHydrationCodec.sol";
import "./StreamArtistPayoutHydration.sol";
import "./StreamArtistAuthorityCheckpoint.sol";
import {
    StreamArtistPayoutRecoveryState as RewindState
} from "./StreamArtistPayoutRecoveryState.sol";
import { StreamArtistPayoutRecovery as Rewind } from "./StreamArtistPayoutRecovery.sol";
import {
    StreamArtistRecoveryRewindEnvironment as RewindEnvironment
} from "./StreamArtistRecoveryRewindEnvironment.sol";
import {
    StreamArtistRecoveryRewindTypes as RewindTypes
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    IStreamArtistSuiteReads
} from "../../interfaces/stream/artist/IStreamArtistSuiteReads.sol";

import "./StreamArtistOwner.sol";
import "./StreamArtistCurrentAuthorityFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistCurrentPayoutOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistPayoutTransitionOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistPayoutResolutionOwner.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Sole owner of operative payout designations; signing addresses are never payout fallbacks.
contract StreamArtistPayoutLifecycle is StreamArtistOwner {
    mapping(bytes32 => T.Payout) private _payouts;
    mapping(bytes32 => T.PayoutDesignation) private _records;
    mapping(bytes32 => T.Payout) private _pending;
    mapping(bytes32 => R.ProvisionalAssociation) private _associations;
    mapping(bytes32 => bytes32) private _abandonedUnder;
    RewindState.State private _recoveryRewind;
    event ArtistPayoutRecoveryRewindApplied(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        bytes32 indexed recoveryRecordHash,
        bytes32 indexed actionId,
        bytes32 planCommitment,
        bytes32 continuationHash,
        bytes32 mutationCommitment
    );
    event ArtistPayoutProvisionalChildAbandoned(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        bytes32 indexed abandonedRecordHash,
        bytes32 stableRecordHash,
        bytes32 indexed dismissalRecordHash
    );

    function payoutAbandonment(bytes32 recordHash) external view returns (bytes32) {
        return _abandonedUnder[recordHash];
    }

    function payoutRecoveryAppliedCommitmentV3(bytes32 recordHash) external view returns (bytes32) {
        return _recoveryRewind.appliedRecoveries[recordHash];
    }

    function payoutRewindInventoryV3(bytes32 artistId)
        external
        view
        returns (RewindTypes.PayoutInventoryV3 calldata)
    {
        _payoutRead();
    }

    function payoutRecoveryRecordStatusV3(bytes32 recordHash)
        external
        view
        returns (RewindTypes.StatusV3 calldata)
    {
        _payoutRead();
    }

    function payoutDesignationRecoveryContinuationV3(bytes32 recordHash)
        external
        view
        returns (bytes32)
    {
        return _recoveryRewind.recordContinuations[recordHash];
    }

    function payoutRecoveryContinuationV3(bytes32 continuationHash)
        external
        view
        returns (RewindTypes.PayoutContinuationV3 calldata)
    {
        _payoutRead();
    }

    function applyRecoveryRewindV3(
        T.ActionContext calldata c,
        RewindTypes.PayoutApplyV3 calldata plan
    ) external returns (bytes32 mutationCommitment) {
        _check(c, 35);
        Rewind.Mutation memory mutation = Rewind.applyRewind(
            _recoveryRewind, _payouts, _pending, _records, _replay, _rewindEnvironment(), c, plan
        );
        _commit(c, mutation.action, mutation.state, mutation.replay, bytes32(0));
        emit ArtistPayoutRecoveryRewindApplied(
            3,
            plan.artistId,
            plan.recoveryRecordHash,
            plan.actionId,
            plan.planCommitment,
            _recoveryRewind.continuationHeads[plan.artistId],
            mutation.commitment
        );
        return mutation.commitment;
    }
    event ArtistPayoutDesignationRecorded(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed payoutAccount,
        address indexed signer,
        bytes32 previousDesignationRecordHash,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt,
        bytes32 designationRecordHash
    );
    constructor(
        address registry_,
        address coordinator_,
        address archive_,
        address core_,
        address manager_
    )
        StreamArtistOwner(
            registry_, coordinator_, archive_, keccak256("domain:payout_lifecycle"), core_, manager_
        )
    { }

    function artistPayoutAccount(bytes32 artistId) external view returns (address, bytes32) {
        if (_pending[artistId].recordHash != bytes32(0)) {
            revert R.PayoutRequiresAuthorityContext(artistId);
        }
        T.Payout storage p = _payouts[artistId];
        return (p.account, p.recordHash);
    }

    function designationRecord(bytes32 record)
        external
        view
        returns (T.PayoutDesignation calldata)
    {
        _payoutRead();
    }

    function payoutDesignationProvisionalAssociation(bytes32 record)
        external
        view
        returns (R.ProvisionalAssociation calldata)
    {
        _payoutRead();
    }

    function payoutCandidates(bytes32 artistId)
        external
        view
        returns (
            T.Payout calldata stable,
            T.Payout calldata candidate,
            R.ProvisionalAssociation calldata association
        )
    {
        _payoutRead();
    }

    function _payoutRead() private view {
        bytes memory result = StreamArtistPayoutReadEncoding.read(
            _payouts, _pending, _records, _associations, _recoveryRewind, msg.data
        );
        assembly ("memory-safe") { return(add(result, 32), mload(result)) }
    }

    function recordDesignationWithTransition(
        T.ActionContext calldata c,
        T.PayoutDesignation calldata p,
        address signer,
        uint256 nonce,
        uint64 signedAt,
        R.TransitionState calldata currentTransition,
        R.TransitionState calldata candidateTransition
    ) external returns (bytes32 record) {
        Dismissal.PayoutResolutionFacts memory none;
        return _recordDesignation(
            c, p, signer, nonce, signedAt, currentTransition, candidateTransition, none, false, 1
        );
    }

    function recordDesignationWithResolution(
        T.ActionContext calldata c,
        T.PayoutDesignation calldata p,
        address signer,
        uint256 nonce,
        uint64 signedAt,
        R.TransitionState calldata currentTransition,
        R.TransitionState calldata candidateTransition,
        Dismissal.PayoutResolutionFacts calldata resolution
    ) external returns (bytes32 record) {
        return _recordDesignation(
            c,
            p,
            signer,
            nonce,
            signedAt,
            currentTransition,
            candidateTransition,
            resolution,
            true,
            1
        );
    }

    function recordDesignationWithAuthority(
        T.ActionContext calldata c,
        T.PayoutDesignation calldata p,
        address signer,
        uint256 nonce,
        uint64 signedAt,
        R.TransitionState calldata currentTransition,
        R.TransitionState calldata candidateTransition,
        Dismissal.PayoutResolutionFacts calldata resolution,
        R.AuthorityFact calldata authority
    ) external returns (bytes32) {
        _check(c, 18);
        StreamArtistCurrentAuthorityFacts.requirePrincipal(p.artistId, signer, authority, false);
        return _recordDesignation(
            c,
            p,
            signer,
            nonce,
            signedAt,
            currentTransition,
            candidateTransition,
            resolution,
            true,
            authority.authorityClass
        );
    }

    function _recordDesignation(
        T.ActionContext calldata c,
        T.PayoutDesignation calldata p,
        address signer,
        uint256 nonce,
        uint64 signedAt,
        R.TransitionState calldata currentTransition,
        R.TransitionState calldata candidateTransition,
        Dismissal.PayoutResolutionFacts memory resolution,
        bool modern,
        uint8 authorityClass
    ) private returns (bytes32 record) {
        _check(c, 18);
        if (modern && resolution.artistId != p.artistId) revert T.InvalidRecord();
        bool currentClosed = modern
            && _checkClosure(p.artistId, currentTransition, resolution.currentTransitionClosure);
        bool candidateClosed = modern
            && _checkClosure(p.artistId, candidateTransition, resolution.candidateTransitionClosure);
        bytes32 abandonedChild;
        bytes32 dismissal;
        T.Payout memory current = _payouts[p.artistId];
        T.Payout memory candidate = _pending[p.artistId];
        if (candidate.recordHash != bytes32(0)) {
            R.ProvisionalAssociation memory candidateAssociation =
                _associations[candidate.recordHash];
            if (!R.eligible(p.artistId, candidateAssociation, candidateTransition, block.timestamp))
            {
                Dismissal.Closure memory closure_ = resolution.candidateTransitionClosure;
                if (
                    !candidateClosed || !closure_.abandoned
                        || closure_.transitionRecordHash
                            != candidateAssociation.transitionRecordHash
                        || closure_.windowEndsAt != candidateAssociation.windowEndsAt
                ) revert R.ProvisionalChainOccupied(candidate.recordHash);
                if (_abandonedUnder[candidate.recordHash] != bytes32(0)) revert T.InvalidRecord();
                abandonedChild = candidate.recordHash;
                dismissal = closure_.dismissalRecordHash;
            } else {
                current = candidate;
            }
        } else if (modern && candidateTransition.recordHash != bytes32(0)) {
            revert T.InvalidRecord();
        }
        if (
            p.artistId == bytes32(0) || p.payoutAccount == address(0) || signer == address(0)
                || current.recordHash != p.previousDesignationRecordHash
                || current.account == p.payoutAccount
        ) {
            revert T.InvalidRecord();
        }
        R.ProvisionalAssociation memory association;
        if (currentTransition.recordHash != bytes32(0) && !currentClosed) {
            if (
                currentTransition.artistId != p.artistId || currentTransition.phase != 2
                    || currentTransition.executedAt == 0
            ) revert T.InvalidRecord();
            if (block.timestamp < currentTransition.postWindowEndsAt) {
                if (currentTransition.contestedAt != 0) revert T.InvalidIdentity(p.artistId);
                association = R.ProvisionalAssociation(
                    currentTransition.recordHash, currentTransition.postWindowEndsAt
                );
            }
        }
        record = StreamArtistHashes.payoutRecordForAuthority(
            _environment(), p, signer, authorityClass, nonce, signedAt
        );
        if (_records[record].artistId != bytes32(0)) revert T.InvalidRecord();
        if (abandonedChild != bytes32(0)) _abandonedUnder[abandonedChild] = dismissal;
        _records[record] = p;
        _associations[record] = association;
        if (association.transitionRecordHash == bytes32(0)) {
            _payouts[p.artistId] = T.Payout(p.payoutAccount, record);
            delete _pending[p.artistId];
        } else {
            _payouts[p.artistId] = current;
            _pending[p.artistId] = T.Payout(p.payoutAccount, record);
        }
        bytes32 key = _replayKey(
            keccak256("payout_lifecycle.replay.designation_chain"),
            keccak256(abi.encode(p.artistId))
        );
        _replay[key] = T.ReplayCell(record, _revision + 1, 3, 1);
        StreamArtistAuthorityCheckpoint.noteReplay(key, _replay[key]);
        bytes32 recoveryAdmission = _noteRecoveryAdmission(p, record);
        _commit(
            c,
            modern
                ? keccak256(
                    abi.encode(
                        p,
                        signer,
                        nonce,
                        signedAt,
                        currentTransition,
                        candidateTransition,
                        resolution,
                        abandonedChild,
                        dismissal
                    )
                )
                : keccak256(
                    abi.encode(p, signer, nonce, signedAt, currentTransition, candidateTransition)
                ),
            _withRecoveryAdmission(
                keccak256("6529STREAM_ARTIST_PAYOUT_ADMISSION_STATE_V3"),
                modern
                    ? keccak256(
                        abi.encode(
                            p.artistId,
                            _payouts[p.artistId],
                            _pending[p.artistId],
                            association,
                            record,
                            abandonedChild,
                            dismissal,
                            current.recordHash
                        )
                    )
                    : keccak256(
                        abi.encode(
                            p.artistId,
                            _payouts[p.artistId],
                            _pending[p.artistId],
                            association,
                            record
                        )
                    ),
                recoveryAdmission
            ),
            _withRecoveryAdmission(
                keccak256("6529STREAM_ARTIST_PAYOUT_ADMISSION_REPLAY_V3"),
                keccak256(abi.encode(key, current.recordHash, record)),
                recoveryAdmission
            ),
            record
        );
        _native(c.operationId, record, p.artistId, 0);
        emit ArtistPayoutDesignationRecorded(
            1,
            p.artistId,
            p.payoutAccount,
            signer,
            current.recordHash,
            authorityClass,
            nonce,
            signedAt,
            record
        );

        if (abandonedChild != bytes32(0)) {
            emit ArtistPayoutProvisionalChildAbandoned(
                1, p.artistId, abandonedChild, current.recordHash, dismissal
            );
        }
    }

    function _checkClosure(
        bytes32 artistId,
        R.TransitionState calldata transition,
        Dismissal.Closure memory closure_
    ) private pure returns (bool) {
        if (closure_.dismissalRecordHash == bytes32(0)) {
            Dismissal.Closure memory empty;
            if (keccak256(abi.encode(closure_)) != keccak256(abi.encode(empty))) {
                revert Dismissal.InvalidClosure(closure_.transitionRecordHash);
            }
            return false;
        }
        bool abandoned = transition.phase == 3
            || (transition.phase == 2
                && transition.contestedAt != 0
                && transition.contestedAt < transition.postWindowEndsAt);
        if (
            closure_.artistId != artistId || transition.artistId != artistId
                || closure_.transitionRecordHash != transition.recordHash || transition.phase != 2
                || transition.executedAt == 0
                || closure_.windowEndsAt != transition.postWindowEndsAt
                || closure_.contestedAt != transition.contestedAt || closure_.abandoned != abandoned
        ) revert Dismissal.InvalidClosure(closure_.transitionRecordHash);
        return true;
    }

    function recordDesignation(
        T.ActionContext calldata c,
        T.PayoutDesignation calldata p,
        address signer,
        uint256 nonce,
        uint64 signedAt
    ) external returns (bytes32 record) {
        _check(c, 18);
        if (_pending[p.artistId].recordHash != bytes32(0)) {
            revert R.PayoutRequiresAuthorityContext(p.artistId);
        }
        T.Payout storage current = _payouts[p.artistId];
        if (
            p.artistId == bytes32(0) || p.payoutAccount == address(0) || signer == address(0)
                || current.recordHash != p.previousDesignationRecordHash
                || current.account == p.payoutAccount
        ) {
            revert T.InvalidRecord();
        }
        record = StreamArtistHashes.payoutRecord(_environment(), p, signer, nonce, signedAt);
        bytes32 key = _replayKey(
            keccak256("payout_lifecycle.replay.designation_chain"),
            keccak256(abi.encode(p.artistId))
        );
        bytes32 prior = current.recordHash;
        _payouts[p.artistId] = T.Payout(p.payoutAccount, record);
        _records[record] = p;
        _replay[key] = T.ReplayCell(record, _revision + 1, 3, 1);
        StreamArtistAuthorityCheckpoint.noteReplay(key, _replay[key]);
        bytes32 recoveryAdmission = _noteRecoveryAdmission(p, record);
        _commit(
            c,
            keccak256(abi.encode(p, signer, nonce, signedAt)),
            _withRecoveryAdmission(
                keccak256("6529STREAM_ARTIST_PAYOUT_ADMISSION_STATE_V3"),
                keccak256(abi.encode(p.artistId, p.payoutAccount, record)),
                recoveryAdmission
            ),
            _withRecoveryAdmission(
                keccak256("6529STREAM_ARTIST_PAYOUT_ADMISSION_REPLAY_V3"),
                keccak256(abi.encode(key, prior, record)),
                recoveryAdmission
            ),
            record
        );
        _native(c.operationId, record, p.artistId, 0);
        emit ArtistPayoutDesignationRecorded(
            1, p.artistId, p.payoutAccount, signer, prior, 1, nonce, signedAt, record
        );
    }

    function _noteRecoveryAdmission(T.PayoutDesignation calldata p, bytes32 record)
        private
        returns (bytes32)
    {
        if (_recoveryRewind.continuationHeads[p.artistId] == bytes32(0)) return bytes32(0);
        return Rewind.noteAdmission(
            _recoveryRewind, _replay, _rewindEnvironment(), _revision, p, record
        );
    }

    function _withRecoveryAdmission(bytes32 tag, bytes32 original, bytes32 admission)
        private
        pure
        returns (bytes32)
    {
        return admission == bytes32(0)
            ? original
            : keccak256(abi.encode(tag, uint16(3), original, admission));
    }

    function _rewindEnvironment() private view returns (RewindTypes.EnvironmentV3 memory) {
        T.SuiteConfiguration memory suite =
            IStreamArtistSuiteReads(operationCoordinator).suiteConfiguration();
        return RewindEnvironment.fromFixed(
            suite.owners[2], artistRegistry, operationCoordinator, archiveV2, core, mintManager
        );
    }

    function authorityHydrationState(AH.Query calldata q)
        external
        view
        override
        returns (bytes memory)
    {
        return StreamArtistPayoutHydration.exportState(
            _payouts, _records, _pending, _associations, _abandonedUnder, q.artistId
        );
    }

    function _hydrateAuthority(AH.Query calldata q, AH.OwnerData calldata p) internal override {
        if (StreamArtistRecoveredHydrationCodec.isState(p.typedState, 5)) {
            if (_revision != 0 || p.nonces.length != 0) revert T.InvalidRecord();
            uint256[6] memory roots;
            assembly ("memory-safe") {
                mstore(roots, _payouts.slot)
                mstore(add(roots, 32), _records.slot)
                mstore(add(roots, 64), _pending.slot)
                mstore(add(roots, 96), _associations.slot)
                mstore(add(roots, 128), _abandonedUnder.slot)
                mstore(add(roots, 160), _recoveryRewind.slot)
            }
            StreamArtistRecoveredPayoutTransport.importEncoded(roots, msg.data);
            return;
        }
        if (p.nonces.length != 0) revert T.InvalidRecord();
        StreamArtistPayoutHydration.importState(_payouts, _records, q.artistId, p.typedState);
    }

    function _recoveredHydrationFeatures() internal pure override returns (uint256) {
        return StreamArtistRecoveredHydrationTypes.MULTIPLE_ATTESTATIONS_GRAPH_FEATURES;
    }

    function recoveredAuthorityHydrationState(
        AH.Query calldata,
        StreamArtistRecoveredHydrationTypes.OwnerProvenance calldata
    ) external view override returns (bytes memory) {
        return StreamArtistRecoveredPayoutTransport.exportEncoded(msg.data);
    }

    function recoveredHydrationAuxiliaryPoint(bytes32 kind, bytes32 key)
        external
        view
        override
        returns (StreamArtistRecoveredHydrationTypes.Point memory)
    {
        StreamArtistRecoveredHydrationTypes.OriginEnvironment memory current =
            StreamArtistRecoveredOwnerReads.environment(
                StreamArtistOwnerHydration.Binding(
                    artistRegistry, operationCoordinator, archiveV2, domainId
                ),
                5
            );
        return
            StreamArtistRecoveredPayoutTransport.auxiliaryPoint(_recoveryRewind, kind, key, current);
    }
}
