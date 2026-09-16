// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Half-open commit/reveal clocks over global, collection and sale stop unions.
/// @dev The host owns authorization, collection-standing reads, events and immutable schedules.
///      Global transitions never scan collections or sales. Historical reads use binary search;
///      each expired window needs at most 64 timestamp probes, each logarithmic in its histories.
library StreamNativeCuratedClock {
    struct Point {
        uint64 at;
        uint64 accumulated;
        uint64 parentAtEdge;
        bool stopped;
    }

    struct SaleHistory {
        uint256 collectionId;
        Point[] points;
    }

    struct History {
        Point[] global;
        mapping(uint256 => Point[]) collections;
        mapping(bytes32 => SaleHistory) sales;
    }

    struct Schedule {
        uint64 commitOpen;
        uint64 commitClose;
        uint64 revealOpen;
        uint64 revealClose;
        uint64 absoluteEscape;
    }

    struct View {
        uint64 commitOpen;
        uint64 commitClose;
        uint64 revealOpen;
        uint64 revealClose;
        uint64 commitToll;
        uint64 revealToll;
        bool commitLive;
        bool revealLive;
        bool commitMatured;
        bool matured;
        bool escapeReached;
        bool globalPaused;
        bool localPaused;
        bool collectionStopped;
    }

    error CuratedClockOverflow();
    error CuratedClockScheduleInvalid();
    error CuratedClockFuture(uint64 timestamp);
    error CuratedClockStopUnchanged();
    error CuratedClockIdentityInvalid();

    function now64() public view returns (uint64) {
        if (block.timestamp > type(uint64).max) revert CuratedClockOverflow();
        return uint64(block.timestamp);
    }

    /// @notice Registration check; snapshots retain the same nominal schedule after opening.
    function validateSchedule(Schedule memory s) public view {
        _validate(s);
        if (now64() >= s.commitOpen) revert CuratedClockScheduleInvalid();
    }

    function _validate(Schedule memory s) private pure {
        if (
            s.commitOpen >= s.commitClose || s.commitClose > s.revealOpen
                || s.revealOpen >= s.revealClose || s.absoluteEscape < s.revealClose
        ) revert CuratedClockScheduleInvalid();
    }

    function setGlobal(History storage h, bool value) public {
        if (_stopped(h.global) == value) revert CuratedClockStopUnchanged();
        uint64 at = now64();
        h.global.push(Point(at, _globalAt(h, at), 0, value));
    }

    function setCollection(History storage h, uint256 collectionId, bool value) public {
        if (collectionId == 0) revert CuratedClockIdentityInvalid();
        Point[] storage points = h.collections[collectionId];
        if (_stopped(points) == value) revert CuratedClockStopUnchanged();
        uint64 at = now64();
        uint64 parent = _globalAt(h, at);
        points.push(Point(at, _exclusiveAt(points, at, parent), parent, value));
    }

    function setSale(History storage h, bytes32 saleId, uint256 collectionId, bool value) public {
        _identity(h, saleId, collectionId);
        SaleHistory storage sale = h.sales[saleId];
        if (_stopped(sale.points) == value) revert CuratedClockStopUnchanged();
        uint64 at = now64();
        uint64 parent = _collectionAt(h, collectionId, at);
        sale.collectionId = collectionId;
        sale.points.push(Point(at, _exclusiveAt(sale.points, at, parent), parent, value));
    }

    function stops(History storage h, bytes32 saleId, uint256 collectionId)
        public
        view
        returns (bool globalPaused, bool localPaused, bool collectionStopped)
    {
        _identity(h, saleId, collectionId);
        return (
            _stopped(h.global),
            _stopped(h.sales[saleId].points),
            _stopped(h.collections[collectionId])
        );
    }

    function unionAt(History storage h, bytes32 saleId, uint256 collectionId, uint64 at)
        public
        view
        returns (uint64)
    {
        _identity(h, saleId, collectionId);
        if (at > now64()) revert CuratedClockFuture(at);
        return _unionAt(h, saleId, collectionId, at);
    }

    /// @notice Observed deadlines, assuming no additional future stops; all windows are half-open.
    /// @dev Toll fields count actual stopped seconds while live, up to escape. The absolute cap
    ///      may truncate the corresponding deadline extension. Maturity never depends on stop flags.
    function snapshot(History storage h, bytes32 saleId, uint256 collectionId, Schedule memory s)
        public
        view
        returns (View memory v)
    {
        _validate(s);
        _identity(h, saleId, collectionId);
        uint64 at = now64();
        (v.globalPaused, v.localPaused, v.collectionStopped) = stops(h, saleId, collectionId);
        v.commitOpen = s.commitOpen;
        (v.commitClose, v.commitToll) = _window(
            h,
            saleId,
            collectionId,
            s.commitOpen,
            s.commitClose - s.commitOpen,
            s.absoluteEscape,
            at
        );
        // Only the commit window's extension shifts reveal opening. No pause in the
        // intervening gap is charged, and an escape-truncated commit cannot open reveal.
        v.revealOpen = _cap(uint256(s.revealOpen) + v.commitClose - s.commitClose, s.absoluteEscape);
        (v.revealClose, v.revealToll) = _window(
            h,
            saleId,
            collectionId,
            v.revealOpen,
            s.revealClose - s.revealOpen,
            s.absoluteEscape,
            at
        );
        bool stopped = v.globalPaused || v.localPaused || v.collectionStopped;
        v.escapeReached = at >= s.absoluteEscape;
        v.commitMatured = at >= v.commitClose;
        v.matured = at >= v.revealClose;
        v.commitLive = !stopped && at >= v.commitOpen && !v.commitMatured;
        v.revealLive = !stopped && at >= v.revealOpen && !v.matured;
    }

    function _window(
        History storage h,
        bytes32 saleId,
        uint256 collectionId,
        uint64 start,
        uint64 duration,
        uint64 escape,
        uint64 at
    ) private view returns (uint64 end, uint64 toll) {
        end = _cap(uint256(start) + duration, escape);
        if (at <= start || start == escape) return (end, 0);
        uint64 observed = at < escape ? at : escape;
        uint64 baseline = _unionAt(h, saleId, collectionId, start);
        toll = _unionAt(h, saleId, collectionId, observed) - baseline;
        if (toll == 0) return (end, 0);
        if (observed - start - toll < duration) {
            return (_cap(uint256(start) + duration + toll, escape), toll);
        }
        // Locate the FIRST second with the entire unpaused duration elapsed. Searching
        // the historical monotone active clock excludes every stop after the true close.
        uint64 low = end;
        uint64 high = observed;
        while (low < high) {
            uint64 mid = low + (high - low) / 2;
            uint64 paused = _unionAt(h, saleId, collectionId, mid) - baseline;
            if (mid - start - paused >= duration) high = mid;
            else low = mid + 1;
        }
        end = low;
        toll = end - start - duration;
    }

    function _cap(uint256 value, uint64 escape) private pure returns (uint64) {
        return value < escape ? uint64(value) : escape;
    }

    function _identity(History storage h, bytes32 saleId, uint256 collectionId) private view {
        uint256 bound = h.sales[saleId].collectionId;
        if (saleId == 0 || collectionId == 0 || (bound != 0 && bound != collectionId)) {
            revert CuratedClockIdentityInvalid();
        }
    }

    function _stopped(Point[] storage points) private view returns (bool) {
        uint256 n = points.length;
        return n != 0 && points[n - 1].stopped;
    }

    function _unionAt(History storage h, bytes32 saleId, uint256 collectionId, uint64 at)
        private
        view
        returns (uint64)
    {
        uint64 parent = _collectionAt(h, collectionId, at);
        return parent + _exclusiveAt(h.sales[saleId].points, at, parent);
    }

    function _collectionAt(History storage h, uint256 collectionId, uint64 at)
        private
        view
        returns (uint64)
    {
        uint64 parent = _globalAt(h, at);
        return parent + _exclusiveAt(h.collections[collectionId], at, parent);
    }

    function _globalAt(History storage h, uint64 at) private view returns (uint64) {
        uint256 n = _upperBound(h.global, at);
        if (n == 0) return 0;
        Point storage p = h.global[n - 1];
        return p.accumulated + (p.stopped ? at - p.at : 0);
    }

    function _exclusiveAt(Point[] storage points, uint64 at, uint64 parent)
        private
        view
        returns (uint64)
    {
        uint256 n = _upperBound(points, at);
        if (n == 0) return 0;
        Point storage p = points[n - 1];
        return p.accumulated + (p.stopped ? (at - p.at) - (parent - p.parentAtEdge) : 0);
    }

    function _upperBound(Point[] storage points, uint64 at) private view returns (uint256 low) {
        uint256 high = points.length;
        while (low < high) {
            uint256 mid = low + (high - low) / 2;
            if (points[mid].at <= at) low = mid + 1;
            else high = mid;
        }
    }
}
