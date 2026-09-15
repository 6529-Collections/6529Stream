// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamFinalityRecoveryOwnerEvidence,
    StreamFinalityScope
} from "../../interfaces/stream/finality/IStreamFinalityRecoveryOwnerEvidence.sol";

/// @notice Bounded, canonical owner-evidence read with ADR0020's total error precedence.
/// @dev Only the owning companion supplies its fixed target/runtime/cap and its
///      independently validated current action, scope and staged manifest. This
///      helper does not establish notice authority or canonical action execution.
library StreamFinalityRecoveryOwnerReads {
    error FinalityRecoveryOwnerEvidenceUnreadable();
    error FinalityRecoveryOwnerEvidenceInvalid();
    error FinalityRecoveryOwnerNoticeOpen(uint64 ownerNoticeEndsAt);
    error FinalityRecoveryParentGas(uint256 available, uint256 required);

    struct Facts {
        bytes32 evidenceHash;
        uint64 revision;
        uint64 ownerNoticeEndsAt;
        uint32 acknowledgementCount;
        uint32 objectionCount;
    }

    function read(
        address ownerEvidence,
        bytes32 expectedCodeHash,
        uint256 readGas,
        StreamFinalityScope memory scope,
        bytes32 recoveryId,
        bytes32 manifestHash
    ) public view returns (Facts memory facts) {
        if (
            ownerEvidence.code.length == 0 || ownerEvidence.codehash != expectedCodeHash
                || readGas == 0 || readGas > type(uint256).max / 64
        ) revert FinalityRecoveryOwnerEvidenceUnreadable();
        bytes memory input = abi.encodeCall(
            IStreamFinalityRecoveryOwnerEvidence.verifyRecoveryOwnerEvidence,
            (scope, recoveryId, manifestHash)
        );
        uint256 required = readGas + readGas / 63 + 100000;
        if (gasleft() <= required) revert FinalityRecoveryParentGas(gasleft(), required);
        uint256[6] memory words;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(readGas, ownerEvidence, add(input, 32), mload(input), words, 192)
            size := returndatasize()
        }
        if (
            !ok || size != 192 || words[0] > 1 || words[2] > type(uint64).max
                || words[3] > type(uint64).max || words[4] > type(uint32).max
                || words[5] > type(uint32).max
        ) revert FinalityRecoveryOwnerEvidenceUnreadable();
        if (words[1] == 0 || words[2] == 0 || words[3] == 0) {
            revert FinalityRecoveryOwnerEvidenceInvalid();
        }
        if (words[3] > block.timestamp) {
            revert FinalityRecoveryOwnerNoticeOpen(uint64(words[3]));
        }
        if (words[0] == 0) revert FinalityRecoveryOwnerEvidenceInvalid();
        return Facts(
            bytes32(words[1]),
            uint64(words[2]),
            uint64(words[3]),
            uint32(words[4]),
            uint32(words[5])
        );
    }
}
