// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Supported artist economics extensions without advertising the unfinished full authority API.
interface IStreamArtistEconomicsAuthority {
    /// @notice Records operation 15 consent to a canonical prospective fixed profile or exact primary key clear.
    /// @dev Primary collection/token clear uses assignmentHash zero and an entirely zero candidate.
    ///      Requires actual artist authorization and current typed payout facts; does not mutate a resolver.
    function recordProspectiveEconomicsConsent(
        T.EconomicsConsent calldata payload,
        T.FixedEconomicsCandidate calldata candidate,
        T.Authorization calldata authorization
    ) external returns (bytes32 consentRecordHash);

    /// @notice Records operation 20 authority to freeze only the exact current collection royalty assignment.
    /// @dev Defensive artist authorization does not require mint floors or governance approval.
    function authorizeArtistRoyaltyFreeze(
        T.RoyaltyFreeze calldata payload,
        T.Authorization calldata authorization
    ) external returns (bytes32 freezeRecordHash);

    /// @notice Returns the permanent AA StreamArtistRoyaltyFreeze EIP-712 digest for this registry and Core.
    function royaltyFreezeDigest(
        T.RoyaltyFreeze calldata payload,
        T.Authorization calldata authorization
    ) external view returns (bytes32);

    /// @notice Permanent AA read: whether the current binding authorizes freezing this exact royalty hash.
    /// @dev The resolver and ROYALTY_ERC2981 class are the registry's immutable admitted targets.
    function isRoyaltyFreezeAuthorized(uint256 collectionId, bytes32 expectedAssignmentHash)
        external
        view
        returns (bool);

    /// @notice Requires current-binding consent to the calling resolver's exact assignment or clear result.
    /// @dev Governance remains independently required. Static consent survives payout and authority changes
    ///      within the same binding; a corrected binding requires its own fresh association evidence.
    function requireEconomicsConsent(
        uint256 collectionId,
        bytes32 revenueClass,
        uint8 scope,
        uint256 scopeId,
        bytes32 assignmentHash
    ) external view;
}
