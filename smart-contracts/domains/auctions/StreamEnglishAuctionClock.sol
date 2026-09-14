// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Clock and minimum-bid arithmetic for the new versioned native auction.
/// @dev The house owns authorization, escrow, terminal states, pause-union accounting and
///      events. All deadlines stored here exclude elapsed pause toll. See ADR 0043.
library StreamEnglishAuctionClock {
    struct Configuration {
        uint64 startTime;
        uint64 endTime;
        uint32 firstBidDuration;
        uint32 antiSnipeWindow;
        uint32 antiSnipeExtension;
        uint32 maxTotalExtension;
        bool startOnFirstBid;
        bool hardClose;
    }

    struct State {
        uint64 originalEnd;
        uint64 nominalEnd;
        bool budgetWarningEmitted;
    }

    struct Bid {
        uint256 amount;
        uint256 highest;
        uint256 reserve;
        uint16 incrementBps;
        bool incrementFloorWaived;
    }

    struct Transition {
        uint64 previousEnd;
        uint64 effectiveEnd;
        uint32 extensionDelta;
        uint32 usedExtension;
        uint32 remainingExtension;
        bool clockStarted;
        bool extended;
        bool budgetWarning;
        bool budgetExhausted;
    }

    error AuctionClockConfigurationInvalid();
    error AuctionClockStateInvalid();
    error AuctionClockOverflow();
    error AuctionClockNotStarted();
    error AuctionClockEnded();
    error AuctionIncrementInvalid();
    error AuctionBidTooLow(uint256 minimum);
    error AuctionBidOverflow();
    error AuctionSettlementWindowInvalid();

    function initialize(Configuration memory c, uint256 reserve, uint64 timestamp)
        internal
        pure
        returns (State memory s)
    {
        if (c.startOnFirstBid) {
            if (
                c.endTime != 0 || reserve == 0 || c.firstBidDuration < 3600
                    || c.firstBidDuration > 2592000
            ) revert AuctionClockConfigurationInvalid();
        } else {
            if (c.firstBidDuration != 0 || c.endTime <= c.startTime || c.endTime <= timestamp) {
                revert AuctionClockConfigurationInvalid();
            }
            s.originalEnd = c.endTime;
            s.nominalEnd = c.endTime;
        }
        if (c.hardClose) {
            if (c.antiSnipeWindow != 0 || c.antiSnipeExtension != 0 || c.maxTotalExtension != 0) {
                revert AuctionClockConfigurationInvalid();
            }
        } else if (
            c.antiSnipeWindow < 60 || c.antiSnipeWindow > 86400 || c.antiSnipeExtension < 60
                || c.antiSnipeExtension > 86400 || c.maxTotalExtension < c.antiSnipeExtension
                || c.maxTotalExtension > 604800
        ) {
            revert AuctionClockConfigurationInvalid();
        }
    }

    function minimumBid(uint256 highest, uint256 reserve, uint16 bps, bool waived)
        internal
        pure
        returns (uint256 minimum)
    {
        if (bps > 10000 || (!waived && bps < 100)) revert AuctionIncrementInvalid();
        if (highest == 0) return reserve == 0 ? 1 : reserve;
        // Division first keeps the full uint256 price range, without a lossy division of
        // the final product. The remainder term implements the required upward rounding.
        uint256 increment = (highest / 10000) * bps;
        increment += ((highest % 10000) * bps + 9999) / 10000;
        if (increment == 0) increment = 1;
        if (highest > type(uint256).max - increment) revert AuctionBidOverflow();
        return highest + increment;
    }

    function acceptBid(
        Configuration memory c,
        State memory s,
        Bid memory b,
        uint64 timestamp,
        uint64 elapsedToll
    ) internal pure returns (State memory next, Transition memory t) {
        uint256 minimum = minimumBid(b.highest, b.reserve, b.incrementBps, b.incrementFloorWaived);
        if (b.amount < minimum) revert AuctionBidTooLow(minimum);
        if (timestamp < c.startTime) revert AuctionClockNotStarted();
        // Copy the fields: a memory assignment would alias the caller's state and
        // erase the previous deadline before calculating the extension delta.
        next = State(s.originalEnd, s.nominalEnd, s.budgetWarningEmitted);
        if (s.nominalEnd == 0) {
            if (
                !c.startOnFirstBid || s.originalEnd != 0 || s.budgetWarningEmitted || b.highest != 0
                    || elapsedToll != 0
            ) revert AuctionClockStateInvalid();
            next.nominalEnd = add64(timestamp, c.firstBidDuration);
            next.originalEnd = next.nominalEnd;
            t.clockStarted = true;
            t.extended = true;
            t.effectiveEnd = next.nominalEnd;
            t.remainingExtension = c.maxTotalExtension;
            t.budgetExhausted = c.hardClose;
            return (next, t);
        }
        if (
            s.originalEnd == 0 || s.nominalEnd < s.originalEnd
                || s.nominalEnd - s.originalEnd > c.maxTotalExtension
                || (c.startOnFirstBid && b.highest == 0)
        ) revert AuctionClockStateInvalid();
        t.previousEnd = add64(s.nominalEnd, elapsedToll);
        if (timestamp >= t.previousEnd) revert AuctionClockEnded();
        t.effectiveEnd = t.previousEnd;
        if (!c.hardClose && t.previousEnd - timestamp < c.antiSnipeWindow) {
            uint256 proposed = uint256(timestamp) + c.antiSnipeExtension;
            uint256 cap = uint256(s.originalEnd) + elapsedToll + c.maxTotalExtension;
            if (proposed > cap) proposed = cap;
            if (proposed > t.previousEnd) {
                if (proposed > type(uint64).max) revert AuctionClockOverflow();
                t.effectiveEnd = uint64(proposed);
                next.nominalEnd = uint64(proposed - elapsedToll);
                t.extensionDelta = uint32(next.nominalEnd - s.nominalEnd);
                t.extended = true;
            }
        }
        t.usedExtension = uint32(next.nominalEnd - next.originalEnd);
        t.remainingExtension = c.maxTotalExtension - t.usedExtension;
        t.budgetExhausted = t.remainingExtension == 0;
        if (
            t.extended && !s.budgetWarningEmitted
                && uint256(t.usedExtension) * 2 >= c.maxTotalExtension
        ) {
            next.budgetWarningEmitted = true;
            t.budgetWarning = true;
        }
    }

    function effectiveEnd(State memory s, uint64 elapsedToll) internal pure returns (uint64) {
        return s.nominalEnd == 0 ? 0 : add64(s.nominalEnd, elapsedToll);
    }

    function effectiveFinalizeBy(
        State memory s,
        uint32 window,
        uint64 elapsedToll,
        uint64 signedCeiling
    ) internal pure returns (uint64) {
        if (window < 86400 || window > 7776000) {
            revert AuctionSettlementWindowInvalid();
        }
        if (s.nominalEnd == 0) return 0;
        uint256 deadline = uint256(s.nominalEnd) + window + elapsedToll;
        if (signedCeiling != 0 && deadline > signedCeiling) return signedCeiling;
        if (deadline > type(uint64).max) revert AuctionClockOverflow();
        return uint64(deadline);
    }

    function expired(uint64 deadline, uint64 timestamp) internal pure returns (bool) {
        return deadline != 0 && timestamp > deadline;
    }

    function add64(uint64 a, uint64 b) private pure returns (uint64) {
        uint256 sum = uint256(a) + b;
        if (sum > type(uint64).max) revert AuctionClockOverflow();
        return uint64(sum);
    }
}
