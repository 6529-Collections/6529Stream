// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact immutable archival evidence selected by a canonical finality action.
/// @dev Completion identifies original whole-artifact coverage. Execution separately validates
///      current coverage; no mutable newest-proof or validation-cache head selects the action.
struct StreamFinalitySanctionArchiveProof {
    bytes32 sanctionRecordHash;
    bytes32 artifactHash;
    bytes32 completionHash;
}

/// @notice Executed proof selection, separate from permanent signed finality record preimages.
struct StreamFinalitySanctionArchiveWitness {
    bytes32 evidenceHash;
    StreamFinalitySanctionArchiveProof proof;
}
