// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtworkFinalityTypes.sol";
import "./StreamFinalityEvidenceTypes.sol";

/// @notice Authoritative host seam used by constructor-fixed component-family adapters.
interface IStreamFinalityComponentFacts {
    function core() external view returns (address);

    /// @notice Derives the exact component-family facts from current host state for this scope.
    /// @dev Unknown families/scopes and incomplete applicable state revert. A request cannot
    ///      supply expected hashes, a replacement provider, a payload inventory or readiness.
    function finalityComponentFacts(bytes32 componentType, StreamFinalityScope calldata scope)
        external
        view
        returns (StreamFinalityHostComponentFacts memory facts);
}
