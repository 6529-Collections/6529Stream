// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistCompleteHistoryConsentSupplementImport as CompleteSupplement } from "./StreamArtistCompleteHistoryConsentSupplementImport.sol";
import { StreamArtistRecoveredAggregateConsentSupplementWrites as SupplementWrites } from "./StreamArtistRecoveredAggregateConsentSupplementWrites.sol";

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
        // Complete History also validates empty original heads when both family bits are absent.
        if (CompleteSupplement.applyState(sanctions, current, records, anchor, outer)) return true;
        RH.Envelope memory e = Envelope.decode(outer, 6);
        if ((e.header.requiredFeatures & (RH.SANCTION_HISTORY | RH.RATIFICATIONS)) == 0) {
            return false;
        }
        (bool selected, M.State memory scope, Payload.Payload memory payload) =
            Aggregate.decode(anchor, outer);
        if (!selected) return false;
        Proof.validate(scope.rows, scope.collections, payload.provenance, outer);
        SupplementWrites.install(
            sanctions, current, records, scope,
            (e.header.requiredFeatures & RH.RATIFICATIONS) != 0,
            (e.header.requiredFeatures & RH.SANCTION_HISTORY) != 0
        );
        return true;
    }
}
