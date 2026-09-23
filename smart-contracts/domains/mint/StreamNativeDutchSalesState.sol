// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamNativeImmediateSalesState } from "./StreamNativeImmediateSalesState.sol";

import {
    IStreamDutchPriceSchedule
} from "../../interfaces/stream/mint/IStreamDutchPriceSchedule.sol";

/// @notice Canonical Dutch operational records and immutable schedules.
library StreamNativeDutchSalesState {
    struct State {
        StreamNativeImmediateSalesState.State common;
        mapping(bytes32 => IStreamDutchPriceSchedule.DutchPriceSchedule) schedules;
        mapping(bytes32 => bytes32) scheduleHashes;
        mapping(bytes32 => bool) declaredFree;
    }
}
