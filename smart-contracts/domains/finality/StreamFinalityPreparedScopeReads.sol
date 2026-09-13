// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFinalityBoundedReads.sol";
import "./StreamFinalitySanctionReviewReads.sol";
import "../../interfaces/stream/finality/IStreamFinalityPreparedSanctionReview.sol";
import "../../interfaces/stream/finality/IStreamFinalityPreparedScopeEvidence.sol";

/// @notice Optional prepared dispatch, used only after Registry live-state and route validation.
library StreamFinalityPreparedScopeReads {
    function read(
        address provider,
        StreamFinalityScope memory scope,
        bytes32 manifestHash,
        StreamFinalityComponentExpectation[] calldata validatedComponents,
        uint256 cap
    ) public view returns (bytes memory) {
        bytes memory input;
        if (StreamFinalityBoundedReads.supportsOptional(
                provider, type(IStreamFinalityPreparedScopeEvidence).interfaceId, cap
            )) {
            input = abi.encodeCall(
                IStreamFinalityPreparedScopeEvidence.requirePreparedFinalityScopeInputs,
                (scope, manifestHash, validatedComponents)
            );
        } else {
            input = abi.encodeCall(
                IStreamFinalityScopeEvidence.requireFinalityScopeInputs, (scope, manifestHash)
            );
        }
        return StreamFinalityBoundedReads.read(provider, input, 384, cap);
    }

    /// @dev An advertised combined-provider failure is terminal. Older providers keep both reads.
    function readWithReview(
        address provider,
        StreamFinalityScope memory scope,
        bytes32 manifestHash,
        StreamFinalityComponentExpectation[] calldata validatedComponents,
        uint256 cap
    )
        public
        view
        returns (bytes memory inputs, IStreamFinalitySanctionReview.ReviewFacts memory review)
    {
        if (StreamFinalityBoundedReads.supportsOptional(
                    provider, type(IStreamFinalityPreparedSanctionReview).interfaceId, cap
                )) {
            bytes memory raw = StreamFinalitySanctionReviewReads.read(
                provider,
                abi.encodeCall(
                    IStreamFinalityPreparedSanctionReview.requirePreparedFinalityScopeInputsAndReview,
                    (scope, manifestHash, validatedComponents)
                ),
                1152,
                cap
            );
            review = StreamFinalitySanctionReviewReads.review(raw, 416);
            (StreamFinalityScopeInputs memory facts, bytes32 schema, bytes32 canon) =
                abi.decode(raw, (StreamFinalityScopeInputs, bytes32, bytes32));
            inputs = abi.encode(facts, schema, canon);
        } else {
            inputs = read(provider, scope, manifestHash, validatedComponents, cap);
            bytes memory raw = StreamFinalitySanctionReviewReads.read(
                provider,
                abi.encodeCall(
                    IStreamFinalitySanctionReview.requireSanctionReviewFacts, (scope, manifestHash)
                ),
                768,
                cap
            );
            review = StreamFinalitySanctionReviewReads.review(raw, 32);
        }
    }
}
