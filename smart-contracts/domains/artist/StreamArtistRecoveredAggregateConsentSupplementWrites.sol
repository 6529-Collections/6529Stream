// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import { StreamArtistSanctionState as Sanctions } from "./StreamArtistSanctionState.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Fixed post-validation original12/52 supplement writes.
library StreamArtistRecoveredAggregateConsentSupplementWrites {
    function install(
        Sanctions.State storage sanctions,
        mapping(uint256 => T.RatificationRecord) storage current,
        mapping(bytes32 => T.RatificationRecord) storage records,
        M.State memory scope,
        bool ratificationsSelected,
        bool historySelected
    ) public {
        (, T.RatificationRecord[][] memory ratifications, H.Inventory memory history) = Transport.decode(
            scope.rows, ratificationsSelected, historySelected
        );
        if (history.sanctions.length != 0) Storage.install(sanctions, history);
        for (uint256 i; i < scope.collections.length; ++i) {
            Writes.importRecords(
                current, records, scope.collections[i].collectionId, ratifications[i]
            );
        }
    }
}
