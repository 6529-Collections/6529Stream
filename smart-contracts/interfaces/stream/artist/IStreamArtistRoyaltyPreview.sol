// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Canonical prospective royalty facts, separate from the existing live-assignment capability.
interface IStreamArtistRoyaltyPreview {
    /// @notice Derives the exact collection royalty assignment hash from real factory profile data.
    /// @param collectionId Existing Core collection whose royalty assignment is proposed.
    /// @param profileHash Existing immutable factory profile that receives the royalty.
    /// @param royaltyBps Royalty rate in basis points, admitted under the resolver's existing limits.
    /// @param frozen Whether the resulting assignment is permanently frozen.
    /// @return fact Admitted resolver, ROYALTY_ERC2981 class, scope and canonical assignment hash.
    /// @dev Policy hash is zero in this profile. The preview grants no authority to mutate state.
    function previewArtistRoyaltyAssignment(
        uint256 collectionId,
        bytes32 profileHash,
        uint16 royaltyBps,
        bool frozen
    ) external view returns (T.AssignmentFact memory fact);
}
