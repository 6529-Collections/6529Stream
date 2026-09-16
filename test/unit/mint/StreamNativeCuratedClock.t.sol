// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/mint/StreamNativeCuratedClock.sol";

interface CuratedClockVm {
    function warp(uint256 timestamp) external;
    function expectRevert(bytes calldata reason) external;
}

/// @dev Isolated clock arithmetic; this harness intentionally supplies no role or contest authority.
contract NativeCuratedClockHarness {
    StreamNativeCuratedClock.History private history;

    function validate(StreamNativeCuratedClock.Schedule memory s) external view {
        StreamNativeCuratedClock.validateSchedule(s);
    }

    function global(bool value) external {
        StreamNativeCuratedClock.setGlobal(history, value);
    }

    function collection(uint256 id, bool value) external {
        StreamNativeCuratedClock.setCollection(history, id, value);
    }

    function sale(bytes32 id, uint256 collectionId, bool value) external {
        StreamNativeCuratedClock.setSale(history, id, collectionId, value);
    }

    function snapshot(bytes32 id, uint256 collectionId, StreamNativeCuratedClock.Schedule memory s)
        external
        view
        returns (StreamNativeCuratedClock.View memory)
    {
        return StreamNativeCuratedClock.snapshot(history, id, collectionId, s);
    }

    function total(bytes32 id, uint256 collectionId, uint64 at) external view returns (uint64) {
        return StreamNativeCuratedClock.unionAt(history, id, collectionId, at);
    }
}

