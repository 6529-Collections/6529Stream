// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Original operation15 approval of the exact frozen hash of an installed collection/token TEMPLATE.
/// @dev Does not mutate the Resolver or change existing SET-only signature domains/interfaces.
interface IStreamArtistTemplateMutationAuthority {
    function recordProspectiveTemplateFreezeConsent(
        T.EconomicsConsent calldata payload,
        T.Authorization calldata authorization
    ) external returns (bytes32 consentRecordHash);
}
