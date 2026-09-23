// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Stored primary-template terms for explicit artist consent.
/// @dev Separate from the initial >=500000 ppm capability. Supports a positive
///      COLLECTION_ARTIST share plus static nonartist rows, with no paid collaborators.
///      These structural reads neither consume nor require prior consent.
interface IStreamArtistPrimaryTemplateConsentFacts {
    function primaryTemplateConsentFacts(bytes32 templateId)
        external
        view
        returns (bytes32 entriesHash, bytes32 metadataURIHash, uint32 artistSharePpm);

    /// @notice Rebuilds the exact original collection PRIMARY_SALE assignment preimage.
    /// @dev Policy must be zero. Preview grants no mutation or freeze authority.
    function previewArtistPrimaryTemplateConsentAssignment(
        uint256 collectionId,
        bytes32 templateId,
        bytes32 policyHash,
        bool frozen
    ) external view returns (T.AssignmentFact memory fact);
}
