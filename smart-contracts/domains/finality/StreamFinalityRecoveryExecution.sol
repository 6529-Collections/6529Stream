// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamFinalityRecoveryBindings.sol";
import "./StreamFinalityRecoveryOwnerReads.sol";
import "../../interfaces/stream/artist/IStreamArtistRecoveryApproval.sol";
import "../../interfaces/stream/artist/IStreamArtistUnavailability.sol";
import "../../interfaces/stream/finality/IStreamArtistRecoveryIntent.sol";
import "../../interfaces/stream/finality/StreamFinalityRecoveryTypes.sol";
import "../../interfaces/stream/governance/IStreamGovernanceReads.sol";

/// @notice Exact active Executor context and separately snapshotted recovery evidence.
/// @dev Fixed companion supplies all pins and independently prepared commitments. Saved execution
///      never repeats these current evidence reads; no role/signature is fabricated by this helper.
library StreamFinalityRecoveryExecution {
    error FinalityRecoveryExecutionContextMissing();
    error FinalityRecoveryActionClassInvalid(uint8 actionClass);
    error FinalityRecoveryTransitionContextMismatch();
    error FinalityRecoveryArtistEvidenceUnreadable();
    error FinalityRecoveryArtistEvidenceInvalid();
    error FinalityRecoveryUnavailabilityNoticeOpen(uint64 noticeEndsAt);

    function context(
        StreamFinalityRecoveryBindings.Bound memory b,
        IStreamArtistRecoveryIntent.Facts memory facts
    ) public view returns (bytes32 id) {
        bytes memory raw = StreamFinalityRecoveryBindings.fixedRead(
            b.inputs.executor,
            abi.encodeCall(IStreamGovernanceReads.currentAction, ()),
            192,
            b.inputs.readGas
        );
        uint256 flag = _word(raw, 0);
        uint256 actionClass = _word(raw, 2);
        if (flag > 1 || actionClass > type(uint8).max) {
            revert FinalityRecoveryTransitionContextMismatch();
        }
        id = bytes32(_word(raw, 1));
        if (flag == 0 || id == 0) revert FinalityRecoveryExecutionContextMissing();
        if (actionClass != 2) revert FinalityRecoveryActionClassInvalid(uint8(actionClass));
        if (
            bytes32(_word(raw, 3)) != facts.scopeHash
                || bytes32(_word(raw, 4)) != facts.oldValueHash
                || bytes32(_word(raw, 5)) != facts.newValueHash
        ) revert FinalityRecoveryTransitionContextMismatch();
    }

    function evidence(
        StreamFinalityRecoveryBindings.Bound memory b,
        StreamFinalityRecoveryRequest memory request,
        bytes32 actionId,
        bytes32 originalArtistId,
        uint256 artistCap,
        uint256 ownerCap
    ) public view returns (StreamFinalityRecoveryEvidenceSnapshot memory e) {
        bytes memory raw = _artist(
            b.inputs.artist,
            abi.encodeCall(
                IStreamArtistRecoveryApproval.verifyRecoveryApproval,
                (
                    request.scope.collectionId,
                    request.expectedOriginalFinalityRecordHash,
                    request.recoveryManifest.contentHash
                )
            ),
            artistCap
        );
        if (_word(raw, 0) > 1 || _word(raw, 2) >> 160 != 0 || _word(raw, 3) > type(uint8).max) {
            revert FinalityRecoveryArtistEvidenceUnreadable();
        }
        if (_word(raw, 0) == 1) {
            if (
                _word(raw, 1) == 0 || _word(raw, 2) == 0
                    || (_word(raw, 3) != 1 && _word(raw, 3) != 3) || originalArtistId == 0
            ) revert FinalityRecoveryArtistEvidenceInvalid();
            e.artistEvidenceKind = StreamFinalityRecoveryArtistEvidenceKind.APPROVAL;
            e.artistEvidenceHash = bytes32(_word(raw, 1));
            e.artistSigner = address(uint160(_word(raw, 2)));
            e.artistAuthorityClass = uint8(_word(raw, 3));
            e.artistId = originalArtistId;
        } else {
            U.Target memory target = U.Target(
                address(this),
                actionId,
                request.scope,
                request.expectedOriginalFinalityRecordHash,
                request.recoveryManifest.contentHash
            );
            raw = _artist(
                b.inputs.artist,
                abi.encodeCall(IStreamArtistUnavailability.verifyRecoveryUnavailability, (target)),
                artistCap
            );
            if (_word(raw, 0) > 1 || _word(raw, 3) > type(uint64).max) {
                revert FinalityRecoveryArtistEvidenceUnreadable();
            }
            uint64 notice = uint64(_word(raw, 3));
            if (
                _word(raw, 1) == 0 || _word(raw, 2) == 0
                    || bytes32(_word(raw, 2)) != originalArtistId || notice == 0
            ) revert FinalityRecoveryArtistEvidenceInvalid();
            if (notice > block.timestamp) revert FinalityRecoveryUnavailabilityNoticeOpen(notice);
            if (_word(raw, 0) == 0) revert FinalityRecoveryArtistEvidenceInvalid();
            e.artistEvidenceKind = StreamFinalityRecoveryArtistEvidenceKind.UNAVAILABILITY;
            e.artistEvidenceHash = bytes32(_word(raw, 1));
            e.artistId = bytes32(_word(raw, 2));
            e.artistNoticeEndsAt = notice;
        }
        StreamFinalityRecoveryOwnerReads.Facts memory owner = StreamFinalityRecoveryOwnerReads.read(
            b.inputs.ownerEvidence,
            b.codeHashes[6],
            ownerCap,
            request.scope,
            actionId,
            request.recoveryManifest.contentHash
        );
        e.ownerEvidenceHash = owner.evidenceHash;
        e.ownerEvidenceRevision = owner.revision;
        e.ownerNoticeEndsAt = owner.ownerNoticeEndsAt;
        e.ownerAcknowledgementCount = owner.acknowledgementCount;
        e.ownerObjectionCount = owner.objectionCount;
    }

    function _artist(address target, bytes memory input, uint256 cap)
        private
        view
        returns (bytes memory raw)
    {
        if (cap == 0 || cap > type(uint256).max / 64) {
            revert FinalityRecoveryArtistEvidenceUnreadable();
        }
        raw = new bytes(128);
        bool ok;
        uint256 size;
        uint256 required = cap + cap / 63 + 100000;
        if (gasleft() <= required) {
            revert StreamFinalityRecoveryBindings.FinalityRecoveryParentGas(gasleft(), required);
        }
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(raw, 32), 128)
            size := returndatasize()
        }
        if (!ok || size != 128) revert FinalityRecoveryArtistEvidenceUnreadable();
    }

    function _word(bytes memory raw, uint256 index) private pure returns (uint256 value) {
        assembly ("memory-safe") { value := mload(add(add(raw, 32), mul(index, 32))) }
    }
}
