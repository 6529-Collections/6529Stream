// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";

/// @notice One additive Consent carrier shared by original ratification and sanction families.
/// @dev Empty supplements retain the exact original G.Consents bytes instead of this wrapper.
/// sanctionInventory is reserved for canonical abi.encode of the existing sanction H.Inventory,
/// validated by its fixed worker over the complete global catalogue, never a filtered certificate.
/// Only the selected fixed sanction worker admits nonempty inventory; ratification-only entries reject it.
library StreamArtistAggregateConsentSupplementTypes {
    bytes32 internal constant SCHEMA =
        keccak256("6529STREAM_ARTIST_AGGREGATE_CONSENT_SUPPLEMENT_V1");
    uint16 internal constant VERSION = RH.VERSION;

    struct Bundle {
        G.Consents original;
        T.RatificationRecord[] ratifications;
        bytes sanctionInventory;
    }
}
