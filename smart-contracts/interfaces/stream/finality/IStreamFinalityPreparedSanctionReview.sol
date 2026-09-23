// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamFinalityPreparedScopeEvidence.sol";
import "./IStreamFinalitySanctionReview.sol";

/// @notice Scope inputs and original review images derived from the same current statement.
/// @dev Only the original Registry after its strict component/route checks may call this.
/// Current inventory, archival coverage and exact registered manifest are still mandatory.
interface IStreamFinalityPreparedSanctionReview {
    function requirePreparedFinalityScopeInputsAndReview(
        StreamFinalityScope calldata scope,
        bytes32 manifestContentHash,
        StreamFinalityComponentExpectation[] calldata validatedComponents
    )
        external
        view
        returns (
            StreamFinalityScopeInputs memory inputs,
            bytes32 schema,
            bytes32 canonicalization,
            IStreamFinalitySanctionReview.ReviewFacts memory review
        );
}
