// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistOnboardingTypes.sol";

/// @notice Seven real typed artist operations for the primary-only first-sale profile.
/// @dev Payload fields and authorization envelope are grouped tuples; AA EIP712 payloads
///      and record preimages are unchanged. Unsupported full-v1 operations are absent.
interface IStreamArtistOnboarding {
    function proposeArtistBinding(
        uint256 collectionId,
        StreamArtistOnboardingTypes.BindingProposal calldata proposal,
        bytes calldata identityDocument,
        string calldata displayName
    ) external returns (bytes32 artistId, bytes32 bindingHash);
    function acceptArtistBinding(
        uint256 collectionId,
        StreamArtistOnboardingTypes.Authorization calldata authorization
    ) external returns (bytes32 recordHash);
    function recordPolicyConsent(
        StreamArtistOnboardingTypes.PolicyConsent calldata payload,
        StreamArtistOnboardingTypes.Authorization calldata authorization
    ) external returns (bytes32 recordHash);
    function recordEconomicsConsent(
        StreamArtistOnboardingTypes.EconomicsConsent calldata payload,
        StreamArtistOnboardingTypes.Authorization calldata authorization
    ) external returns (bytes32 recordHash);
    function recordPayoutDesignation(
        StreamArtistOnboardingTypes.PayoutDesignation calldata payload,
        StreamArtistOnboardingTypes.Authorization calldata authorization
    ) external returns (bytes32 recordHash);
    function recordArtistAttestation(
        StreamArtistOnboardingTypes.Attestation calldata payload,
        StreamArtistOnboardingTypes.Authorization calldata authorization,
        bytes calldata statementBytes
    ) external returns (bytes32 recordHash);
    function recordContentRatification(
        StreamArtistOnboardingTypes.Ratification calldata payload,
        StreamArtistOnboardingTypes.Authorization calldata authorization
    ) external returns (bytes32 recordHash);
}
