// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/auctions/StreamEnglishAuctionClock.sol";

interface AuctionClockVm {
    function expectRevert(bytes4 selector) external;
    function expectRevert(bytes calldata reason) external;
}

contract AuctionClockAPI {
    function initialize(
        StreamEnglishAuctionClock.Configuration memory c,
        uint256 reserve,
        uint64 at
    ) external pure returns (StreamEnglishAuctionClock.State memory) {
        return StreamEnglishAuctionClock.initialize(c, reserve, at);
    }

    function minimum(uint256 highest, uint256 reserve, uint16 bps, bool waived)
        external
        pure
        returns (uint256)
    {
        return StreamEnglishAuctionClock.minimumBid(highest, reserve, bps, waived);
    }

    function bid(
        StreamEnglishAuctionClock.Configuration memory c,
        StreamEnglishAuctionClock.State memory s,
        StreamEnglishAuctionClock.Bid memory b,
        uint64 at,
        uint64 toll
    )
        external
        pure
        returns (
            StreamEnglishAuctionClock.State memory,
            StreamEnglishAuctionClock.Transition memory
        )
    {
        return StreamEnglishAuctionClock.acceptBid(c, s, b, at, toll);
    }

    function deadline(
        StreamEnglishAuctionClock.State memory s,
        uint32 window,
        uint64 toll,
        uint64 ceiling
    ) external pure returns (uint64) {
        return StreamEnglishAuctionClock.effectiveFinalizeBy(s, window, toll, ceiling);
    }
}

