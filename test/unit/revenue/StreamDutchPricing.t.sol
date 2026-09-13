// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/mint/StreamDutchPricing.sol";

interface DutchPricingVm {
    function expectRevert(bytes calldata reason) external;
}

/// @dev Pure arithmetic only; not an admitted consumer or paid-mint proof.
contract DutchPricingHarness {
    function validate(IStreamDutchPriceSchedule.DutchPriceSchedule memory s, bool free)
        external
        pure
    {
        StreamDutchPricing.validate(s, free);
    }

    function price(IStreamDutchPriceSchedule.DutchPriceSchedule memory s, uint256 timestamp)
        external
        pure
        returns (uint256)
    {
        return StreamDutchPricing.price(s, timestamp);
    }

    function scheduleHash(
        IStreamDutchPriceSchedule.DutchPriceSchedule memory s,
        uint256 chainId,
        address adapter,
        bytes32 saleId
    ) external pure returns (bytes32) {
        return StreamDutchPricing.scheduleHash(s, chainId, adapter, saleId);
    }
}

contract StreamDutchPricingTest {
    DutchPricingVm private constant vm =
        DutchPricingVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    DutchPricingHarness private pricing;

    function setUp() public {
        pricing = new DutchPricingHarness();
    }

    function _linear() private pure returns (IStreamDutchPriceSchedule.DutchPriceSchedule memory) {
        return IStreamDutchPriceSchedule.DutchPriceSchedule(1000, 101, 100, 110, 0, 0, 0);
    }

    function _invalid(IStreamDutchPriceSchedule.DutchPriceSchedule memory s, bool free) private {
        vm.expectRevert(
            abi.encodeWithSelector(IStreamDutchPriceSchedule.DutchScheduleInvalid.selector)
        );
        pricing.validate(s, free);
    }

    function testLinearIndependentRemainderAndStartEndQuotes() public view {
        IStreamDutchPriceSchedule.DutchPriceSchedule memory s = _linear();
        pricing.validate(s, false);
        require(pricing.price(s, 0) == 1000 && pricing.price(s, 100) == 1000, "start quote");
        require(pricing.price(s, 101) == 911, "one-tenth rounds charge up");
        require(pricing.price(s, 105) == 551, "half rounds charge up");
        require(pricing.price(s, 109) == 191, "nine-tenths remainder");
        require(pricing.price(s, 110) == 101 && pricing.price(s, type(uint256).max) == 101, "rest");
    }

    function testDeclaredZeroDoesNotAppearEarlyInLinearRounding() public {
        IStreamDutchPriceSchedule.DutchPriceSchedule memory s = _linear();
        s.startPrice = 3;
        s.restingPrice = 0;
        _invalid(s, false);
        pricing.validate(s, true);
        require(pricing.price(s, 109) == 1 && pricing.price(s, 110) == 0, "zero boundary");
        s.startPrice = 0;
        _invalid(s, true);
    }

    function testPositiveFlatScheduleRemainsValid() public view {
        IStreamDutchPriceSchedule.DutchPriceSchedule memory s = _linear();
        s.restingPrice = s.startPrice;
        pricing.validate(s, false);
        require(pricing.price(s, 105) == 1000, "flat");
        s.decayKind = 1;
        s.stepSeconds = 3;
        s.stepAmount = 999;
        pricing.validate(s, false);
        require(pricing.price(s, 105) == 1000, "flat stepped");
    }

    function testSteppedBoundariesAndFinalPartialInterval() public view {
        IStreamDutchPriceSchedule.DutchPriceSchedule memory s =
            IStreamDutchPriceSchedule.DutchPriceSchedule(10, 2, 100, 110, 1, 4, 3);
        pricing.validate(s, false);
        require(pricing.price(s, 103) == 10, "before step");
        require(pricing.price(s, 104) == 7 && pricing.price(s, 107) == 7, "first step");
        require(pricing.price(s, 108) == 4 && pricing.price(s, 109) == 4, "second step");
        require(pricing.price(s, 110) == 2, "partial last interval drops to rest");
    }

    function testSteppedOversizedReductionClampsWithoutUnderflow() public view {
        IStreamDutchPriceSchedule.DutchPriceSchedule memory s =
            IStreamDutchPriceSchedule.DutchPriceSchedule(
                10, 2, 1, type(uint64).max, 1, 1, type(uint96).max
            );
        pricing.validate(s, false);
        require(pricing.price(s, type(uint64).max - 1) == 2, "wide multiply clamps");
    }

    function testInvalidShapeAndReservedKindsReject() public {
        IStreamDutchPriceSchedule.DutchPriceSchedule memory s = _linear();
        s.restingPrice = 1001;
        _invalid(s, true);
        s = _linear();
        s.endTime = s.startTime;
        _invalid(s, false);
        s.endTime = s.startTime - 1;
        _invalid(s, false);
        s = _linear();
        s.decayKind = 2;
        _invalid(s, false);
        s.decayKind = 255;
        _invalid(s, true);
    }

    function testUnusedLinearAndRequiredSteppedFieldsReject() public {
        IStreamDutchPriceSchedule.DutchPriceSchedule memory s = _linear();
        s.stepSeconds = 1;
        _invalid(s, false);
        s.stepSeconds = 0;
        s.stepAmount = 1;
        _invalid(s, false);
        s.decayKind = 1;
        _invalid(s, false);
        s.stepSeconds = 1;
        s.stepAmount = 0;
        _invalid(s, false);
    }

    function testScheduleGoldenPinsLiteralDomainAndEveryNamedField() public view {
        IStreamDutchPriceSchedule.DutchPriceSchedule memory s = _linear();
        bytes32 expected = keccak256(
            abi.encode(
                bytes32(0xf22d2e97f1de4a74f3f96b4bd6c3dc8bd6a378980328e92785afa57f0c3957ad),
                uint256(31337),
                address(0x1234),
                bytes32(uint256(77)),
                uint96(1000),
                uint96(101),
                uint64(100),
                uint64(110),
                uint8(0),
                uint32(0),
                uint96(0)
            )
        );
        require(
            pricing.scheduleHash(s, 31337, address(0x1234), bytes32(uint256(77))) == expected,
            "golden"
        );
        require(
            pricing.scheduleHash(s, 1, address(0x1234), bytes32(uint256(77))) != expected, "chain"
        );
        require(
            pricing.scheduleHash(s, 31337, address(0x1235), bytes32(uint256(77))) != expected,
            "consumer"
        );
        require(
            pricing.scheduleHash(s, 31337, address(0x1234), bytes32(uint256(78))) != expected,
            "sale"
        );
        for (uint256 field; field < 7; ++field) {
            IStreamDutchPriceSchedule.DutchPriceSchedule memory changed = _linear();
            if (field == 0) changed.startPrice++;
            else if (field == 1) changed.restingPrice++;
            else if (field == 2) changed.startTime++;
            else if (field == 3) changed.endTime++;
            else if (field == 4) changed.decayKind++;
            else if (field == 5) changed.stepSeconds++;
            else changed.stepAmount++;
            require(
                pricing.scheduleHash(changed, 31337, address(0x1234), bytes32(uint256(77)))
                    != expected,
                "field"
            );
        }
    }

    function testFuzzLinearPriceIsCeilingOfRemainingInterpolation(
        uint96 start,
        uint96 rest,
        uint64 durationSeed,
        uint64 elapsedSeed
    ) public view {
        if (start == 0) start = 1;
        rest = uint96(uint256(rest) % (uint256(start) + 1));
        uint256 duration = uint256(durationSeed) + 1;
        if (duration == type(uint64).max + uint256(1)) duration--;
        uint256 elapsed = uint256(elapsedSeed) % (duration + 1);
        IStreamDutchPriceSchedule.DutchPriceSchedule memory s =
            IStreamDutchPriceSchedule.DutchPriceSchedule(start, rest, 0, uint64(duration), 0, 0, 0);
        pricing.validate(s, true);
        uint256 charged = pricing.price(s, elapsed);
        uint256 numerator = uint256(start) * (duration - elapsed) + uint256(rest) * elapsed;
        require(charged * duration >= numerator, "not below exact rational");
        require(charged == 0 || (charged - 1) * duration < numerator, "smallest upper integer");
        if (elapsed < duration) require(charged != 0, "declared zero not early");
    }

    function testFuzzSteppedMonotonicAndBounded(
        uint96 start,
        uint96 rest,
        uint32 stepSeed,
        uint96 amountSeed,
        uint64 timeSeed
    ) public view {
        if (start == 0) start = 1;
        rest = uint96(uint256(rest) % (uint256(start) + 1));
        uint32 step = stepSeed == 0 ? 1 : stepSeed;
        uint96 amount = amountSeed == 0 ? 1 : amountSeed;
        IStreamDutchPriceSchedule.DutchPriceSchedule memory s =
            IStreamDutchPriceSchedule.DutchPriceSchedule(
                start, rest, 0, type(uint64).max, 1, step, amount
            );
        pricing.validate(s, true);
        uint256 beforePrice = pricing.price(s, timeSeed);
        uint256 afterPrice = pricing.price(s, uint256(timeSeed) + 1);
        require(
            beforePrice <= start && afterPrice >= rest && afterPrice <= beforePrice,
            "monotonic bounds"
        );
    }
}
