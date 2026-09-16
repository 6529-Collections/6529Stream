// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import { IStreamRevenueResolver } from "../revenue/IStreamRevenueResolver.sol";

/// @notice Actual primary per-key facts and fixed-profile previews for artist economics consent.
/// @dev These reads validate the canonical Core mapping and immutable provider pins.
///      They never consume consent, resolve payout accounts, or authorize a mutation.
interface IStreamArtistPrimaryScopeFacts {
    /// @notice Reads the exact default, collection or token storage key, without ancestor fallback.
    /// @dev A missing key returns exists=false; it never represents an inherited assignment.
    function primaryEconomicsFacts(uint256 collectionId, uint8 scope, uint256 scopeId)
        external
        view
        returns (IStreamRevenueResolver.ResolvedPrimaryAssignment memory);

    /// @notice Derives the canonical PRIMARY_SALE hash from a real immutable factory profile.
    function previewArtistPrimaryAssignmentForScope(
        uint256 collectionId,
        uint8 scope,
        uint256 scopeId,
        bytes32 profileHash,
        bytes32 policyHash,
        bool frozen
    ) external view returns (T.AssignmentFact memory);

    /// @notice Previews removal of an existing mutable collection/token PROFILE key.
    /// @dev Resulting per-key hash is zero; previousHash is the actual stored hash.
    ///      Neither field substitutes for consent to the separately selected ancestor.
    function previewArtistPrimaryClear(uint256 collectionId, uint8 scope, uint256 scopeId)
        external
        view
        returns (T.AssignmentFact memory fact, bytes32 previousHash);
}
