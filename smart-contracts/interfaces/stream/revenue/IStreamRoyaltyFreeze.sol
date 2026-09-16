// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Permissionless application of an artist's exact, current royalty-freeze authorization.
interface IStreamRoyaltyFreeze {
    error ArtistRoyaltyFreezeNotAuthorized(uint256 collectionId, bytes32 assignmentHash);
    error ArtistRoyaltyAssignmentChanged(uint256 collectionId, bytes32 expected, bytes32 actual);

    /// @notice Permanently freezes the explicit collection assignment authorized by its artist.
    /// @dev Changes neither the profile nor the royalty rate. A later mint still needs economics
    ///      consent to the resulting frozen assignment hash; freeze authority does not supply it.
    function applyArtistRoyaltyFreeze(uint256 collectionId, bytes32 expectedAssignmentHash) external;
}
