// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Authenticated facade transport for the additive template consent capability.
interface IStreamArtistTemplateEconomicsCoordinator {
    function coordinateRecordProspectiveTemplateEconomicsConsent(
        address actor,
        T.EconomicsConsent calldata payload,
        bytes32 templateId,
        T.Authorization calldata authorization
    ) external returns (bytes32 recordHash);
}
