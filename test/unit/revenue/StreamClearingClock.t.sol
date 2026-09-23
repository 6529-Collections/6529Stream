// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../../smart-contracts/domains/mint/StreamClearingClock.sol";

contract ClearingClockHarness {
    using StreamClearingClock for StreamClearingClock.History;
    StreamClearingClock.History private history;

    function global(bool value) external {
        history.setGlobal(value);
    }

    function local(bytes32 saleId, bool value) external {
        history.setLocal(saleId, value);
    }

    function at(bytes32 saleId, uint64 timestamp) external view returns (uint64) {
        return history.unionTotalAt(saleId, timestamp);
    }

    function toll(bytes32 saleId, uint64 referenceTime) external view returns (uint64) {
        return history.tollSince(saleId, referenceTime);
    }

    function paused(bytes32 saleId) external view returns (bool) {
        return history.globalPaused() || history.localPaused(saleId);
    }
}

contract StreamClearingClockTest is CharacterizationTestBase {
    ClearingClockHarness private h;
    bytes32 private constant SALE = bytes32(uint256(1));

    function setUp() external {
        vm.warp(100);
        h = new ClearingClockHarness();
    }

    function testUnattendedCloseCrossingBothPausesAndLaterGlobalChanges() external {
        vm.warp(110);
        h.global(true);
        vm.warp(120);
        h.local(SALE, true);
        // Configured close at 125 has no transaction.
        vm.warp(130);
        h.global(false);
        vm.warp(140);
        h.global(true);
        vm.warp(150);
        h.local(SALE, false);
        vm.warp(160);
        h.global(false);
        vm.warp(170);
        h.global(true);
        vm.warp(175);
        h.global(false);
        vm.warp(190);
        require(h.at(SALE, 125) == 15, "close prefix");
        require(h.at(SALE, 190) == 55, "union [110,160)+[170,175)");
        require(h.toll(SALE, 125) == 40, "only overlap since close");
        require(h.at(bytes32(uint256(2)), 190) == 45, "other sale has no local pause");
    }

    function testReverseOverlapAndEveryHistoricalBoundary() external {
        vm.warp(110);
        h.local(SALE, true);
        vm.warp(120);
        h.global(true);
        vm.warp(130);
        h.local(SALE, false);
        vm.warp(140);
        h.global(false);
        vm.warp(150);
        h.local(SALE, true);
        vm.warp(155);
        h.local(SALE, false);
        vm.warp(170);
        for (uint64 t = 100; t <= 170; ++t) {
            uint64 expected;
            for (uint64 second = 100; second < t; ++second) {
                if ((second >= 110 && second < 140) || (second >= 150 && second < 155)) ++expected;
            }
            require(h.at(SALE, t) == expected, "independent interval union");
        }
    }

    function testLastSameTimestampCheckpointAndZeroLengthTransitions() external {
        vm.warp(110);
        h.global(true);
        h.global(false);
        h.global(true);
        h.local(SALE, true);
        h.local(SALE, false);
        h.local(SALE, true);
        vm.warp(120);
        h.global(false);
        h.local(SALE, false);
        h.global(true);
        h.global(false);
        require(h.at(SALE, 110) == 0, "no zero-length toll");
        require(h.at(SALE, 115) == 5, "last same-second state");
        require(h.at(SALE, 120) == 10 && !h.paused(SALE), "end last state");
        vm.warp(200);
        require(h.toll(SALE, 100) == 10, "stays ended");
    }

    function testNoPauseAndRejectedFutureReadOrDuplicateTransition() external {
        vm.warp(200);
        require(h.at(SALE, 150) == 0 && h.toll(SALE, 110) == 0, "no pause parity");
        vm.expectRevert(
            abi.encodeWithSelector(StreamClearingClock.ClearingClockFuture.selector, uint64(201))
        );
        h.at(SALE, 201);
        vm.expectRevert(abi.encodeWithSelector(StreamClearingClock.ClearingPauseUnchanged.selector));
        h.global(false);
        h.global(true);
        vm.expectRevert(abi.encodeWithSelector(StreamClearingClock.ClearingPauseUnchanged.selector));
        h.global(true);
        require(h.at(SALE, 200) == 0, "failures do not rewrite history");
    }

    function testElapsedUnpausedTimeCannotReopenExpiredWindow() external {
        uint64 referenceTime = 110;
        vm.warp(120);
        h.global(true);
        vm.warp(125);
        h.global(false);
        vm.warp(146);
        // Window 30: effective end 145. A new pause after expiry cannot revive it.
        require(block.timestamp - referenceTime - h.toll(SALE, referenceTime) == 31, "expired");
        h.local(SALE, true);
        vm.warp(200);
        require(
            block.timestamp - referenceTime - h.toll(SALE, referenceTime) == 31, "still expired"
        );
        h.local(SALE, false);
        vm.warp(201);
        require(block.timestamp - referenceTime - h.toll(SALE, referenceTime) == 32, "advances");
    }

    function testFuzzHistoricalUnionAgainstPerSecondOracle(uint256 globalBits, uint256 localBits)
        external
    {
        bool g;
        bool l;
        uint64[65] memory totals;
        for (uint64 i; i < 64; ++i) {
            vm.warp(100 + i);
            bool ng = ((globalBits >> i) & 1) != 0;
            bool nl = ((localBits >> i) & 1) != 0;
            if (ng != g) {
                h.global(ng);
                g = ng;
            }
            if (nl != l) {
                h.local(SALE, nl);
                l = nl;
            }
            totals[i + 1] = totals[i] + (g || l ? 1 : 0);
        }
        vm.warp(164);
        for (uint64 i; i <= 64; ++i) {
            require(h.at(SALE, 100 + i) == totals[i], "history oracle");
        }
        require(h.toll(SALE, 132) == totals[64] - totals[32], "unattended midpoint");
    }
}
