// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistOnboardingTypes.sol";

/// @notice Canonical live royalty-assignment evidence supplied by the actual selected resolver.
interface IStreamArtistRoyaltyFacts {
    /// @notice Returns the source-owned RSR assignment hash, including pointer policy and bps.
    /// @dev This is an assignment read, never an operator-supplied readiness assertion.
    function currentArtistRoyaltyAssignment(uint256 collectionId)
        external
        view
        returns (StreamArtistOnboardingTypes.AssignmentFact memory);
}
