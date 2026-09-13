// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFinalityBoundedReads.sol";
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
}
