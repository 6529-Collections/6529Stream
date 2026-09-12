// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import { StreamArtistBindingLifecycleTypes as L } from "./StreamArtistBindingLifecycleTypes.sol";
import { StreamArtistRotationTypes as R } from "./StreamArtistRotationTypes.sol";

/// @notice Typed Coordinator snapshots of current authority, separate from historical binding terms.
interface IStreamArtistCurrentAcceptanceOwner {
    function recordAcceptanceWithAuthority(
        T.ActionContext calldata c,
        uint256 collectionId,
        T.Binding calldata b,
        R.AuthorityFact calldata authority,
        address signer,
        uint256 nonce
    ) external returns (bytes32);
}

interface IStreamArtistCurrentBindingOwner {
    function refuseWithAuthority(
        T.ActionContext calldata c,
        L.Termination calldata p,
        R.AuthorityFact calldata authority,
        address signer,
        uint256 nonce
    ) external returns (bytes32);
}

interface IStreamArtistCurrentAttributionOwner {
    function recordRefusalWithAuthority(
        T.ActionContext calldata c,
        T.Binding calldata b,
        L.Termination calldata p,
        R.AuthorityFact calldata authority,
        address signer,
        uint256 nonce,
        bytes32 record
    ) external;

    function acceptWithAuthority(
        T.ActionContext calldata c,
        uint256 collectionId,
        T.Binding calldata b,
        bytes32 record,
        R.AuthorityFact calldata authority
    ) external;

    function recordAttestationWithAuthority(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.Attestation calldata p,
        bytes32 operativeIdentityHash,
        R.AuthorityFact calldata authority,
        address signer,
        uint256 nonce,
        uint64 signedAt,
        bytes calldata statement
    ) external returns (bytes32);
}
