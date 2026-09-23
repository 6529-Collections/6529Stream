// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationCommit as Commit
} from "./StreamArtistRecoveredHydrationCommit.sol";

/// @notice Original inventory preimage read directly from the complete typed certificate.
library StreamArtistRecoveredPreparationInventory {
    function inventory(Commit.Prepared calldata p) public pure returns (bytes32) {
        bytes32 provenance = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERED_HYDRATION_PROVENANCE_V1"),
                RH.VERSION,
                p.admission.provenance
            )
        );
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERED_SEMANTIC_INVENTORY_V1"),
                RH.VERSION,
                provenance,
                p.query,
                p.data,
                p.timing,
                p.externalGuards
            )
        );
    }
}
