// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Immutable standard Dutch schedule vocabulary from SSA-DUTCH.
interface IStreamDutchPriceSchedule {
    struct DutchPriceSchedule {
        uint96 startPrice;
        uint96 restingPrice;
        uint64 startTime;
        uint64 endTime;
        uint8 decayKind; // LINEAR0, STEPPED1; all other values are reserved.
        uint32 stepSeconds;
        uint96 stepAmount;
    }

    error DutchScheduleInvalid();
}
