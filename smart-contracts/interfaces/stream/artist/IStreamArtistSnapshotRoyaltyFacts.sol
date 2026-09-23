// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes } from "./StreamArtistOnboardingTypes.sol";

/// @notice Explicit mode-bound collection royalty consent, separate from canonical royalty hashes.
interface IStreamArtistSnapshotRoyaltyFacts {
    /// @dev Unelected collections retain implicit live mode (1, zero election hash).
    function collectionRoyaltyMode(uint256 collectionId)
        external
        view
        returns (uint8 mode, bytes32 electionHash);

    /// @dev This first snapshot capability admits positive fixed collection SET only, frozen=false.
    function previewArtistSnapshotRoyaltyAssignment(
        uint256 collectionId,
        bytes32 profileHash,
        uint16 royaltyBps,
        bool frozen
    ) external view returns (StreamArtistOnboardingTypes.AssignmentFact memory);

    function currentArtistSnapshotRoyaltyAssignment(uint256 collectionId)
        external
        view
        returns (StreamArtistOnboardingTypes.AssignmentFact memory);
}
