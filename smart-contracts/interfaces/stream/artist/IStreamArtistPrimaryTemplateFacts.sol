// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Actual immutable primary-template facts for initial artist economics consent.
/// @dev This provider never records consent or resolves a payout account. Only COLLECTION_ARTIST
///      artist entries plus static nonartist entries and at least 500000 artist ppm are supported.
interface IStreamArtistPrimaryTemplateFacts {
    error UnsupportedArtistPrimaryTemplate(bytes32 templateId);

    /// @notice Reverts unless the actual stored template has the supported initial terms.
    function primaryTemplateEconomicsFacts(bytes32 templateId)
        external
        view
        returns (bytes32 entriesHash, bytes32 metadataURIHash, uint32 artistSharePpm);

    /// @notice Derives the exact canonical collection PRIMARY_SALE template assignment hash.
    /// @dev Policy must be zero. This preview grants no permission to mutate an artist-bound
    ///      or frozen assignment; prospective template writes remain unavailable.
    function previewArtistPrimaryTemplateAssignment(
        uint256 collectionId,
        bytes32 templateId,
        bytes32 policyHash,
        bool frozen
    ) external view returns (T.AssignmentFact memory fact);
}
