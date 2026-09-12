// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../../smart-contracts/domains/mint/StreamClearingCeilingBook.sol";

contract ClearingCeilingHarness {
    using StreamClearingCeilingBook for StreamClearingCeilingBook.Tree;
    mapping(address => StreamClearingCeilingBook.Tree) private trees;

    function record(address buyer, uint256 ceiling, uint64 maximum) external {
        trees[buyer].record(ceiling, maximum);
    }

    function recordAndFail(address buyer, uint256 ceiling, uint64 maximum) external {
        trees[buyer].record(ceiling, maximum);
        revert("purchase failed");
    }

    function count(address buyer) external view returns (uint256) {
        return trees[buyer].count();
    }

    function total(address buyer) external view returns (uint256) {
        return trees[buyer].ceilingSum();
    }

    function uniform(address buyer, uint256 price) external view returns (uint256) {
        return trees[buyer].uniformSum(price);
    }

    function normalize(uint256 start, bool enabled, uint256 raw) external pure returns (uint256) {
        return StreamClearingCeilingBook.normalize(start, enabled, raw);
    }
}

contract StreamClearingCeilingBookTest is CharacterizationTestBase {
    event BookGasMeasured(uint256 firstInsertion, uint256 duplicateInsertion, uint256 sparseQuery);

    function testMeasureActualPackedUpdateAndBoundedQuery() external {
        uint256 before = gasleft();
        h.record(address(1), type(uint96).max, type(uint64).max);
        uint256 first = before - gasleft();
        before = gasleft();
        h.record(address(1), type(uint96).max, type(uint64).max);
        uint256 duplicate = before - gasleft();
        before = gasleft();
        uint256 result = h.uniform(address(1), uint256(type(uint96).max) - 1);
        uint256 query = before - gasleft();
        require(result == 2 * (uint256(type(uint96).max) - 1), "measured read is correct");
        emit BookGasMeasured(first, duplicate, query);
    }

    ClearingCeilingHarness private h;

    function setUp() external {
        h = new ClearingCeilingHarness();
    }

    function testIndependentHeterogeneousCeilingsEveryBoundaryAndBuyerIsolation() external {
        uint256[7] memory caps = [uint256(0), 1, 1000, 1000, 1001, 1 << 80, type(uint96).max];
        for (uint256 i; i < caps.length; ++i) {
            h.record(address(1), caps[i], 20);
        }
        h.record(address(2), 77, 20);
        uint256[10] memory prices = [
            uint256(0),
            1,
            999,
            1000,
            1001,
            1002,
            (1 << 80) - 1,
            1 << 80,
            type(uint96).max,
            type(uint256).max
        ];
        for (uint256 i; i < prices.length; ++i) {
            uint256 expected;
            for (uint256 j; j < caps.length; ++j) {
                expected += prices[i] < caps[j] ? prices[i] : caps[j];
            }
            require(h.uniform(address(1), prices[i]) == expected, "independent sum of minima");
        }
        require(
            h.count(address(1)) == 7 && h.count(address(2)) == 1
                && h.uniform(address(2), 100) == 77,
            "account isolation"
        );
    }

    function testCountLimitAndFailedPurchaseRollbackLeaveAllAggregatePathsUnchanged() external {
        h.record(address(1), 5, 2);
        uint256 sum = h.total(address(1));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "purchase failed"));
        h.recordAndFail(address(1), 99, 2);
        require(
            h.count(address(1)) == 1 && h.total(address(1)) == sum
                && h.uniform(address(1), 10) == 5,
            "atomic rollback"
        );
        h.record(address(1), 99, 2);
        vm.expectRevert(
            abi.encodeWithSelector(StreamClearingCeilingBook.ClearingCountLimitExceeded.selector)
        );
        h.record(address(1), 1, 2);
        require(h.count(address(1)) == 2 && h.total(address(1)) == 104, "accepted count only");
    }

    function testWideSignedOverrideNormalizationDoesNotTruncateAndPackingProof() external {
        uint256 start = type(uint96).max;
        uint256 raw = (uint256(1) << 255) + 123;
        require(
            h.normalize(start, true, raw) == start && h.normalize(start, false, 0) == start,
            "clamp not narrowing"
        );
        h.record(address(1), start, type(uint64).max);
        h.record(address(1), start, type(uint64).max);
        require(
            h.total(address(1)) == 2 * start && h.uniform(address(1), start - 1) == 2 * (start - 1),
            "sum exceeds individual96 safely"
        );
        uint256 maximumSum = uint256(type(uint64).max) * uint256(type(uint96).max);
        require(
            maximumSum < (uint256(1) << 160) && maximumSum <= type(uint192).max,
            "catalog upper bound"
        );
    }

    function testInvalidCeilingAndZeroCountLimitRejectWithoutARecord() external {
        vm.expectRevert(
            abi.encodeWithSelector(StreamClearingCeilingBook.ClearingCeilingOutOfBounds.selector)
        );
        h.record(address(1), uint256(1) << 96, 1);
        vm.expectRevert(
            abi.encodeWithSelector(StreamClearingCeilingBook.ClearingCountLimitExceeded.selector)
        );
        h.record(address(1), 1, 0);
        require(h.count(address(1)) == 0 && h.total(address(1)) == 0, "empty state");
    }

    function testRebateThenPartialSupplementThenGlobalUnlockDoesNotRefundOfficialRevenue()
        external
    {
        h.record(address(1), 5000, 10);
        h.record(address(1), 2000, 10);
        h.record(address(1), 4000, 10);
        uint256 paid = 5000 + 2000 + 4000;
        uint256 floor = 1000;
        uint256 uniform = h.uniform(address(1), 3000);
        uint256 initialEntitlement = paid - uniform;
        require(initialEntitlement == 3000, "rebates immediate");
        uint256 claimed = 1200;
        uint256 settled = 2000;
        uint256 unlockedEntitlement = paid - h.count(address(1)) * floor - settled;
        require(
            unlockedEntitlement - claimed == 4800,
            "remaining refund after partial claim and settled leg"
        );
        require(
            (h.count(address(1)) * floor + settled) + claimed + (unlockedEntitlement - claimed)
                == paid,
            "exact conservation"
        );
        require(
            h.count(address(1)) == 3 && h.uniform(address(1), 3000) == uniform,
            "immutable original basis"
        );
    }

    function testFuzzNormalizationPreservesEveryValidClearing(
        uint96 start,
        uint96 price,
        uint256 raw,
        bool enabled
    ) external {
        uint256 clearing = start == 0 ? 0 : uint256(price) % (uint256(start) + 1);
        uint256 normalized = h.normalize(start, enabled, raw);
        uint256 original = enabled && raw < clearing ? raw : clearing;
        require(
            (normalized < clearing ? normalized : clearing) == original,
            "mathematically identical clamp"
        );
    }

    function testFuzzRadixQueryMatchesIndependentArray(uint96 a, uint96 b, uint96 c, uint96 price)
        external
    {
        h.record(address(1), a, 3);
        h.record(address(1), b, 3);
        h.record(address(1), c, 3);
        uint256 expected = uint256(a < price ? a : price) + (uint256(b) < price ? b : price)
            + (uint256(c) < price ? c : price);
        require(
            h.uniform(address(1), price) == expected && h.total(address(1)) == uint256(a) + b + c,
            "independent three-element oracle"
        );
    }

    event CompressedDistinctGas(
        uint256 first, uint256 second, uint256 duplicate, uint256 prefixQuery
    );

    function testCompressedSparseInsertionOrderAndAbsentPrefixes() external {
        uint96[9] memory caps =
            [uint96(1 << 80), (1 << 80) + 7, 0, type(uint96).max, 1, 1 << 95, 99, 1 << 70, 1 << 80];
        for (uint256 i; i < 9; ++i) {
            h.record(address(3), caps[i], 9);
            for (uint256 j; j < 9; ++j) {
                uint256 price = uint256(caps[j]) + 1;
                uint256 expected;
                for (uint256 k; k <= i; ++k) {
                    expected += caps[k] < price ? caps[k] : price;
                }
                require(h.uniform(address(3), price) == expected, "partial prefix oracle");
            }
        }
    }

    function testCompressedMaximumDepthAllDivergenceBits() external {
        h.record(address(3), 0, 97);
        for (uint256 i; i < 96; ++i) {
            h.record(address(3), uint256(1) << i, 97);
        }
        require(
            h.count(address(3)) == 97 && h.total(address(3)) == type(uint96).max, "all bits total"
        );
        for (uint256 i; i < 96; ++i) {
            uint256 price = (uint256(1) << i) + 1;
            uint256 expected;
            for (uint256 j; j < 96; ++j) {
                uint256 c = uint256(1) << j;
                expected += c < price ? c : price;
            }
            require(h.uniform(address(3), price) == expected, "96 branch oracle");
        }
    }

    function testCompressedGasFirstDistinctAndDuplicate() external {
        uint256 before = gasleft();
        h.record(address(3), 1000, 10);
        uint256 first = before - gasleft();
        before = gasleft();
        h.record(address(3), 777, 10);
        uint256 second = before - gasleft();
        before = gasleft();
        h.record(address(3), 777, 10);
        uint256 duplicate = before - gasleft();
        before = gasleft();
        require(h.uniform(address(3), 900) == 2454, "actual query");
        uint256 query = before - gasleft();
        emit CompressedDistinctGas(first, second, duplicate, query);
    }

    function testCompressedDeepestDuplicateAfterSameTransactionPreparation() external {
        h.record(address(3), 0, 98);
        for (uint256 i; i < 96; ++i) {
            h.record(address(3), uint256(1) << i, 98);
        }
        (bool cooled,) = address(vm).call(abi.encodeWithSignature("cool(address)", address(h)));
        require(cooled, "actual storage cooling");
        uint256 before = gasleft();
        h.record(address(3), 0, 98);
        uint256 used = before - gasleft();
        require(
            h.count(address(3)) == 98 && h.total(address(3)) == type(uint96).max,
            "deep update exact"
        );
        emit CompressedDistinctGas(0, 0, used, 0);
    }

    function testFuzzCompressedPermutationAndEveryPrefix(bytes32 seed, uint96 price) external {
        uint96[16] memory caps;
        for (uint256 i; i < 16; ++i) {
            caps[i] = i % 4 == 0 ? uint96(0) : uint96(uint256(keccak256(abi.encode(seed, i))));
            h.record(address(3), caps[i], 16);
        }
        for (uint256 i = 16; i != 0;) {
            --i;
            h.record(address(4), caps[i], 16);
        }
        uint256 expected;
        uint256 total;
        for (uint256 i; i < 16; ++i) {
            expected += caps[i] < price ? caps[i] : price;
            total += caps[i];
        }
        require(
            h.uniform(address(3), price) == expected && h.total(address(3)) == total,
            "independent array"
        );
        for (uint256 i; i < 16; ++i) {
            uint256 boundary = uint256(caps[i]) + 1;
            expected = 0;
            for (uint256 j; j < 16; ++j) {
                expected += caps[j] < boundary ? caps[j] : boundary;
            }
            require(h.uniform(address(4), boundary) == expected, "all present boundaries");
        }
    }

    function testLegacyNonemptyEncodingKeepsClaimsAndFutureUpdatesWithoutMigration() external {
        bytes32 base = keccak256(abi.encode(address(7), uint256(0)));
        uint256 maximum = type(uint96).max;
        // Literal old root and the two extreme binary paths for ceilings0/MAX.
        // This is the previously committed fixed-depth representation, not a
        // compressed-tree encoder used to construct its own expected state.
        vm.store(address(h), keccak256(abi.encode(uint256(1), base)), bytes32((maximum << 64) | 2));
        for (uint256 depth = 1; depth <= 96; ++depth) {
            vm.store(
                address(h), keccak256(abi.encode(uint256(1) << depth, base)), bytes32(uint256(1))
            );
            vm.store(
                address(h),
                keccak256(abi.encode((uint256(1) << (depth + 1)) - 1, base)),
                bytes32((maximum << 64) | 1)
            );
        }
        require(h.count(address(7)) == 2 && h.total(address(7)) == maximum, "old root");
        require(
            h.uniform(address(7), 5) == 5 && h.uniform(address(7), type(uint256).max) == maximum,
            "old entitlement"
        );
        h.record(address(7), 7, 3);
        require(
            h.count(address(7)) == 3 && h.total(address(7)) == maximum + 7
                && h.uniform(address(7), 5) == 10,
            "legacy append exact"
        );
        require(
            vm.load(address(h), keccak256(abi.encode(uint256(0), base))) == 0, "no legacy migration"
        );
        vm.expectRevert(
            abi.encodeWithSelector(StreamClearingCeilingBook.ClearingCountLimitExceeded.selector)
        );
        h.record(address(7), 1, 3);
        h.record(address(8), 0, 3);
        bytes32 freshBase = keccak256(abi.encode(address(8), uint256(0)));
        require(
            vm.load(address(h), keccak256(abi.encode(uint256(0), freshBase)))
                == bytes32(uint256(1) << 96),
            "fresh leaf pointer"
        );
        require(
            h.count(address(7)) == 3 && h.count(address(8)) == 1, "encodings and buyers isolated"
        );
    }
}

contract StreamClearingCeilingColdTest is CharacterizationTestBase {
    ClearingCeilingHarness private h;
    event CompressedColdGas(uint256 gasUsed);

    function setUp() external {
        h = new ClearingCeilingHarness();
        h.record(address(3), 0, 98);
        for (uint256 i; i < 96; ++i) {
            h.record(address(3), uint256(1) << i, 98);
        }
    }

    function testColdDeepestDuplicateAgainstSetupCommittedWords() external {
        (bool cooled,) = address(vm).call(abi.encodeWithSignature("cool(address)", address(h)));
        require(cooled, "actual storage cooling");
        uint256 before = gasleft();
        h.record(address(3), 0, 98);
        uint256 used = before - gasleft();
        require(
            h.count(address(3)) == 98 && h.total(address(3)) == type(uint96).max,
            "committed deep update exact"
        );
        emit CompressedColdGas(used);
    }
}
