// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import { StreamArtistSaleTypes as Sale } from "./StreamArtistSaleTypes.sol";

/// @notice Original op14/op16 consent signed by a live scoped delegate in ARTIST_DELEGATED mode.
/// @dev Grant validity is checked when recording. The exact append-only consent survives later grant expiry/revocation/exhaustion.
interface IStreamArtistDelegatedConsent {
    function recordDelegatedPolicyConsent(
        T.PolicyConsent calldata p,
        bytes32 grant,
        T.Authorization calldata a
    ) external returns (bytes32);
    function recordDelegatedSaleConsent(
        Sale.Consent calldata p,
        bytes32 grant,
        T.Authorization calldata a
    ) external returns (bytes32);
}

interface IStreamArtistDelegatedConsentCoordinator {
    function coordinateRecordDelegatedPolicyConsent(
        address actor,
        T.PolicyConsent calldata p,
        bytes32 grant,
        T.Authorization calldata a
    ) external returns (bytes32);
    function coordinateRecordDelegatedSaleConsent(
        address actor,
        Sale.Consent calldata p,
        bytes32 grant,
        T.Authorization calldata a
    ) external returns (bytes32);
}

interface IStreamArtistDelegatedPolicySaleIdentityOwner {
    function consumeDelegatedPolicyConsent(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.PolicyConsent calldata p,
        bytes32 grant,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32);
    function consumeDelegatedSaleConsent(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Sale.Consent calldata p,
        bytes32 grant,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32);
}

interface IStreamArtistDelegatedPolicySaleConsentOwner {
    function recordDelegatedPolicyConsent(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.PolicyConsent calldata p,
        address signer,
        uint256 nonce,
        bytes32 grant
    ) external returns (bytes32);
    function recordDelegatedSaleConsent(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Sale.Consent calldata p,
        address signer,
        uint256 nonce,
        bytes32 grant
    ) external returns (bytes32);
}
