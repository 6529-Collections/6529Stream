// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistAggregateConsentSupplementTypes as S
} from "./StreamArtistAggregateConsentSupplementTypes.sol";
import {
    StreamArtistAggregateSanctionConsentTypes as F
} from "./StreamArtistAggregateSanctionConsentTypes.sol";
import {
    StreamArtistRecoveredAggregateRatificationRows as Rows
} from "./StreamArtistRecoveredAggregateRatificationRows.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice One canonical global sanction inventory in the first row of the shared Consent supplement.
/// @dev Row zero is only the carrier: its collection does not own or replace the global certificate.
/// All other rows retain their original or ratification-only bytes. No inventory is copied per collection.
library StreamArtistRecoveredAggregateSanctionConsentTransport {
    function encode(bytes[] memory rows, H.Inventory memory history)
        public
        pure
        returns (bytes[] memory)
    {
        if (rows.length == 0 || rows.length > 128 || history.sanctions.length == 0) _invalid();
        for (uint256 i; i < rows.length; ++i) {
            S.Bundle memory row = Rows.decodeSupplement(rows[i]);
            if (row.sanctionInventory.length != 0) _invalid();
            if (i == 0) {
                row.sanctionInventory = abi.encode(history);
                rows[i] = Rows.encodeSupplement(row);
            }
        }
        return rows;
    }

    function decode(bytes[] memory rows, bool ratificationsRequired, bool sanctionsRequired)
        public
        pure
        returns (
            G.Consents[] memory original,
            T.RatificationRecord[][] memory ratifications,
            H.Inventory memory history
        )
    {
        if (rows.length == 0 || rows.length > 128) _invalid();
        original = new G.Consents[](rows.length);
        ratifications = new T.RatificationRecord[][](rows.length);
        bool ratified;
        bool sanctioned;
        for (uint256 i; i < rows.length; ++i) {
            S.Bundle memory row = Rows.decodeSupplement(rows[i]);
            original[i] = row.original;
            ratifications[i] = row.ratifications;
            if (row.ratifications.length != 0) ratified = true;
            if (row.sanctionInventory.length == 0) continue;
            if (i != 0 || sanctioned) _invalid();
            history = abi.decode(row.sanctionInventory, (H.Inventory));
            if (
                history.sanctions.length == 0 || history.operations.length == 0
                    || history.catalogues.length == 0
                    || keccak256(row.sanctionInventory) != keccak256(abi.encode(history))
            ) _invalid();
            sanctioned = true;
        }
        if (ratified != ratificationsRequired || sanctioned != sanctionsRequired) _invalid();
    }

    function facts(H.Inventory memory history) public pure returns (F.Facts memory result) {
        result.sanctions = new F.Record[](history.sanctions.length);
        for (uint256 i; i < result.sanctions.length; ++i) {
            result.sanctions[i] = F.Record(history.sanctions[i].point, history.sanctions[i].record);
        }
        result.confirmations = history.confirmations;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
