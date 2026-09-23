// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/auctions/IStreamNativeCustodyAuction.sol";

/// @notice Appended custody-only state; no overlay of the original deferred auction slots.
library StreamNativeEnglishAuctionCustodyState {
    struct State {
        mapping(bytes32 => StreamNativeCustodySettlementTypes.Origin) origins;
        bytes32 acquiring;
        uint256 expectedToken;
        bool received;
    }
}
