// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Fixed-depth aggregate for exact uniform-price entitlements with heterogeneous ceilings.
/// @dev Caller owns authenticated purchase/replay/sale bounds. No external calls or financial transfers.
library StreamClearingCeilingBook {
    struct Tree {
        mapping(uint256 => uint256) nodes;
    }
    error ClearingCeilingOutOfBounds();
    error ClearingCountLimitExceeded();
    error ClearingAggregateOutOfBounds();

    /// @dev A node packs count64 in low bits and sum192 above it. Count<=2^64-1 and
    ///      each normalized price<=2^96-1 imply sum<2^160; arithmetic stays uint256.
    function record(Tree storage self, uint256 normalizedCeiling, uint64 maximumCount) internal {
        if (normalizedCeiling > type(uint96).max) revert ClearingCeilingOutOfBounds();
        if (maximumCount == 0 || count(self) >= maximumCount) revert ClearingCountLimitExceeded();
        uint256 key = (uint256(1) << 96) + normalizedCeiling;
        for (uint256 depth; depth <= 96; ++depth) {
            uint256 word = self.nodes[key];
            uint256 nextCount = (word & type(uint64).max) + 1;
            uint256 nextSum = (word >> 64) + normalizedCeiling;
            if (nextCount > type(uint64).max || nextSum > type(uint192).max) {
                revert ClearingAggregateOutOfBounds();
            }
            self.nodes[key] = (nextSum << 64) | nextCount;
            key >>= 1;
        }
    }

    function count(Tree storage self) internal view returns (uint256) {
        return self.nodes[1] & type(uint64).max;
    }

    function ceilingSum(Tree storage self) internal view returns (uint256) {
        return self.nodes[1] >> 64;
    }

    /// @notice Returns sum(min(clearingPrice,ceiling)) in at most96 child-node reads.
    function uniformSum(Tree storage self, uint256 clearingPrice) internal view returns (uint256) {
        uint256 root = self.nodes[1];
        uint256 totalCount = root & type(uint64).max;
        if (clearingPrice >= type(uint96).max) return root >> 64;
        if (clearingPrice == 0 || totalCount == 0) return 0;
        uint256 belowCount;
        uint256 belowSum;
        uint256 key = 1;
        for (uint256 remaining = 96; remaining != 0;) {
            --remaining;
            uint256 left = key << 1;
            if ((clearingPrice & (uint256(1) << remaining)) != 0) {
                uint256 word = self.nodes[left];
                belowCount += word & type(uint64).max;
                belowSum += word >> 64;
                key = left | 1;
            } else {
                key = left;
            }
        }
        return belowSum + clearingPrice * (totalCount - belowCount);
    }

    /// @dev Preserves min(clearing,raw) for every clearing<=start. Original signed raw stays elsewhere.
    function normalize(uint256 startPrice, bool hasOverride, uint256 rawOverride)
        internal
        pure
        returns (uint256)
    {
        if (startPrice > type(uint96).max) revert ClearingCeilingOutOfBounds();
        return hasOverride && rawOverride < startPrice ? rawOverride : startPrice;
    }
}
