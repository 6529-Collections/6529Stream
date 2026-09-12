// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistOwner.sol";
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

    function designationRecord(bytes32 record) external view returns (T.PayoutDesignation memory) {
        return _records[record];
    }

    function payoutDesignationProvisionalAssociation(bytes32 record)
        external
        view
        returns (R.ProvisionalAssociation memory)
    {
        return _associations[record];
    }

    function payoutCandidates(bytes32 artistId)
        external
        view
        returns (
            T.Payout memory stable,
            T.Payout memory candidate,
            R.ProvisionalAssociation memory association
        )
    {
        stable = _payouts[artistId];
        candidate = _pending[artistId];
        association = _associations[candidate.recordHash];
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
            c, p, signer, nonce, signedAt, currentTransition, candidateTransition, none, false
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
            c, p, signer, nonce, signedAt, currentTransition, candidateTransition, resolution, true
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
        bool modern
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
        record = StreamArtistHashes.payoutRecord(_environment(), p, signer, nonce, signedAt);
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
                        p.artistId, _payouts[p.artistId], _pending[p.artistId], association, record
                    )
                ),
            keccak256(abi.encode(key, current.recordHash, record)),
            record
        );
        emit ArtistPayoutDesignationRecorded(
            1, p.artistId, p.payoutAccount, signer, current.recordHash, 1, nonce, signedAt, record
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
        _commit(
            c,
            keccak256(abi.encode(p, signer, nonce, signedAt)),
            keccak256(abi.encode(p.artistId, p.payoutAccount, record)),
            keccak256(abi.encode(key, prior, record)),
            record
        );
        emit ArtistPayoutDesignationRecorded(
            1, p.artistId, p.payoutAccount, signer, prior, 1, nonce, signedAt, record
        );
    }
}
