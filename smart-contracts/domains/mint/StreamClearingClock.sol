// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Historical union of global and sale pauses for an unattended close reference.
/// @dev Lookups are logarithmic in transitions. Global changes never iterate over sales.
library StreamClearingClock {
    struct GlobalCheckpoint {
        uint64 at;
        uint64 accumulated;
        bool paused;
    }

    struct LocalCheckpoint {
        uint64 at;
        uint64 exclusiveAccumulated;
        uint64 globalAtStart;
        bool paused;
    }

    struct History {
        GlobalCheckpoint[] global;
        mapping(bytes32 => LocalCheckpoint[]) local;
    }

    error ClearingClockOverflow();
    error ClearingClockFuture(uint64 timestamp);
    error ClearingPauseUnchanged();

    function now64() public view returns (uint64) {
        if (block.timestamp > type(uint64).max) revert ClearingClockOverflow();
        return uint64(block.timestamp);
    }

    function globalPaused(History storage h) public view returns (bool) {
        uint256 n = h.global.length;
        return n != 0 && h.global[n - 1].paused;
    }

    function localPaused(History storage h, bytes32 saleId) public view returns (bool) {
        uint256 n = h.local[saleId].length;
        return n != 0 && h.local[saleId][n - 1].paused;
    }

    function setGlobal(History storage h, bool value) public {
        if (globalPaused(h) == value) revert ClearingPauseUnchanged();
        uint64 at = now64();
        uint64 total = globalTotalAt(h, at);
        if (h.global.length == type(uint64).max) revert ClearingClockOverflow();
        h.global.push(GlobalCheckpoint(at, total, value));
    }

    function setLocal(History storage h, bytes32 saleId, bool value) public {
        if (localPaused(h, saleId) == value) revert ClearingPauseUnchanged();
        uint64 at = now64();
        uint64 g = globalTotalAt(h, at);
        uint64 exclusive = _exclusiveAt(h, saleId, at, g);
        if (h.local[saleId].length == type(uint64).max) revert ClearingClockOverflow();
        h.local[saleId].push(LocalCheckpoint(at, exclusive, g, value));
    }

    function globalTotalAt(History storage h, uint64 at) public view returns (uint64) {
        if (at > now64()) revert ClearingClockFuture(at);
        uint256 lo;
        uint256 hi = h.global.length;
        // Upper bound selects the LAST transition at the requested second.
        while (lo < hi) {
            uint256 mid = lo + (hi - lo) / 2;
            if (h.global[mid].at <= at) lo = mid + 1;
            else hi = mid;
        }
        if (lo == 0) return 0;
        GlobalCheckpoint storage c = h.global[lo - 1];
        return c.accumulated + (c.paused ? at - c.at : 0);
    }

    function unionTotalAt(History storage h, bytes32 saleId, uint64 at)
        public
        view
        returns (uint64)
    {
        uint64 g = globalTotalAt(h, at);
        return g + _exclusiveAt(h, saleId, at, g);
    }

    function tollSince(History storage h, bytes32 saleId, uint64 referenceTime)
        public
        view
        returns (uint64)
    {
        return unionTotalAt(h, saleId, now64()) - unionTotalAt(h, saleId, referenceTime);
    }

    function _exclusiveAt(History storage h, bytes32 saleId, uint64 at, uint64 g)
        private
        view
        returns (uint64)
    {
        LocalCheckpoint[] storage entries = h.local[saleId];
        uint256 lo;
        uint256 hi = entries.length;
        while (lo < hi) {
            uint256 mid = lo + (hi - lo) / 2;
            if (entries[mid].at <= at) lo = mid + 1;
            else hi = mid;
        }
        if (lo == 0) return 0;
        LocalCheckpoint storage c = entries[lo - 1];
        return c.exclusiveAccumulated + (c.paused ? (at - c.at) - (g - c.globalAtStart) : 0);
    }
}
