// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import { StreamArtistDelegationTypes as D } from "./StreamArtistDelegationTypes.sol";

/// @notice Exact delegation operation routes; the immutable facade supplies the original actor.
interface IStreamArtistDelegationCoordinator {
    function coordinateGrantArtistDelegation(
        address actor,
        D.Grant calldata p,
        T.Authorization calldata a
    ) external returns (bytes32);
    function coordinateRevokeArtistDelegation(
        address actor,
        D.Revocation calldata p,
        T.Authorization calldata a
    ) external returns (bytes32);
    function coordinateRecordDelegatedEconomicsConsent(
        address actor,
        T.EconomicsConsent calldata p,
        bytes32 grant,
        T.Authorization calldata a
    ) external returns (bytes32);
    function coordinateRecordDelegatedProspectiveEconomicsConsent(
        address actor,
        T.EconomicsConsent calldata p,
        T.FixedEconomicsCandidate calldata candidate,
        bytes32 grant,
        T.Authorization calldata a
    ) external returns (bytes32);
    function coordinateAuthorizeDelegatedRoyaltyFreeze(
        address actor,
        T.RoyaltyFreeze calldata p,
        bytes32 grant,
        T.Authorization calldata a
    ) external returns (bytes32);
}
