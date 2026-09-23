// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistOnboardingTypes.sol";

/// @notice Authenticated facade transport for the seven immutable onboarding recipes.
interface IStreamArtistOnboardingCoordinator {
    function coordinateProposeArtistBinding(
        address actor,
        uint256 collectionId,
        StreamArtistOnboardingTypes.BindingProposal calldata proposal,
        bytes calldata document,
        string calldata displayName
    ) external returns (bytes32 artistId, bytes32 bindingHash);
    function coordinateAcceptArtistBinding(
        address actor,
        uint256 collectionId,
        StreamArtistOnboardingTypes.Authorization calldata authorization
    ) external returns (bytes32 recordHash);
    function coordinateRecordPolicyConsent(
        address actor,
        StreamArtistOnboardingTypes.PolicyConsent calldata payload,
        StreamArtistOnboardingTypes.Authorization calldata authorization
    ) external returns (bytes32 recordHash);
    function coordinateRecordEconomicsConsent(
        address actor,
        StreamArtistOnboardingTypes.EconomicsConsent calldata payload,
        StreamArtistOnboardingTypes.Authorization calldata authorization
    ) external returns (bytes32 recordHash);
    function coordinateRecordPayoutDesignation(
        address actor,
        StreamArtistOnboardingTypes.PayoutDesignation calldata payload,
        StreamArtistOnboardingTypes.Authorization calldata authorization
    ) external returns (bytes32 recordHash);
    function coordinateRecordArtistAttestation(
        address actor,
        StreamArtistOnboardingTypes.Attestation calldata payload,
        StreamArtistOnboardingTypes.Authorization calldata authorization,
        bytes calldata statementBytes
    ) external returns (bytes32 recordHash);
    function coordinateRecordContentRatification(
        address actor,
        StreamArtistOnboardingTypes.Ratification calldata payload,
        StreamArtistOnboardingTypes.Authorization calldata authorization
    ) external returns (bytes32 recordHash);
}
