// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import { StreamArtistCompleteHistoryTypes as CT } from "./StreamArtistCompleteHistoryTypes.sol";
import {
    StreamArtistCompleteHistoryCatalogue as SharedCatalogue
} from "./StreamArtistCompleteHistoryCatalogue.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredAggregateSanctionRows as Rows
} from "./StreamArtistRecoveredAggregateSanctionRows.sol";
import {
    StreamArtistRecoveredAggregateSanctionLocalProof as Local
} from "./StreamArtistRecoveredAggregateSanctionLocalProof.sol";

/// @notice One complete original sanction source inventory joined to the shared all-family Archive.
/// @dev An empty result is proved by both the authentic full Archive and native owner6 journal.
/// The original sanction catalogue retains its own domain and cutoffs; no fabricated conversion
/// between its catalogue hash and the shared catalogue hash is permitted.
library StreamArtistCompleteHistorySanctionSource {
    function collect(M.State memory scope, CT.Inventory memory inventory)
        public
        view
        returns (H.Inventory memory result)
    {
        RH.Provenance memory p = inventory.provenance;
        if (p.origins.length == 0) _invalid();
        SharedCatalogue.requireCurrent(
            p, inventory.archive.catalogues, inventory.archive.operations
        );
        uint256 count;
        uint256 originals;
        for (uint256 i; i < inventory.archive.operations.length; ++i) {
            uint16 operation = inventory.archive.operations[i].operation;
            if (operation == 12 || operation == 13) ++count;
            if (operation == 12) ++originals;
        }
        uint256 nativeCount;
        for (uint256 i; i < p.journals[6].length; ++i) {
            if (p.journals[6][i].receipt.operation == 12) ++nativeCount;
        }
        if (nativeCount != originals) _invalid();
        if (count == 0) return result;
        result = Rows.collect(
            p.origins[p.origins.length - 1].owners[6],
            scope.collections,
            p,
            inventory.bindings.bindings
        );
        if (result.operations.length != count) _invalid();
        uint256 cursor;
        for (uint256 i; i < inventory.archive.operations.length; ++i) {
            H.OperationEvidence memory row = inventory.archive.operations[i];
            if (row.operation != 12 && row.operation != 13) continue;
            if (keccak256(abi.encode(row)) != keccak256(abi.encode(result.operations[cursor++]))) {
                _invalid();
            }
        }
        Local.validate(RH.ownerProvenance(p, 4), 4, scope.collections, result);
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
