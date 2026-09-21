// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredAttestationHydration as Original
} from "./StreamArtistRecoveredAttestationHydration.sol";

/// @notice Complete mixed owner4 history; every original nominal member remains explicit.
library StreamArtistRecoveredHistoryRecordTypes {
    bytes32 internal constant ATTRIBUTION =
        keccak256("6529STREAM_ARTIST_RECOVERED_HISTORY_RECORDS_V1");
    bytes32 internal constant BINDING =
        keccak256("6529STREAM_ARTIST_RECOVERED_HISTORY_RECORD_BINDINGS_V1");

    struct Bundle {
        P.Bundle history;
        Original.Bundle attestations;
    }
}
