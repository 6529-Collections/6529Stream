// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredAggregateConsentEnvelope as Aggregate
} from "./StreamArtistRecoveredAggregateConsentEnvelope.sol";
import {
    StreamArtistRecoveredAggregateConsentProof as Proof
} from "./StreamArtistRecoveredAggregateConsentProof.sol";
import {
    StreamArtistRecoveredAggregateSanctionConsentTransport as Transport
} from "./StreamArtistRecoveredAggregateSanctionConsentTransport.sol";
import {
    StreamArtistRecoveredAggregateSanctionStorage as Storage
} from "./StreamArtistRecoveredAggregateSanctionStorage.sol";
import {
    StreamArtistRecoveredHistoryContentWrites as Writes
} from "./StreamArtistRecoveredHistoryContentWrites.sol";
import {
    StreamArtistRecoveredHydrationCodec as Envelope
} from "./StreamArtistRecoveredHydrationCodec.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import { StreamArtistSanctionState as Sanctions } from "./StreamArtistSanctionState.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice One fixed additive original12/52 storage worker inside the owner's existing op60 guard.
/// @dev Three existing storage references only. The following existing aggregate import installs
/// base/content rows in the same transaction; any failure rolls back every supplement write.
library StreamArtistRecoveredAggregateConsentSupplementImport {
    function applyState(
        Sanctions.State storage sanctions,
        mapping(uint256 => T.RatificationRecord) storage current,
        mapping(
            bytes32 => T.RatificationRecord
        ) storage records,
        AH.Query memory anchor,
        bytes memory outer
    ) public returns (bool) {
        RH.Envelope memory e = Envelope.decode(outer, 6);
        if ((e.header.requiredFeatures & (RH.SANCTION_HISTORY | RH.RATIFICATIONS)) == 0) {
            return false;
        }
        (bool selected, M.State memory scope, Payload.Payload memory payload) =
            Aggregate.decode(anchor, outer);
        if (!selected) return false;
        Proof.validate(scope.rows, scope.collections, payload.provenance, outer);
        (, T.RatificationRecord[][] memory ratifications, H.Inventory memory history) = Transport.decode(
            scope.rows,
            (e.header.requiredFeatures & RH.RATIFICATIONS) != 0,
            (e.header.requiredFeatures & RH.SANCTION_HISTORY) != 0
        );
        if (history.sanctions.length != 0) Storage.install(sanctions, history);
        for (uint256 i; i < scope.collections.length; ++i) {
            Writes.importRecords(
                current, records, scope.collections[i].collectionId, ratifications[i]
            );
        }
        return true;
    }
}
