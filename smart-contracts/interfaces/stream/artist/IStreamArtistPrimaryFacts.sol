// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Canonical prospective fixed-profile assignment facts owned by the admitted primary resolver.
interface IStreamArtistPrimaryFacts {
    /// @notice Derives the exact collection-scope assignment hash using real factory profile data.
    /// @param collectionId Existing Core collection whose primary assignment is proposed.
    /// @param profileHash Existing immutable factory profile; never a caller-asserted entries hash.
    /// @param policyHash Must be zero in the supported fixed-profile mode.
    /// @param frozen Whether the resulting assignment is permanently frozen.
    /// @return fact Resolver, revenue class, scope and resulting canonical assignment hash.
    /// @dev This is a preview, not governance approval or permission to rewrite frozen state.
    function previewArtistPrimaryAssignment(
        uint256 collectionId,
        bytes32 profileHash,
        bytes32 policyHash,
        bool frozen
    ) external view returns (T.AssignmentFact memory fact);
}
