// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "./StreamArtistRecoveredHydrationTypes.sol";

/// @notice Additional typed migration features without changing the original transport types.
/// @dev A known bit is not a capability advertisement or admission. Each implemented owner
/// and semantic profile must explicitly support its complete feature set.
library StreamArtistExtendedHydrationFeatures {
    uint256 internal constant MULTIPLE_GENERATIONS = 2097152;
    uint256 internal constant MULTIPLE_GENERATIONS_GRAPH_FEATURES =
        RH.MULTIPLE_ATTESTATIONS_GRAPH_FEATURES | MULTIPLE_GENERATIONS;
    uint256 internal constant UNBOUND_PLATFORM = 4194304;
    uint256 internal constant PRIMARY_COLLABORATORS = 8388608;
    uint256 internal constant MULTIPLE_DISPUTE_HISTORY = 16777216;
    uint256 internal constant KNOWN_FEATURES = RH.KNOWN_FEATURES | MULTIPLE_GENERATIONS
        | UNBOUND_PLATFORM | PRIMARY_COLLABORATORS | MULTIPLE_DISPUTE_HISTORY;
}
