// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredAggregateSanctionConsentTransport as Transport
} from "./StreamArtistRecoveredAggregateSanctionConsentTransport.sol";
import {
    StreamArtistRecoveredAggregateSanctionLocalProof as Local
} from "./StreamArtistRecoveredAggregateSanctionLocalProof.sol";
import {
    StreamArtistRecoveredMultipleGenerationConsentValidation as Validation
} from "./StreamArtistRecoveredMultipleGenerationConsentValidation.sol";
import {
    StreamArtistRecoveredAggregateRatificationRows as Ratifications
} from "./StreamArtistRecoveredAggregateRatificationRows.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredHydrationCodec as Envelope
} from "./StreamArtistRecoveredHydrationCodec.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

/// @notice Shared complete owner6 validation for G, MD and PC with additive original12/13/52.
library StreamArtistRecoveredAggregateConsentProof {
    function validate(
        bytes[] memory rows,
        AH.Query[] memory queries,
        RH.OwnerProvenance memory p,
        bytes memory outer
    ) public view returns (G.Consents[] memory original) {
        RH.Envelope memory e = Envelope.decode(outer, 6);
        bool sanctioned = (e.header.requiredFeatures & RH.SANCTION_HISTORY) != 0;
        T.RatificationRecord[][] memory ratifications;
        if (!sanctioned) {
            (original, ratifications) = Ratifications.decodeOwnerRows(rows, outer);
            Validation.validate(original, ratifications, queries, p);
            return original;
        }
        H.Inventory memory history;
        (original, ratifications, history) =
            Transport.decode(rows, (e.header.requiredFeatures & RH.RATIFICATIONS) != 0, true);
        Local.validate(p, 6, queries, history);
        Validation.validate(original, ratifications, queries, p, Transport.facts(history));
    }
}
