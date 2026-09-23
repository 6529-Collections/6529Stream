// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredAggregateConsentEnvelope as Aggregate
} from "./StreamArtistRecoveredAggregateConsentEnvelope.sol";
import {
    StreamArtistRecoveredAggregateSanctionConsentTransport as Transport
} from "./StreamArtistRecoveredAggregateSanctionConsentTransport.sol";
import {
    StreamArtistRecoveredSanctionCatalogue as Catalogue
} from "./StreamArtistRecoveredSanctionCatalogue.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredHydrationCodec as Envelope
} from "./StreamArtistRecoveredHydrationCodec.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

/// @notice Recheck the exact global original12/13 Archive inventory after the complete owner transaction.
library StreamArtistRecoveredAggregateSanctionCurrent {
    function requireCurrent(AH.Query memory anchor, RH.Provenance memory full, bytes memory outer)
        public
        view
        returns (bool)
    {
        (bool selected, M.State memory scope, Payload.Payload memory payload) =
            Aggregate.decode(anchor, outer);
        if (!selected) return false;
        RH.Envelope memory e = Envelope.decode(outer, 6);
        if ((e.header.requiredFeatures & RH.SANCTION_HISTORY) == 0) return false;
        if (
            keccak256(abi.encode(payload.provenance))
                != keccak256(abi.encode(RH.ownerProvenance(full, 6)))
        ) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        (,, H.Inventory memory history) = Transport.decode(
            scope.rows, (e.header.requiredFeatures & RH.RATIFICATIONS) != 0, true
        );
        Catalogue.requireCurrent(full, history.catalogues, history.operations);
        return true;
    }
}
