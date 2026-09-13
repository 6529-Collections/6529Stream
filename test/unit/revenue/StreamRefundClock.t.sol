// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/mint/StreamRefundClock.sol";

interface RefundClockVm {
    function warp(uint256 timestamp) external;
    function expectRevert(bytes calldata reason) external;
}

/// @dev Arithmetic harness only: no adapter roles, purchase or money authority.
contract RefundClockHarness {
    StreamRefundClock.GlobalClock private global;
    mapping(bytes32 => StreamRefundClock.SaleClock) private sales;

    function setGlobal(bool paused) external {
        StreamRefundClock.setGlobal(global, paused);
    }

    function setSale(bytes32 id, bool paused) external {
        StreamRefundClock.setSale(global, sales[id], paused);
    }

    function total(bytes32 id) external view returns (uint64) {
        return StreamRefundClock.unionTotal(global, sales[id]);
    }

    function deadline(uint64 nominal, uint64 toll, uint64 escape) external pure returns (uint64) {
        return StreamRefundClock.cappedDeadline(nominal, toll, escape);
    }
}

contract StreamRefundClockTest {
    RefundClockVm private constant vm =
        RefundClockVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    RefundClockHarness private clock;
    bytes32 private constant SALE = bytes32(uint256(1));

    function setUp() public {
        vm.warp(1000);
        clock = new RefundClockHarness();
    }

    function testGlobalThenLocalOverlapCountsOnceAcrossBothResumes() public {
        clock.setGlobal(true);
        vm.warp(1010);
        clock.setSale(SALE, true);
        vm.warp(1020);
        clock.setGlobal(false);
        require(clock.total(SALE) == 20, "overlap counted once");
        vm.warp(1030);
        clock.setSale(SALE, false);
        vm.warp(1100);
        require(clock.total(SALE) == 30, "global then local union");
        require(clock.total(bytes32(uint256(2))) == 20, "unrelated sale excludes local");
    }

    function testLocalThenGlobalOverlapCountsOnceAcrossBothResumes() public {
        clock.setSale(SALE, true);
        vm.warp(1010);
        clock.setGlobal(true);
        vm.warp(1020);
        clock.setSale(SALE, false);
        vm.warp(1030);
        clock.setGlobal(false);
        require(clock.total(SALE) == 30, "local then global union");
        require(clock.total(bytes32(uint256(2))) == 20, "other sale only global");
    }

    function testMultipleGlobalIntervalsInsideOneLocalPause() public {
        clock.setSale(SALE, true);
        vm.warp(1010);
        clock.setGlobal(true);
        vm.warp(1020);
        clock.setGlobal(false);
        vm.warp(1030);
        clock.setGlobal(true);
        vm.warp(1040);
        clock.setGlobal(false);
        vm.warp(1050);
        clock.setSale(SALE, false);
        require(clock.total(SALE) == 50, "all overlaps excluded");
        require(clock.total(bytes32(uint256(2))) == 20, "global sum retained");
    }

    function testPurchaseBaselineExcludesEveryPriorInterval() public {
        clock.setGlobal(true);
        vm.warp(1010);
        clock.setGlobal(false);
        clock.setSale(SALE, true);
        vm.warp(1020);
        clock.setSale(SALE, false);
        uint64 purchased = clock.total(SALE);
        vm.warp(1030);
        clock.setGlobal(true);
        vm.warp(1040);
        clock.setGlobal(false);
        require(clock.total(SALE) - purchased == 10, "only post-purchase toll");
    }

    function testCappedDeadlineDoesNotOverflowAndPreservesExactEquality() public view {
        require(clock.deadline(100, 9, 110) == 109, "before escape");
        require(clock.deadline(100, 10, 110) == 110, "equal escape");
        require(clock.deadline(100, 11, 110) == 110, "beyond escape");
        require(
            clock.deadline(type(uint64).max - 1, type(uint64).max, type(uint64).max)
                == type(uint64).max,
            "saturated without uint64 overflow"
        );
    }

    function testNoOpPauseTransitionsReject() public {
        vm.expectRevert(abi.encodeWithSelector(StreamRefundClock.RefundPauseUnchanged.selector));
        clock.setGlobal(false);
        vm.expectRevert(abi.encodeWithSelector(StreamRefundClock.RefundPauseUnchanged.selector));
        clock.setSale(SALE, false);
        clock.setGlobal(true);
        vm.expectRevert(abi.encodeWithSelector(StreamRefundClock.RefundPauseUnchanged.selector));
        clock.setGlobal(true);
    }

    function testTimestampBeyondDeclaredWidthRejects() public {
        vm.warp(uint256(type(uint64).max) + 1);
        vm.expectRevert(abi.encodeWithSelector(StreamRefundClock.RefundClockOverflow.selector));
        clock.setGlobal(true);
    }

    function testFuzzUnionMatchesIndependentElapsedIntervalOracle(uint256 seed) public {
        bool globalPaused;
        bool salePaused;
        uint64 timestamp = 1000;
        uint64 expected;
        for (uint256 i; i < 64; ++i) {
            seed = uint256(keccak256(abi.encode(seed, i)));
            uint64 elapsed = uint64(seed % 1000 + 1);
            timestamp += elapsed;
            if (globalPaused || salePaused) expected += elapsed;
            vm.warp(timestamp);
            require(clock.total(SALE) == expected, "independent interval union");
            if (seed & 1 == 0) {
                globalPaused = !globalPaused;
                clock.setGlobal(globalPaused);
            } else {
                salePaused = !salePaused;
                clock.setSale(SALE, salePaused);
            }
        }
    }
}
