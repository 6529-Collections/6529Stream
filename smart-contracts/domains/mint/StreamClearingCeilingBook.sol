// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Compressed binary radix aggregate for exact uniform-price entitlements.
/// @dev Caller owns authenticated purchase/replay/sale bounds. No external calls or value transfers.
/// Existing nonempty fixed-depth trees retain their original encoding; new trees use a root pointer.
library StreamClearingCeilingBook {
    struct Tree {
        mapping(uint256 => uint256) nodes;
    }
    uint256 private constant LEAF = uint256(1) << 96;
    uint256 private constant POINTER_MASK = (uint256(1) << 97) - 1;
    error ClearingCeilingOutOfBounds();
    error ClearingCountLimitExceeded();
    error ClearingAggregateOutOfBounds();

    // nodes[0] is the root key. Keys are the binary heap prefix, including its
    // leading 1; depth-96 keys are leaves. Aggregate lives at key*2 and branch
    // header at key*2+1. Header packs left97/right97/branchBit7.
    function record(Tree storage self, uint256 ceiling, uint64 maximumCount) internal {
        if (ceiling > type(uint96).max) revert ClearingCeilingOutOfBounds();
        uint256 root = self.nodes[0];
        if (root == 0 && self.nodes[1] != 0) {
            _legacyRecord(self, ceiling, maximumCount);
            return;
        }
        if (maximumCount == 0 || count(self) >= maximumCount) revert ClearingCountLimitExceeded();
        uint256 leaf = LEAF | ceiling;
        if (root == 0) {
            self.nodes[leaf << 1] = _add(0, ceiling);
            self.nodes[0] = leaf;
            return;
        }
        uint256[97] memory path;
        uint256 length;
        uint256 key = root;
        while (true) {
            path[length++] = key;
            if (key >= LEAF) break;
            uint256 header = self.nodes[(key << 1) | 1];
            uint256 bit = header >> 194;
            key = (ceiling & (uint256(1) << bit)) == 0
                ? header & POINTER_MASK
                : (header >> 97) & POINTER_MASK;
        }
        if (key == leaf) {
            for (uint256 i; i < length; ++i) {
                uint256 slot = path[i] << 1;
                self.nodes[slot] = _add(self.nodes[slot], ceiling);
            }
            return;
        }
        uint256 differentBit = _msb((key ^ leaf));
        uint256 insertion;
        while (path[insertion] < LEAF) {
            if (self.nodes[(path[insertion] << 1) | 1] >> 194 <= differentBit) break;
            ++insertion;
        }
        uint256 subtree = path[insertion];
        uint256 branch = _newBranch(self, subtree, ceiling, differentBit);
        if (insertion == 0) {
            self.nodes[0] = branch;
        } else {
            _replaceChild(self, path[insertion - 1], subtree, branch);
        }
        for (uint256 i; i < insertion; ++i) {
            uint256 slot = path[i] << 1;
            self.nodes[slot] = _add(self.nodes[slot], ceiling);
        }
    }

    function _newBranch(Tree storage self, uint256 subtree, uint256 ceiling, uint256 bit)
        private
        returns (uint256 branch)
    {
        uint256 leaf = LEAF | ceiling;
        branch = (uint256(1) << (95 - bit)) | (ceiling >> (bit + 1));
        uint256 left = (ceiling & (uint256(1) << bit)) == 0 ? leaf : subtree;
        uint256 right = left == leaf ? subtree : leaf;
        self.nodes[leaf << 1] = _add(0, ceiling);
        self.nodes[branch << 1] = _add(self.nodes[subtree << 1], ceiling);
        self.nodes[(branch << 1) | 1] = left | (right << 97) | (bit << 194);
    }

    function _replaceChild(Tree storage self, uint256 parentKey, uint256 subtree, uint256 branch)
        private
    {
        uint256 slot = (parentKey << 1) | 1;
        uint256 parent = self.nodes[slot];
        self.nodes[slot] = (parent & POINTER_MASK) == subtree
            ? (parent & ~POINTER_MASK) | branch
            : (parent & ~(POINTER_MASK << 97)) | (branch << 97);
    }

    function count(Tree storage self) internal view returns (uint256) {
        uint256 root = self.nodes[0];
        return self.nodes[root == 0 ? 1 : root << 1] & type(uint64).max;
    }

    function ceilingSum(Tree storage self) internal view returns (uint256) {
        uint256 root = self.nodes[0];
        return self.nodes[root == 0 ? 1 : root << 1] >> 64;
    }

    function uniformSum(Tree storage self, uint256 price) internal view returns (uint256) {
        uint256 key = self.nodes[0];
        if (key == 0) return _legacyUniformSum(self, price);
        if (price == 0) return 0;
        uint256 root = self.nodes[key << 1];
        if (price >= type(uint96).max) return root >> 64;
        uint256 belowCount;
        uint256 belowSum;
        while (key != 0) {
            if (key >= LEAF) {
                if ((key & (LEAF - 1)) < price) {
                    uint256 word = self.nodes[key << 1];
                    belowCount += word & type(uint64).max;
                    belowSum += word >> 64;
                }
                break;
            }
            uint256 header = self.nodes[(key << 1) | 1];
            uint256 bit = header >> 194;
            uint256 minimum = (key ^ (uint256(1) << (95 - bit))) << (bit + 1);
            if (price <= minimum) break;
            if (price > (minimum | ((uint256(1) << (bit + 1)) - 1))) {
                uint256 word = self.nodes[key << 1];
                belowCount += word & type(uint64).max;
                belowSum += word >> 64;
                break;
            }
            uint256 left = header & POINTER_MASK;
            if ((price & (uint256(1) << bit)) != 0) {
                uint256 word = self.nodes[left << 1];
                belowCount += word & type(uint64).max;
                belowSum += word >> 64;
                key = (header >> 97) & POINTER_MASK;
            } else {
                key = left;
            }
        }
        return belowSum + price * ((root & type(uint64).max) - belowCount);
    }

    function normalize(uint256 start, bool enabled, uint256 raw) internal pure returns (uint256) {
        if (start > type(uint96).max) revert ClearingCeilingOutOfBounds();
        return enabled && raw < start ? raw : start;
    }

    function _add(uint256 word, uint256 ceiling) private pure returns (uint256) {
        uint256 nextCount = (word & type(uint64).max) + 1;
        uint256 nextSum = (word >> 64) + ceiling;
        if (nextCount > type(uint64).max || nextSum > type(uint192).max) {
            revert ClearingAggregateOutOfBounds();
        }
        return (nextSum << 64) | nextCount;
    }

    function _msb(uint256 x) private pure returns (uint256 r) {
        if (x >> 64 != 0) {
            x >>= 64;
            r += 64;
        }
        if (x >> 32 != 0) {
            x >>= 32;
            r += 32;
        }
        if (x >> 16 != 0) {
            x >>= 16;
            r += 16;
        }
        if (x >> 8 != 0) {
            x >>= 8;
            r += 8;
        }
        if (x >> 4 != 0) {
            x >>= 4;
            r += 4;
        }
        if (x >> 2 != 0) {
            x >>= 2;
            r += 2;
        }
        if (x >> 1 != 0) r += 1;
    }

    // The old fixed-depth algorithm never wrote nodes[0], and its nonempty root
    // aggregate always has nonzero nodes[1]. Compressed aggregate/header keys
    // start at2, so the encodings are unambiguous. Existing trees remain legacy;
    // there is no migration, enumeration or loss of prior buyer entitlements.
    function _legacyRecord(Tree storage self, uint256 normalizedCeiling, uint64 maximumCount)
        internal
    {
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

    function _legacyUniformSum(Tree storage self, uint256 clearingPrice)
        internal
        view
        returns (uint256)
    {
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
}
