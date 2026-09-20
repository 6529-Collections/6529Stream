// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamNativeImmediateSalesState.sol";
import { IStreamERC20DutchSale as D } from "../../interfaces/stream/mint/IStreamERC20DutchSale.sol";

/// @dev New host-owned typed state. Shared bookkeeping types never represent a native receipt.
library StreamERC20DutchSaleState {
    struct State {
        StreamNativeImmediateSalesState.State common;
        mapping(bytes32 => D.Configuration) configurations;
        mapping(bytes32 => StreamPrimarySettlementTypes.SaleLifecycleBinding) lifecycle;
        mapping(bytes32 => bytes32) scheduleHashes;
    }
}
