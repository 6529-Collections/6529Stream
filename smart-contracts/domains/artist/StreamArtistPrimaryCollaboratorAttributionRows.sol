// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";

/// @notice Original complete canonical owner4 row decoder in a fixed typed frame.
library StreamArtistPrimaryCollaboratorAttributionRows {
    struct Result {
        A.AttributionBundle[] histories;
        bytes[] rows;
    }

    function project(M.State calldata scope) public pure returns (Result memory result) {
        result.histories = new A.AttributionBundle[](scope.rows.length);
        result.rows = new bytes[](scope.rows.length);
        for (uint256 k; k < scope.rows.length; ++k) {
            G.Attribution memory row = abi.decode(scope.rows[k], (G.Attribution));
            if (keccak256(scope.rows[k]) != keccak256(abi.encode(row))) _invalid();
            if (
                keccak256(abi.encode(row.history.current))
                    != keccak256(abi.encode(row.records.item))
            ) {
                revert RH.InvalidRecoveredHydrationProfile();
            }
            result.histories[k] = row.history;
            result.rows[k] = abi.encode(row.records);
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
