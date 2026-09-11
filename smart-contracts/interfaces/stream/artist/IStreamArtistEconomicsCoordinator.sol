// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistOnboardingTypes.sol";

/// @notice Authenticated facade transport for prospective fixed economics and defensive royalty rights.
interface IStreamArtistEconomicsCoordinator {
    function coordinateRecordProspectiveEconomicsConsent(
        address actor,
        StreamArtistOnboardingTypes.EconomicsConsent calldata payload,
        StreamArtistOnboardingTypes.FixedEconomicsCandidate calldata candidate,
        StreamArtistOnboardingTypes.Authorization calldata authorization
    ) external returns (bytes32 recordHash);

    function coordinateAuthorizeArtistRoyaltyFreeze(
        address actor,
        StreamArtistOnboardingTypes.RoyaltyFreeze calldata payload,
        StreamArtistOnboardingTypes.Authorization calldata authorization
    ) external returns (bytes32 recordHash);
}
