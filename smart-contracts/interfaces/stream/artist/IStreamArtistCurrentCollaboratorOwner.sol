// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistCollaboratorTypes.sol";
import "./StreamArtistRotationTypes.sol";
import "./StreamArtistOnboardingTypes.sol";

interface IStreamArtistCurrentCollaboratorAcceptanceOwner {
    function recordCollaboratorAcceptanceWithAuthority(
        StreamArtistOnboardingTypes.ActionContext calldata c,
        StreamArtistCollaboratorTypes.BindingAcceptance calldata p,
        bytes32 artistId,
        uint256 nonce,
        StreamArtistRotationTypes.AuthorityFact calldata authority
    ) external returns (bytes32);
}

interface IStreamArtistCurrentCollaboratorAttributionOwner {
    function completeCollaboratorBindingWithAuthority(
        StreamArtistOnboardingTypes.ActionContext calldata c,
        uint256 collectionId,
        StreamArtistOnboardingTypes.Binding calldata b,
        bytes32 record,
        address signer,
        StreamArtistRotationTypes.AuthorityFact calldata authority
    ) external;
}
