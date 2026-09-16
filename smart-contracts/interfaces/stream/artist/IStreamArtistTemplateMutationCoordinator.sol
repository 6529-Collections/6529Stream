// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Authenticated facade transport for explicit template freeze approval.
interface IStreamArtistTemplateMutationCoordinator {
    function coordinateRecordProspectiveTemplateFreezeConsent(
        address actor,
        T.EconomicsConsent calldata payload,
        T.Authorization calldata authorization
    ) external returns (bytes32 recordHash);
}
