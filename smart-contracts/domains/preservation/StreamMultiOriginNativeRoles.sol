// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";

/// @dev The configured Artist pins are current authority. Historical graphs have separate,
/// authenticated ARTIST_ORIGIN_* rows. Preserve every other original item field and order.
library StreamMultiOriginNativeRoles {
    function relabel(T.Item[] memory rows) internal pure {
        for (uint256 i; i < rows.length; ++i) {
            if (rows[i].kind != T.Kind.CONTRACT_RUNTIME) continue;
            bytes32 role = rows[i].role;
            if (role == keccak256("ORIGINAL_ARTIST_DEPENDENCY_RUNTIME")) {
                rows[i].role = keccak256("CURRENT_ARTIST_DEPENDENCY_RUNTIME");
            } else if (role == keccak256("ORIGINAL_ARTIST_CONTENT_OWNER_RUNTIME")) {
                rows[i].role = keccak256("CURRENT_ARTIST_CONTENT_OWNER_RUNTIME");
            } else if (role == keccak256("ORIGINAL_ARTIST_CONTENT_OWNER")) {
                rows[i].role = keccak256("CURRENT_ARTIST_CONTENT_OWNER");
            } else {
                for (uint256 j; j < 5; ++j) {
                    if (role == keccak256(abi.encode("ORIGINAL_ARTIST_DEPENDENCY_V2", j))) {
                        rows[i].role = keccak256(abi.encode("CURRENT_ARTIST_DEPENDENCY_V2", j));
                        break;
                    }
                }
            }
        }
    }
}
