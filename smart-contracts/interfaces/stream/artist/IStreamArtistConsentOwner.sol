// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamArtistOwner.sol";
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Typed ConsentFinalityLifecycle owner boundary for the seven-operation onboarding profile.
/// @dev Mutations require the immutable coordinator and exact pre-operation owner snapshot.
interface IStreamArtistConsentOwner is IStreamArtistOwner {
    function policyRecord(uint256 collectionId, bytes32 phaseId, bytes32 policyHash)
        external
        view
        returns (bytes32);

    function economicsRecord(T.EconomicsConsent calldata p) external view returns (bytes32);

    function firstReleaseRatification(uint256 collectionId)
        external
        view
        returns (T.RatificationRecord memory);

    function ratificationRecord(bytes32 record) external view returns (T.RatificationRecord memory);

    function royaltyFreezeRecord(T.RoyaltyFreeze calldata p, bytes32 artistId, uint64 generation)
        external
        view
        returns (T.RoyaltyFreezeRecord memory);

    function authorizeRoyaltyFreeze(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.RoyaltyFreeze calldata p,
        address signer,
        uint256 nonce
    ) external returns (bytes32 record);

    function recordPolicy(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.PolicyConsent calldata p,
        address signer,
        uint256 nonce
    ) external returns (bytes32 record);

    function recordEconomics(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.EconomicsConsent calldata p,
        T.Payout calldata designation,
        address signer,
        uint256 nonce
    ) external returns (bytes32 record);

    function recordRatification(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.Ratification calldata p,
        address signer,
        uint256 nonce
    ) external returns (bytes32 record);
}
