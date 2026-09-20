// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC165 } from "../../../vendor/openzeppelin/IERC165.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "./StreamArtistRecoveredHydrationTypes.sol";
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Additive operation60 transport for original content and royalty-freeze consent history.
/// @dev Royalty terms select exact original scope-keyed records in complete operation20 order.
/// They supply no authority. The original Request, entry point and interface id remain unchanged.
interface IStreamArtistRecoveredConsentHydration is IERC165 {
    function hydrateRecoveredArtistAuthorityWithConsents(
        RH.Request calldata request,
        T.RoyaltyFreeze[] calldata royaltyFreezes
    ) external returns (bytes32);
}

interface IStreamArtistRecoveredConsentHydrationCoordinator {
    function coordinateHydrateRecoveredArtistAuthorityWithConsents(
        address actor,
        RH.Request calldata request,
        T.RoyaltyFreeze[] calldata royaltyFreezes
    ) external returns (bytes32);
}
