// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamArtistOwner.sol";
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Typed IdentityAuthority owner boundary for the seven-operation onboarding profile.
/// @dev Mutations require the immutable coordinator and exact pre-operation owner snapshot.
interface IStreamArtistIdentityOwner is IStreamArtistOwner {
    /// @notice Fixed-size operative authority facts for capped mint and consent reads.
    /// @dev Canonical document bytes and mirrors remain available through identity/document reads.
    function authorityState(bytes32 artistId)
        external
        view
        returns (
            address authorityAddress,
            uint8 authorityClass,
            uint8 status,
            bytes32 identityRecordHash
        );
    function nextRegistrationNonce() external view returns (uint256);

    function activeIdentity(address account) external view returns (bytes32);

    function identity(bytes32 artistId) external view returns (T.Identity memory);

    function identityDocumentBytes(bytes32 documentHash) external view returns (bytes memory);

    function signatureBundle(bytes32 recordHash) external view returns (bytes memory);

    function nonceUsed(bytes32 artistId, uint256 nonce) external view returns (bool);

    function registerIdentity(
        T.ActionContext calldata c,
        address artist,
        bytes32 documentHash,
        string calldata uri,
        bytes calldata document,
        string calldata displayName
    ) external returns (bytes32 artistId);

    function consumeAcceptance(
        T.ActionContext calldata c,
        uint256 collectionId,
        T.Binding calldata b,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record);

    function consumePolicy(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.PolicyConsent calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record);

    function consumeEconomics(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.EconomicsConsent calldata p,
        bytes32 designation,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record);

    function consumePayout(
        T.ActionContext calldata c,
        T.PayoutDesignation calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record);

    function consumeAttestation(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.Attestation calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record);

    function consumeRatification(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.Ratification calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record);
}
