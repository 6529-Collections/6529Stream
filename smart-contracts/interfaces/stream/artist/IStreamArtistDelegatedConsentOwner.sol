// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Typed Consent-owner records after the Coordinator atomically consumes Identity's delegation authority.
interface IStreamArtistDelegatedConsentOwner {
    function recordDelegation(bytes32 record) external view returns (bytes32);
    function recordDelegatedEconomics(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.EconomicsConsent calldata p,
        T.Payout calldata payout,
        address signer,
        uint256 nonce,
        bytes32 grant
    ) external returns (bytes32);
    function authorizeDelegatedRoyaltyFreeze(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.RoyaltyFreeze calldata p,
        address signer,
        uint256 nonce,
        bytes32 grant
    ) external returns (bytes32);
}
