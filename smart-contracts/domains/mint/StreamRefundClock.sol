// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Constant-time union of adapter-wide and per-sale pause intervals.
/// @dev The embedding adapter owns authority, events and terminal purchase snapshots.
library StreamRefundClock {
    struct GlobalClock {
        bool paused;
        uint64 since;
        uint64 accumulated;
    }

    struct SaleClock {
        bool paused;
        uint64 since;
        uint64 exclusiveAccumulated;
        uint64 globalAtStart;
    }

    error RefundClockOverflow();
    error RefundPauseUnchanged();

    function now64() internal view returns (uint64) {
        if (block.timestamp > type(uint64).max) revert RefundClockOverflow();
        return uint64(block.timestamp);
    }

    function globalTotal(GlobalClock storage clock) internal view returns (uint64) {
        return clock.accumulated + (clock.paused ? now64() - clock.since : 0);
    }

    function unionTotal(GlobalClock storage global, SaleClock storage local)
        internal
        view
        returns (uint64)
    {
        uint64 total = globalTotal(global);
        uint64 exclusive = local.exclusiveAccumulated;
        if (local.paused) {
            exclusive += (now64() - local.since) - (total - local.globalAtStart);
        }
        return total + exclusive;
    }

    function setGlobal(GlobalClock storage clock, bool paused) internal {
        if (clock.paused == paused) revert RefundPauseUnchanged();
        if (paused) clock.since = now64();
        else clock.accumulated = globalTotal(clock);
        clock.paused = paused;
    }

    function setSale(GlobalClock storage global, SaleClock storage local, bool paused) internal {
        if (local.paused == paused) revert RefundPauseUnchanged();
        uint64 total = globalTotal(global);
        if (paused) {
            local.since = now64();
            local.globalAtStart = total;
        } else {
            local.exclusiveAccumulated += (now64() - local.since) - (total - local.globalAtStart);
        }
        local.paused = paused;
    }

    function cappedDeadline(uint64 nominal, uint64 toll, uint64 absoluteEscape)
        internal
        pure
        returns (uint64)
    {
        uint256 extended = uint256(nominal) + toll;
        return extended < absoluteEscape ? uint64(extended) : absoluteEscape;
    }
}
