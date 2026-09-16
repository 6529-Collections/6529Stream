// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Target-side commitments prepared without requiring an executing action.
struct StreamFinalityExecutionContext {
    bytes32 scopeHash;
    bytes32 oldValueHash;
    bytes32 newValueHash;
    bytes32 finalityRecordHash;
    bytes32 coreFactsHash;
    bytes32 componentsHash;
    bytes32 inputsHash;
}

/// @notice Actual executing action and current proposer-role evidence, separate from permanent hashes.
struct StreamFinalityExecutionWitness {
    bytes32 actionId;
    address proposer;
    bytes32 reasonHash;
    bytes32 roleMutationHash;
    uint64 roleRevision;
}
