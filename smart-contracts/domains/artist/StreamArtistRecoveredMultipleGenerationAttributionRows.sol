// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

/// @notice Canonical owner4 attribution rows and the unchanged attestation row view.
library StreamArtistRecoveredMultipleGenerationAttributionRows {
    function validateRow(bytes calldata raw)
        public
        pure
        returns (bytes memory history, bytes memory records)
    {
        G.Attribution memory row = abi.decode(raw, (G.Attribution));
        if (keccak256(raw) != keccak256(abi.encode(row))) _invalid();
        if (
            keccak256(abi.encode(row.history.current))
                != keccak256(abi.encode(row.records.item))
        ) _invalid();
        history = abi.encode(row.history);
        records = abi.encode(row.records);
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
