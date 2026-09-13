// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

library StreamArtistAuthorizationTypes {
    struct Revocation {
        bytes32 artistId;
        bytes32 revokedDigest;
        uint256 revokedNonce;
    }

    struct State {
        bool digestObserved;
        bool digestRevoked;
        bool nonceConsumed;
        bool nonceRevoked;
        uint256 nextUnusedNonce;
    }
}

/// @notice Preventive cancellation by the actual identity authority, independent of mint readiness.
interface IStreamArtistAuthorizationRevocation {
    /// @dev Exactly one target is nonzero. Nonce zero must be targeted by its exact digest.
    function revokeArtistAuthorization(
        StreamArtistAuthorizationTypes.Revocation calldata p,
        T.Authorization calldata a
    ) external returns (bytes32);
    function authorizationRevocationDigest(
        StreamArtistAuthorizationTypes.Revocation calldata p,
        T.Authorization calldata a
    ) external view returns (bytes32);
    /// @notice Successful digest observation does not merge principal and delegate replay lanes.
    function artistAuthorizationState(bytes32 artistId, bytes32 digest, uint256 nonce)
        external
        view
        returns (StreamArtistAuthorizationTypes.State memory);
}

interface IStreamArtistAuthorizationCoordinator {
    function coordinateRevokeArtistAuthorization(
        address actor,
        StreamArtistAuthorizationTypes.Revocation calldata p,
        T.Authorization calldata a
    ) external returns (bytes32);
}

interface IStreamArtistAuthorizationOwner {
    function revokeAuthorization(
        T.ActionContext calldata c,
        StreamArtistAuthorizationTypes.Revocation calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32);
    function artistAuthorizationState(bytes32 artistId, bytes32 digest, uint256 nonce)
        external
        view
        returns (StreamArtistAuthorizationTypes.State memory);
}
