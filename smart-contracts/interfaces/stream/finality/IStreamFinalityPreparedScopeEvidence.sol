// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamFinalityScopeEvidence.sol";
import "./IStreamArtworkFinalityComponents.sol";

/// @notice Optional scope inputs after the original Registry's strict component validation.
/// @dev Only the constructor-pinned original Registry, at its exact runtime, may call this.
/// The Registry must have independently validated every complete component state and current
/// route during this call. The provider still validates current sources, archive coverage,
/// exact manifest bytes and current route identities. Public inputs perform their own checks.
interface IStreamFinalityPreparedScopeEvidence {
    function requirePreparedFinalityScopeInputs(
        StreamFinalityScope calldata scope,
        bytes32 manifestContentHash,
        StreamFinalityComponentExpectation[] calldata validatedComponents
    ) external view returns (StreamFinalityScopeInputs memory, bytes32, bytes32);
}