contract StreamEnglishAuctionClockTest {
    AuctionClockVm private constant vm =
        AuctionClockVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    AuctionClockAPI private api;

    function setUp() public {
        api = new AuctionClockAPI();
    }

    function configuration(bool first)
        private
        pure
        returns (StreamEnglishAuctionClock.Configuration memory c)
    {
        c.startTime = 1000;
        c.endTime = first ? 0 : 10000;
        c.firstBidDuration = first ? 3600 : 0;
        c.antiSnipeWindow = 600;
        c.antiSnipeExtension = 600;
        c.maxTotalExtension = 1800;
        c.startOnFirstBid = first;
    }

    function bidValues(uint256 highest)
        private
        pure
        returns (StreamEnglishAuctionClock.Bid memory b)
    {
        b.highest = highest;
        b.reserve = 100;
        b.incrementBps = 500;
        b.amount = StreamEnglishAuctionClock.minimumBid(highest, b.reserve, b.incrementBps, false);
    }

    function testFirstBidStartsExactlyOnceEvenWithLongAntiSnipe() public pure {
        StreamEnglishAuctionClock.Configuration memory c = configuration(true);
        c.antiSnipeWindow = 86400;
        c.antiSnipeExtension = 86400;
        c.maxTotalExtension = 172800;
        StreamEnglishAuctionClock.State memory s = StreamEnglishAuctionClock.initialize(c, 100, 999);
        StreamEnglishAuctionClock.Transition memory t;
        (s, t) = StreamEnglishAuctionClock.acceptBid(c, s, bidValues(0), 1000, 0);
        require(s.originalEnd == 4600 && s.nominalEnd == 4600 && t.effectiveEnd == 4600);
        require(t.clockStarted && t.extended && t.previousEnd == 0 && t.extensionDelta == 0);
        require(!t.budgetWarning && t.usedExtension == 0 && t.remainingExtension == 172800);
        (s, t) = StreamEnglishAuctionClock.acceptBid(c, s, bidValues(100), 1001, 0);
        require(s.originalEnd == 4600 && s.nominalEnd == 87401 && !t.clockStarted);
        require(t.usedExtension == 82801 && t.extensionDelta == 82801);
    }

    function testPresetFirstBidCanExtendAndWarningOccursOnce() public pure {
        StreamEnglishAuctionClock.Configuration memory c = configuration(false);
        StreamEnglishAuctionClock.State memory s = StreamEnglishAuctionClock.initialize(c, 0, 1000);
        StreamEnglishAuctionClock.Transition memory t;
        uint256 warnings;
        for (uint256 i; i < 5; ++i) {
            (s, t) = StreamEnglishAuctionClock.acceptBid(
                c, s, bidValues(i == 0 ? 0 : 100), s.nominalEnd - 1, 0
            );
            if (t.budgetWarning) ++warnings;
            require(t.usedExtension + t.remainingExtension == c.maxTotalExtension);
        }
        require(warnings == 1 && s.budgetWarningEmitted && s.originalEnd == 10000);
        require(s.nominalEnd == 11800 && t.budgetExhausted && !t.extended && t.extensionDelta == 0);
    }

    function testPauseTollIsSeparateFromExtensionBudget() public pure {
        StreamEnglishAuctionClock.Configuration memory c = configuration(false);
        StreamEnglishAuctionClock.State memory s =
            StreamEnglishAuctionClock.initialize(c, 100, 1000);
        StreamEnglishAuctionClock.Transition memory t;
        (s, t) = StreamEnglishAuctionClock.acceptBid(c, s, bidValues(100), 13999, 4000);
        require(s.originalEnd == 10000 && s.nominalEnd == 10599);
        require(t.previousEnd == 14000 && t.effectiveEnd == 14599 && t.usedExtension == 599);
        require(StreamEnglishAuctionClock.effectiveEnd(s, 5000) == 15599);
    }

    function testStrictWindowAndDeadlineBoundaries() public {
        StreamEnglishAuctionClock.Configuration memory c = configuration(false);
        StreamEnglishAuctionClock.State memory s =
            StreamEnglishAuctionClock.initialize(c, 100, 1000);
        StreamEnglishAuctionClock.Transition memory t;
        (, t) = StreamEnglishAuctionClock.acceptBid(c, s, bidValues(100), 9400, 0);
        require(!t.extended && t.effectiveEnd == 10000);
        (, t) = StreamEnglishAuctionClock.acceptBid(c, s, bidValues(100), 9401, 0);
        require(t.extended && t.effectiveEnd == 10001);
        vm.expectRevert(StreamEnglishAuctionClock.AuctionClockEnded.selector);
        api.bid(c, s, bidValues(100), 10000, 0);
        vm.expectRevert(StreamEnglishAuctionClock.AuctionClockNotStarted.selector);
        api.bid(c, s, bidValues(0), 999, 0);
    }

    function testInvalidReserveBidCannotStartAndUnstartedDoesNotExpire() public {
        StreamEnglishAuctionClock.Configuration memory c = configuration(true);
        StreamEnglishAuctionClock.State memory s =
            StreamEnglishAuctionClock.initialize(c, 100, 1000);
        require(StreamEnglishAuctionClock.effectiveEnd(s, 9999) == 0);
        require(StreamEnglishAuctionClock.effectiveFinalizeBy(s, 86400, 9999, 0) == 0);
        require(!StreamEnglishAuctionClock.expired(0, type(uint64).max));
        StreamEnglishAuctionClock.Bid memory b = bidValues(0);
        b.amount = 99;
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamEnglishAuctionClock.AuctionBidTooLow.selector, uint256(100)
            )
        );
        api.bid(c, s, b, 1000, 0);
        vm.expectRevert(StreamEnglishAuctionClock.AuctionClockStateInvalid.selector);
        api.bid(c, s, bidValues(0), 1000, 1);
        (s,) = api.bid(c, s, bidValues(0), 1000, 0);
        require(s.nominalEnd == 4600);
    }

    function testConfigurationRejectsMixedModesAndUnwaivedZeros() public {
        StreamEnglishAuctionClock.Configuration memory c = configuration(true);
        vm.expectRevert(StreamEnglishAuctionClock.AuctionClockConfigurationInvalid.selector);
        api.initialize(c, 0, 1000);
        c.endTime = 9000;
        vm.expectRevert(StreamEnglishAuctionClock.AuctionClockConfigurationInvalid.selector);
        api.initialize(c, 100, 1000);
        c = configuration(true);
        c.firstBidDuration = 3599;
        vm.expectRevert(StreamEnglishAuctionClock.AuctionClockConfigurationInvalid.selector);
        api.initialize(c, 100, 1000);
        c.firstBidDuration = 2592001;
        vm.expectRevert(StreamEnglishAuctionClock.AuctionClockConfigurationInvalid.selector);
        api.initialize(c, 100, 1000);
        c = configuration(false);
        c.firstBidDuration = 1;
        vm.expectRevert(StreamEnglishAuctionClock.AuctionClockConfigurationInvalid.selector);
        api.initialize(c, 100, 1000);
        c = configuration(false);
        c.endTime = 1000;
        vm.expectRevert(StreamEnglishAuctionClock.AuctionClockConfigurationInvalid.selector);
        api.initialize(c, 100, 1000);
        c = configuration(false);
        c.hardClose = true;
        vm.expectRevert(StreamEnglishAuctionClock.AuctionClockConfigurationInvalid.selector);
        api.initialize(c, 100, 1000);
        c = configuration(false);
        c.antiSnipeWindow = 0;
        vm.expectRevert(StreamEnglishAuctionClock.AuctionClockConfigurationInvalid.selector);
        api.initialize(c, 100, 1000);
        c = configuration(false);
        c.maxTotalExtension = 599;
        vm.expectRevert(StreamEnglishAuctionClock.AuctionClockConfigurationInvalid.selector);
        api.initialize(c, 100, 1000);
        c = configuration(false);
        c.maxTotalExtension = 604801;
        vm.expectRevert(StreamEnglishAuctionClock.AuctionClockConfigurationInvalid.selector);
        api.initialize(c, 100, 1000);
    }

    function testHardCloseStillTollsWithoutAntiSnipe() public pure {
        StreamEnglishAuctionClock.Configuration memory c = configuration(false);
        c.hardClose = true;
        c.antiSnipeWindow = 0;
        c.antiSnipeExtension = 0;
        c.maxTotalExtension = 0;
        StreamEnglishAuctionClock.State memory s = StreamEnglishAuctionClock.initialize(c, 0, 1000);
        StreamEnglishAuctionClock.Transition memory t;
        (s, t) = StreamEnglishAuctionClock.acceptBid(c, s, bidValues(100), 14999, 5000);
        require(s.nominalEnd == 10000 && t.effectiveEnd == 15000 && !t.extended && !t.budgetWarning);
    }

    function testMinimumBidRoundsUpAndExplicitWaiverStillRequiresIncrease() public {
        require(api.minimum(0, 0, 100, false) == 1);
        require(api.minimum(0, 1000, 100, false) == 1000);
        require(api.minimum(101, 0, 500, false) == 107);
        require(api.minimum(101, 0, 0, true) == 102);
        require(api.minimum(101, 0, 10000, false) == 202);
        vm.expectRevert(StreamEnglishAuctionClock.AuctionIncrementInvalid.selector);
        api.minimum(1, 0, 0, false);
        vm.expectRevert(StreamEnglishAuctionClock.AuctionIncrementInvalid.selector);
        api.minimum(1, 0, 10001, true);
        vm.expectRevert(StreamEnglishAuctionClock.AuctionBidOverflow.selector);
        api.minimum(type(uint256).max, 0, 0, true);
        vm.expectRevert(StreamEnglishAuctionClock.AuctionBidOverflow.selector);
        api.minimum(type(uint256).max, 0, 10000, false);
    }

    function testSignedCeilingSurvivesPauseAndCanPrecedeTolledBidEnd() public pure {
        StreamEnglishAuctionClock.State memory s =
            StreamEnglishAuctionClock.State(10000, 10000, false);
        require(StreamEnglishAuctionClock.effectiveFinalizeBy(s, 86400, 1000, 0) == 97400);
        uint64 signedCeiling = 96400;
        require(
            StreamEnglishAuctionClock.effectiveFinalizeBy(s, 86400, 100000, signedCeiling)
                == signedCeiling
        );
        require(StreamEnglishAuctionClock.effectiveEnd(s, 100000) == 110000);
        require(!StreamEnglishAuctionClock.expired(signedCeiling, signedCeiling));
        require(StreamEnglishAuctionClock.expired(signedCeiling, signedCeiling + 1));
    }

    function testCheckedTimestampBoundsAndSignedCapBeforeOverflow() public {
        StreamEnglishAuctionClock.Configuration memory c = configuration(true);
        StreamEnglishAuctionClock.State memory s =
            StreamEnglishAuctionClock.initialize(c, 100, 1000);
        vm.expectRevert(StreamEnglishAuctionClock.AuctionClockOverflow.selector);
        api.bid(c, s, bidValues(0), type(uint64).max - 100, 0);
        s = StreamEnglishAuctionClock.State(type(uint64).max - 10, type(uint64).max - 10, false);
        vm.expectRevert(StreamEnglishAuctionClock.AuctionClockOverflow.selector);
        api.deadline(s, 86400, 0, 0);
        require(api.deadline(s, 86400, 0, type(uint64).max - 1) == type(uint64).max - 1);
        vm.expectRevert(StreamEnglishAuctionClock.AuctionSettlementWindowInvalid.selector);
        api.deadline(s, 86399, 0, 0);
        vm.expectRevert(StreamEnglishAuctionClock.AuctionSettlementWindowInvalid.selector);
        api.deadline(s, 7776001, 0, 0);
    }

    function testFuzzIncrementMatchesWideIndependentCeiling(uint128 price, uint16 rawBps)
        public
        pure
    {
        uint256 highest = uint256(price) + 1;
        uint16 bps = uint16(uint256(rawBps) % 10001);
        uint256 delta = (highest * bps + 9999) / 10000;
        if (delta == 0) delta = 1;
        require(StreamEnglishAuctionClock.minimumBid(highest, 0, bps, true) == highest + delta);
    }

    function testFuzzPauseTranslationPreservesNominalBudget(uint32 rawToll, uint16 rawOffset)
        public
        pure
    {
        StreamEnglishAuctionClock.Configuration memory c = configuration(false);
        StreamEnglishAuctionClock.State memory initial =
            StreamEnglishAuctionClock.initialize(c, 100, 1000);
        uint64 at = 9401 + uint64(rawOffset % 599);
        (
            StreamEnglishAuctionClock.State memory plain,
            StreamEnglishAuctionClock.Transition memory a
        ) = StreamEnglishAuctionClock.acceptBid(c, initial, bidValues(100), at, 0);
        (
            StreamEnglishAuctionClock.State memory paused,
            StreamEnglishAuctionClock.Transition memory b
        ) = StreamEnglishAuctionClock.acceptBid(c, initial, bidValues(100), at + rawToll, rawToll);
        require(plain.nominalEnd == paused.nominalEnd && plain.originalEnd == paused.originalEnd);
        require(a.usedExtension == b.usedExtension && a.remainingExtension == b.remainingExtension);
        require(
            b.effectiveEnd == uint256(a.effectiveEnd) + rawToll
                && a.budgetWarning == b.budgetWarning
        );
    }

    function testFuzzFirstBidHasNoAntiSnipeCharge(uint32 rawDuration, uint32 rawTime) public pure {
        StreamEnglishAuctionClock.Configuration memory c = configuration(true);
        c.firstBidDuration = uint32(3600 + uint256(rawDuration) % (2592000 - 3600 + 1));
        c.antiSnipeWindow = 86400;
        c.antiSnipeExtension = 86400;
        c.maxTotalExtension = 604800;
        uint64 at = 1000 + uint64(rawTime);
        StreamEnglishAuctionClock.State memory s = StreamEnglishAuctionClock.initialize(c, 100, 999);
        StreamEnglishAuctionClock.Transition memory t;
        (s, t) = StreamEnglishAuctionClock.acceptBid(c, s, bidValues(0), at, 0);
        require(s.nominalEnd == uint256(at) + c.firstBidDuration && s.originalEnd == s.nominalEnd);
        require(t.usedExtension == 0 && t.remainingExtension == 604800 && !t.budgetWarning);
    }
}
