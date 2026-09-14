// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../mint/StreamRefundClock.sol";

/// @notice Exact historical start clipping over the existing global/local pause union.
/// @dev Append at every successful transition; equal-time edges are resolved to the last edge.
library StreamNativeEnglishAuctionPause {
    struct GlobalPoint {
        uint64 at;
        uint64 accumulated;
        bool paused;
    }

    struct LocalPoint {
        uint64 at;
        uint64 exclusive;
        uint64 globalAtEdge;
        bool paused;
    }

    struct History {
        GlobalPoint[] global;
        mapping(bytes32 => LocalPoint[]) local;
    }

    function recordGlobal(History storage h, StreamRefundClock.GlobalClock storage g) internal {
        h.global
            .push(
                GlobalPoint(StreamRefundClock.now64(), StreamRefundClock.globalTotal(g), g.paused)
            );
    }

    function recordLocal(
        History storage h,
        bytes32 id,
        StreamRefundClock.GlobalClock storage g,
        StreamRefundClock.SaleClock storage l
    ) internal {
        uint64 total = StreamRefundClock.globalTotal(g);
        h.local[id].push(
            LocalPoint(
                StreamRefundClock.now64(),
                StreamRefundClock.unionTotal(g, l) - total,
                total,
                l.paused
            )
        );
    }

    function unionAt(History storage h, bytes32 id, uint64 timestamp)
        internal
        view
        returns (uint64)
    {
        if (timestamp > block.timestamp) {
            revert StreamRefundClock.RefundClockOverflow();
        }
        uint64 global = globalAt(h, timestamp);
        LocalPoint[] storage points = h.local[id];
        uint256 low;
        uint256 high = points.length;
        while (low < high) {
            uint256 mid = low + (high - low) / 2;
            if (points[mid].at <= timestamp) low = mid + 1;
            else high = mid;
        }
        if (low == 0) return global;
        LocalPoint storage p = points[low - 1];
        uint64 exclusive = p.exclusive;
        if (p.paused) exclusive += (timestamp - p.at) - (global - p.globalAtEdge);
        return global + exclusive;
    }

    function globalAt(History storage h, uint64 timestamp) internal view returns (uint64) {
        GlobalPoint[] storage points = h.global;
        uint256 low;
        uint256 high = points.length;
        while (low < high) {
            uint256 mid = low + (high - low) / 2;
            if (points[mid].at <= timestamp) low = mid + 1;
            else high = mid;
        }
        if (low == 0) return 0;
        GlobalPoint storage p = points[low - 1];
        return p.accumulated + (p.paused ? timestamp - p.at : 0);
    }
}
