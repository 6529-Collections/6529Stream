// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamNativeImmediateSalesState } from "./StreamNativeImmediateSalesState.sol";

/// @notice New claim carrier owns the same typed operational records plus immutable price ceilings.
library StreamNativeClaimSalesState {
    struct State {
        StreamNativeImmediateSalesState.State common;
        mapping(bytes32 => uint256) maxUnitPrices;
    }
}
