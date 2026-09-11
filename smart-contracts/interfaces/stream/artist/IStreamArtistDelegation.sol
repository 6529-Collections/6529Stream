// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import { StreamArtistDelegationTypes as D } from "./StreamArtistDelegationTypes.sol";

/// @notice Artist grants and revokes scoped economics/freeze authority; delegates never gain payout or policy powers.
interface IStreamArtistDelegation {
    /// @notice Grant from the current artist, directly or by its signature; authorization.time must be zero.
    function grantArtistDelegation(D.Grant calldata p, T.Authorization calldata a)
        external
        returns (bytes32);
    /// @notice Revoke immediately using the exact stored grantor, directly or by its deadline-bearing signature.
    function revokeArtistDelegation(D.Revocation calldata p, T.Authorization calldata a)
        external
        returns (bytes32);
    function recordDelegatedEconomicsConsent(
        T.EconomicsConsent calldata p,
        bytes32 grant,
        T.Authorization calldata a
    ) external returns (bytes32);
    function recordDelegatedProspectiveEconomicsConsent(
        T.EconomicsConsent calldata p,
        T.FixedEconomicsCandidate calldata candidate,
        bytes32 grant,
        T.Authorization calldata a
    ) external returns (bytes32);
    function authorizeDelegatedRoyaltyFreeze(
        T.RoyaltyFreeze calldata p,
        bytes32 grant,
        T.Authorization calldata a
    ) external returns (bytes32);
    function delegationGrantDigest(D.Grant calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32);
    function delegationRevocationDigest(D.Revocation calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32);
    /// @notice Intrinsic window/revocation/exhaustion state; scope and capability are checked on each action.
    /// @dev Unlimited maxUses=0 reports uint64.max remaining. Time bounds are inclusive start, exclusive expiry.
    function delegationState(bytes32 grant)
        external
        view
        returns (
            bool active,
            address delegate,
            uint256 collectionId,
            uint32 capabilities,
            uint64 notBefore,
            uint64 expiresAt,
            uint64 usesRemaining
        );
    function delegationRecord(bytes32 grant) external view returns (D.Record memory);
    /// @notice Persistent delegate nonce lane across replacement grants; independent of the artist nonce lane.
    function delegatedNonceState(bytes32 artistId, address delegate, uint256 nonce)
        external
        view
        returns (bool used, uint256 nextUnused);
    /// @notice Exact grant authorizing a successful semantic record; revocation never erases historical evidence.
    function recordDelegation(bytes32 record) external view returns (bytes32);
}
