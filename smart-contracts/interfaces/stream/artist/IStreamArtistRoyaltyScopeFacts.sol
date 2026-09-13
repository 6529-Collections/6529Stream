// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import { IStreamRoyaltyResolver } from "../revenue/IStreamRoyaltyResolver.sol";

/// @notice Actual per-key and selected royalty facts for artist economics preparation.
/// @dev These reads do not record or consume artist consent. A configured disabled
///      royalty has a nonzero assignment hash; a missing or cleared key has hash zero.
interface IStreamArtistRoyaltyScopeFacts {
    function royaltyEconomicsFacts(uint256 collectionId, uint8 scope, uint256 scopeId)
        external
        view
        returns (T.AssignmentFact memory fact, IStreamRoyaltyResolver.RoyaltyConfig memory config);

    function previewArtistRoyaltyAssignmentForScope(
        uint256 collectionId,
        uint8 scope,
        uint256 scopeId,
        bytes32 profileHash,
        uint16 royaltyBps,
        bool frozen
    ) external view returns (T.AssignmentFact memory fact);

    function previewArtistRoyaltyClear(uint256 collectionId, uint8 scope, uint256 scopeId)
        external
        view
        returns (T.AssignmentFact memory fact, bytes32 previousAssignmentHash);

    /// @notice Selects token, collection, then default using actual retained Core identity.
    /// @dev The policy hash binds resolution context and the selected per-key assignment hash.
    function resolveRoyaltyAssignment(uint256 collectionId, uint256 tokenId)
        external
        view
        returns (
            T.AssignmentFact memory fact,
            IStreamRoyaltyResolver.RoyaltyConfig memory config,
            bytes32 royaltyPolicyHash
        );
}
