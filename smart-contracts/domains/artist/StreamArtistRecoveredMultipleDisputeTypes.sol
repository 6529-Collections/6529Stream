// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredAttestationHydration as Records
} from "./StreamArtistRecoveredAttestationHydration.sol";
import {
    StreamArtistExtendedHydrationFeatures as XF
} from "../../interfaces/stream/artist/StreamArtistExtendedHydrationFeatures.sol";

/// @notice A separate aggregate profile retaining the original signed history row types.

library StreamArtistRecoveredMultipleDisputeTypes {
    bytes32 internal constant SCHEMA = keccak256("6529STREAM_ARTIST_MULTIPLE_DISPUTE_HISTORY_V1");
    uint16 internal constant VERSION = 1;
    uint256 internal constant FEATURE = XF.MULTIPLE_DISPUTE_HISTORY;
    // The generation profile's original family bits, excluding its distinct profile bit.
    uint256 internal constant ALLOWED = 2276351 - 2097152 + FEATURE;

    struct Attribution {
        D.Bundle history;
        Records.Bundle records;
    }

    function nativeDispute(uint16 operation) internal pure returns (bool) {
        return operation == 44 || operation == 45 || operation == 47 || operation == 61;
    }

    function archivedOperation(uint256 operation) internal pure returns (bool) {
        return (operation >= 1 && operation <= 4) || (operation >= 44 && operation <= 50)
            || operation == 61;
    }
}
