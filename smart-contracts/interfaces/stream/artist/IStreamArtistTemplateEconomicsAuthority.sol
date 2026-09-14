// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Explicit artist authorization of a prospective collection primary template.
/// @dev Uses the original operation-15 digest, nonce, payout and binding association.
///      The exact stored template is authorized with policy zero and frozen=false.
///      This set-only capability does not authorize template freeze or clear.
interface IStreamArtistTemplateEconomicsAuthority {
    function recordProspectiveTemplateEconomicsConsent(
        T.EconomicsConsent calldata payload,
        bytes32 templateId,
        T.Authorization calldata authorization
    ) external returns (bytes32 recordHash);
}
