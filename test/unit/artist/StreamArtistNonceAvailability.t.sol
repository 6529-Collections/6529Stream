// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/artist/StreamArtistNonceAvailability.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";

contract ArtistNonceAvailabilityHarness {
    using StreamArtistNonceAvailability for StreamArtistNonceAvailability.Index;
    StreamArtistNonceAvailability.Index private index;

    function consume(uint256 nonce) external returns (bytes32) {
        return index.consume(nonce);
    }

    function firstUnused() external view returns (bool, uint256) {
        return index.firstUnused();
    }

    function cell(uint8 level, uint256 prefix) external view returns (uint256) {
        return index.full[level][prefix];
    }

    function consumeRange(uint256 start, uint256 count) external {
        for (uint256 i; i < count; ++i) {
            index.consume(start + i);
        }
    }

    /// @dev Algorithm fixture representing 255 earlier consumed values per leaf.
    ///      The final actual consume must propagate fullness into the parent.
    function seedAndCompleteLeaves(uint256 start, uint256 count) external {
        for (uint256 prefix = start; prefix < start + count; ++prefix) {
            require(index.full[0][prefix] == 0, "empty fixture leaf");
            index.full[0][prefix] = type(uint256).max >> 1;
            index.consume((prefix << 8) | 255);
        }
    }
}

contract StreamArtistNonceAvailabilityTest is CharacterizationTestBase {
    ArtistNonceAvailabilityHarness private harness;

    function setUp() public {
        harness = new ArtistNonceAvailabilityHarness();
    }

    function _hint(uint256 expected) private view {
        (bool available, uint256 nonce) = harness.firstUnused();
        require(available && nonce == expected, "lowest unused nonce");
    }

    function testSparseMaximumAndHighPrefixDoNotCollide() public {
        bytes32 first = harness.consume(type(uint256).max);
        bytes32 second = harness.consume(uint256(1) << 255);
        require(first != second, "distinct index transitions");
        _hint(0);
        harness.consume(0);
        _hint(1);
        require(
            harness.cell(0, type(uint256).max >> 8) == uint256(1) << 255, "maximum leaf encoding"
        );
        require(harness.cell(0, uint256(1) << 247) == 1, "high prefix encoding");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamArtistNonceAvailability.NonceAvailabilityAlreadyUsed.selector,
                type(uint256).max
            )
        );
        harness.consume(type(uint256).max);
    }

    function testLeafAndParentFullnessPropagation() public {
        harness.consumeRange(0, 256);
        _hint(256);
        require(
            harness.cell(0, 0) == type(uint256).max && harness.cell(1, 0) == 1,
            "full leaf parent marker"
        );
        harness.seedAndCompleteLeaves(1, 255);
        _hint(65536);
        require(
            harness.cell(1, 0) == type(uint256).max && harness.cell(2, 0) == 1,
            "full parent grandparent marker"
        );
    }

    function testLongFuturePrefixDoesNotCauseLinearHintWork() public {
        harness.consumeRange(1, 8192);
        _hint(0);
        uint256 before_ = gasleft();
        harness.consume(0);
        _hint(8193);
        uint256 used = before_ - gasleft();
        require(used < 200_000, "bounded final consumption and 32-level hint search");
    }

    function testFuzzSparseNonceRemainsDistinctFromZero(uint256 nonce) public {
        if (nonce == 0) nonce = type(uint256).max;
        harness.consume(nonce);
        _hint(0);
        harness.consume(0);
        _hint(nonce == 1 ? 2 : 1);
    }
}