contract StreamNativeCuratedClockTest {
    CuratedClockVm private constant vm =
        CuratedClockVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant SALE = bytes32(uint256(1));
    bytes32 private constant OTHER = bytes32(uint256(2));
    NativeCuratedClockHarness private h;

    function setUp() external {
        vm.warp(50);
        h = new NativeCuratedClockHarness();
    }

    function _schedule() private pure returns (StreamNativeCuratedClock.Schedule memory) {
        return StreamNativeCuratedClock.Schedule(100, 120, 130, 160, 300);
    }

    function _view() private view returns (StreamNativeCuratedClock.View memory) {
        return h.snapshot(SALE, 1, _schedule());
    }

    function testNominalHalfOpenWindowsAndGap() external {
        h.validate(_schedule());
        require(!_view().commitLive && !_view().revealLive, "before open");
        vm.warp(100);
        require(_view().commitLive, "commit open included");
        vm.warp(119);
        require(_view().commitLive, "last commit second");
        vm.warp(120);
        require(_view().commitMatured && !_view().commitLive && !_view().revealLive, "gap");
        vm.warp(130);
        require(_view().revealLive, "reveal open included");
        vm.warp(160);
        StreamNativeCuratedClock.View memory v = _view();
        require(v.matured && !v.revealLive && !v.escapeReached, "reveal close excluded");
        require(v.commitClose == 120 && v.revealClose == 160, "nominal dates");
    }

    function testThreeWayOverlapPreservesRemainingTimeAndPinnedGap() external {
        vm.warp(105);
        h.global(true);
        vm.warp(110);
        h.collection(1, true);
        vm.warp(115);
        h.sale(SALE, 1, true);
        vm.warp(120);
        h.global(false);
        vm.warp(135);
        h.collection(1, false);
        vm.warp(140);
        h.sale(SALE, 1, false);
        StreamNativeCuratedClock.View memory v = _view();
        require(v.commitClose == 155 && v.commitToll == 35, "union counted once");
        require(v.revealOpen == 165 && v.revealClose == 195, "gap preserved");
        require(v.commitLive && !v.revealLive, "remaining commit available");
        vm.warp(170);
        h.global(true);
        vm.warp(175);
        h.collection(1, true);
        vm.warp(180);
        h.global(false);
        vm.warp(185);
        h.sale(SALE, 1, true);
        vm.warp(190);
        h.collection(1, false);
        vm.warp(200);
        h.sale(SALE, 1, false);
        v = _view();
        require(v.commitClose == 155 && v.commitToll == 35, "commit frozen");
        require(v.revealClose == 225 && v.revealToll == 30 && v.revealLive, "reveal union");
    }

    function testPreOpenPauseClipsAtCommitOpening() external {
        h.global(true);
        vm.warp(90);
        require(_view().commitClose == 120, "future opening unaffected");
        vm.warp(110);
        StreamNativeCuratedClock.View memory v = _view();
        require(v.commitToll == 10 && v.commitClose == 130 && !v.commitLive, "only live overlap");
        h.global(false);
        require(_view().commitLive && _view().commitClose == 130, "full remaining time");
    }

    function testStopsEntirelyBeforeOpeningAndInsideGapDoNotToll() external {
        h.collection(1, true);
        vm.warp(90);
        h.collection(1, false);
        vm.warp(122);
        h.global(true);
        vm.warp(128);
        h.global(false);
        StreamNativeCuratedClock.View memory v = _view();
        require(v.commitClose == 120 && v.commitToll == 0, "preopen and later stop excluded");
        require(v.revealOpen == 130 && v.revealClose == 160 && v.revealToll == 0, "gap excluded");
    }

    function testGapStopCrossingRevealOpeningTollsOnlyReveal() external {
        vm.warp(125);
        h.collection(1, true);
        vm.warp(140);
        h.collection(1, false);
        StreamNativeCuratedClock.View memory v = _view();
        require(v.commitClose == 120 && v.revealOpen == 130, "closed commit and fixed reveal start");
        require(v.revealClose == 170 && v.revealToll == 10, "only after reveal open");
    }

    function testStopExactlyAtCommitCloseCannotReviveCommit() external {
        vm.warp(120);
        h.global(true);
        vm.warp(140);
        StreamNativeCuratedClock.View memory v = _view();
        require(
            v.commitMatured && v.commitClose == 120 && v.commitToll == 0, "half-open close frozen"
        );
        require(v.revealClose == 170 && v.revealToll == 10, "later reveal pause");
        h.global(false);
        require(!_view().commitLive && _view().revealLive, "only reveal restored");
    }

    function testStopsAtOrAfterRevealCloseNeverReviveEitherWindow() external {
        vm.warp(160);
        h.collection(1, true);
        vm.warp(175);
        h.global(true);
        vm.warp(190);
        h.sale(SALE, 1, true);
        vm.warp(250);
        StreamNativeCuratedClock.View memory v = _view();
        require(v.commitClose == 120 && v.revealClose == 160, "terminal timestamps frozen");
        require(v.commitToll == 0 && v.revealToll == 0 && v.matured, "no terminal toll");
        require(v.globalPaused && v.localPaused && v.collectionStopped, "stop state independent");
        h.collection(1, false);
        h.global(false);
        h.sale(SALE, 1, false);
        require(_view().matured && !_view().revealLive, "clearing stops does not revive");
    }

    function testSameTimestampEdgesUseLastStateWithoutDoubleCounting() external {
        vm.warp(105);
        h.global(true);
        h.global(false);
        h.global(true);
        h.collection(1, true);
        h.collection(1, false);
        h.collection(1, true);
        h.sale(SALE, 1, true);
        h.sale(SALE, 1, false);
        h.sale(SALE, 1, true);
        vm.warp(115);
        h.sale(SALE, 1, false);
        h.global(false);
        h.collection(1, false);
        h.global(true);
        h.global(false);
        require(h.total(SALE, 1, 105) == 0 && h.total(SALE, 1, 115) == 10, "same-second union");
        StreamNativeCuratedClock.View memory v = _view();
        require(v.commitClose == 130 && v.commitLive, "last state clear and ten seconds toll");
    }

    function testAdjacentNominalWindowsStayAdjacentAfterCommitToll() external {
        StreamNativeCuratedClock.Schedule memory s = _schedule();
        s.revealOpen = 120;
        s.revealClose = 150;
        h.validate(s);
        vm.warp(110);
        h.global(true);
        vm.warp(130);
        h.global(false);
        vm.warp(140);
        StreamNativeCuratedClock.View memory v = h.snapshot(SALE, 1, s);
        require(v.commitClose == 140 && v.revealOpen == 140 && v.revealClose == 170, "adjacency");
        require(!v.commitLive && v.revealLive, "only reveal at common boundary");
    }

    function testIndefiniteStopCannotMoveEscapeOrStrandMaturity() external {
        vm.warp(105);
        h.global(true);
        vm.warp(299);
        StreamNativeCuratedClock.View memory v = _view();
        require(v.commitClose == 300 && v.revealOpen == 300 && v.revealClose == 300, "capped");
        require(!v.matured && !v.escapeReached, "before escape");
        vm.warp(300);
        v = _view();
        require(
            v.escapeReached && v.matured && v.commitMatured && v.globalPaused, "escape despite stop"
        );
        vm.warp(500);
        require(
            _view().commitToll == 195 && _view().revealClose == 300, "history clipped at escape"
        );
        h.global(false);
        require(_view().matured && !_view().revealLive, "escape cannot reopen");
    }

    function testEscapeMayTruncateRemainingRevealTime() external {
        StreamNativeCuratedClock.Schedule memory s = _schedule();
        s.absoluteEscape = 165;
        vm.warp(135);
        h.collection(1, true);
        vm.warp(164);
        StreamNativeCuratedClock.View memory v = h.snapshot(SALE, 1, s);
        require(v.revealClose == 165 && v.revealToll == 29 && !v.matured, "cap distinct from toll");
        vm.warp(165);
        require(h.snapshot(SALE, 1, s).matured, "half-open cap maturity");
    }

    function testEscapeMayEqualNominalRevealClose() external {
        StreamNativeCuratedClock.Schedule memory s = _schedule();
        s.absoluteEscape = s.revealClose;
        h.validate(s);
        vm.warp(160);
        StreamNativeCuratedClock.View memory v = h.snapshot(SALE, 1, s);
        require(v.revealClose == 160 && v.matured && v.escapeReached, "equal cap is valid");
    }

    function testNearUint64LimitCapsBeforeTimestampAdditionCanOverflow() external {
        uint64 last = type(uint64).max;
        vm.warp(last - 100);
        StreamNativeCuratedClock.Schedule memory s =
            StreamNativeCuratedClock.Schedule(last - 60, last - 40, last - 30, last - 10, last);
        h.validate(s);
        vm.warp(last - 50);
        h.global(true);
        vm.warp(last);
        StreamNativeCuratedClock.View memory v = h.snapshot(SALE, 1, s);
        require(v.commitClose == last && v.revealOpen == last && v.revealClose == last, "safe cap");
        require(v.commitToll == 50 && v.matured && v.escapeReached, "terminal at uint64 limit");
    }

    function testMultipleCollectionsAndSalesRemainIndependent() external {
        vm.warp(105);
        h.global(true);
        vm.warp(110);
        h.collection(1, true);
        vm.warp(115);
        h.global(false);
        vm.warp(120);
        h.sale(SALE, 1, true);
        vm.warp(125);
        h.collection(1, false);
        vm.warp(130);
        h.sale(SALE, 1, false);
        require(h.total(SALE, 1, 130) == 25, "all three sources");
        require(h.total(OTHER, 1, 130) == 20, "shared collection only");
        require(h.total(OTHER, 2, 130) == 10, "global only on other collection");
        require(h.snapshot(OTHER, 2, _schedule()).commitClose == 130, "other sale deadline");
    }

    function testInvalidSchedulesAndLateConfigurationReject() external {
        StreamNativeCuratedClock.Schedule memory s = _schedule();
        s.commitClose = 131;
        _invalidSchedule(s);
        s = _schedule();
        s.commitClose = 100;
        _invalidSchedule(s);
        s = _schedule();
        s.revealClose = 130;
        _invalidSchedule(s);
        s = _schedule();
        s.absoluteEscape = 159;
        _invalidSchedule(s);
        s.absoluteEscape = 0;
        _invalidSchedule(s);
        vm.warp(100);
        _invalidSchedule(_schedule());
        vm.warp(101);
        _invalidSchedule(_schedule());
    }

    function _invalidSchedule(StreamNativeCuratedClock.Schedule memory s) private {
        vm.expectRevert(
            abi.encodeWithSelector(StreamNativeCuratedClock.CuratedClockScheduleInvalid.selector)
        );
        h.validate(s);
    }

    function testDuplicateTransitionsIdentityAndFutureReadsReject() external {
        vm.expectRevert(
            abi.encodeWithSelector(StreamNativeCuratedClock.CuratedClockStopUnchanged.selector)
        );
        h.global(false);
        h.sale(SALE, 1, true);
        vm.expectRevert(
            abi.encodeWithSelector(StreamNativeCuratedClock.CuratedClockStopUnchanged.selector)
        );
        h.sale(SALE, 1, true);
        vm.expectRevert(
            abi.encodeWithSelector(StreamNativeCuratedClock.CuratedClockIdentityInvalid.selector)
        );
        h.sale(SALE, 2, false);
        vm.expectRevert(
            abi.encodeWithSelector(StreamNativeCuratedClock.CuratedClockIdentityInvalid.selector)
        );
        h.collection(0, true);
        vm.expectRevert(
            abi.encodeWithSelector(StreamNativeCuratedClock.CuratedClockFuture.selector, uint64(51))
        );
        h.total(SALE, 1, 51);
        vm.warp(uint256(type(uint64).max) + 1);
        vm.expectRevert(
            abi.encodeWithSelector(StreamNativeCuratedClock.CuratedClockOverflow.selector)
        );
        h.global(true);
    }

    function testFuzzThreeSourceHistoryAndWindowsAgainstPerSecondOracle(
        uint64 globalBits,
        uint64 collectionBits,
        uint64 saleBits
    ) external {
        bool g;
        bool c;
        bool l;
        uint64[97] memory totals;
        uint64 commitRemaining = 20;
        uint64 revealRemaining = 30;
        uint64 commitEnd;
        uint64 revealStart;
        uint64 revealEnd;
        for (uint64 i; i < 96; ++i) {
            uint64 at = 90 + i;
            vm.warp(at);
            bool ng = i < 64 && ((globalBits >> i) & 1) != 0;
            bool nc = i < 64 && ((collectionBits >> i) & 1) != 0;
            bool nl = i < 64 && ((saleBits >> i) & 1) != 0;
            if (ng != g) h.global(ng);
            if (nc != c) h.collection(1, nc);
            if (nl != l) h.sale(SALE, 1, nl);
            g = ng;
            c = nc;
            l = nl;
            bool stopped = g || c || l;
            totals[i + 1] = totals[i] + (stopped ? 1 : 0);
            if (at >= 100 && commitRemaining != 0 && !stopped) {
                --commitRemaining;
                if (commitRemaining == 0) {
                    commitEnd = at + 1;
                    revealStart = commitEnd + 10;
                }
            }
            if (revealStart != 0 && at >= revealStart && revealRemaining != 0 && !stopped) {
                --revealRemaining;
                if (revealRemaining == 0) revealEnd = at + 1;
            }
        }
        vm.warp(186);
        for (uint64 i; i <= 96; ++i) {
            require(h.total(SALE, 1, 90 + i) == totals[i], "independent union oracle");
        }
        StreamNativeCuratedClock.View memory v = _view();
        require(commitRemaining == 0 && v.commitClose == commitEnd, "commit oracle");
        require(v.revealOpen == revealStart, "gap oracle");
        if (revealEnd != 0) {
            require(v.revealClose == revealEnd && v.matured, "closed reveal oracle");
        } else {
            require(v.revealClose == 186 + revealRemaining && !v.matured, "remaining reveal oracle");
        }
    }
}
