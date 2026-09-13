// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Bounded auxiliary index for locating an unused uint256 artist nonce.
/// @dev Replay cells remain authoritative. Level zero stores individual nonce bits;
///      each higher bit means its entire 256-way child is full. There are exactly
///      32 levels, so no operation scans a caller-created run of prior submissions.
library StreamArtistNonceAvailability {
    struct Index {
        mapping(uint8 => mapping(uint256 => uint256)) full;
        bool exhausted;
    }

    error NonceAvailabilityAlreadyUsed(uint256 nonce);
    error NonceAvailabilityInconsistent(uint8 level, uint256 prefix);

    /// @notice Marks the same nonce consumed by the owner's replay cell and commits every changed word.
    /// @dev Future revocation must use this same hook atomically with its replay mutation.
    function consume(Index storage index, uint256 nonce) internal returns (bytes32 delta) {
        uint256 prefix = nonce >> 8;
        uint256 bit = nonce & 255;
        delta = keccak256(
            abi.encode(keccak256("6529STREAM_ARTIST_NONCE_AVAILABILITY_INDEX_V1"), nonce)
        );
        for (uint8 level; level < 32; ++level) {
            uint256 oldWord = index.full[level][prefix];
            uint256 mask = uint256(1) << bit;
            if ((oldWord & mask) != 0) revert NonceAvailabilityAlreadyUsed(nonce);
            uint256 nextWord = oldWord | mask;
            index.full[level][prefix] = nextWord;
            delta = keccak256(abi.encode(delta, level, prefix, oldWord, nextWord));
            if (nextWord != type(uint256).max) return delta;
            if (level == 31) {
                index.exhausted = true;
                return keccak256(abi.encode(delta, true));
            }
            bit = prefix & 255;
            prefix >>= 8;
        }
    }

    /// @notice Returns the lowest unused value, or no value if all 2**256 values were consumed.
    /// @dev Depth is fixed independently of the number or order of earlier authorizations.
    function firstUnused(Index storage index)
        internal
        view
        returns (bool available, uint256 nonce)
    {
        if (index.exhausted) return (false, 0);
        uint256 prefix;
        for (uint8 remaining = 32; remaining != 0;) {
            --remaining;
            uint256 word = index.full[remaining][prefix];
            if (word == type(uint256).max) revert NonceAvailabilityInconsistent(remaining, prefix);
            prefix = (prefix << 8) | _firstZeroBit(word);
        }
        return (true, prefix);
    }

    function _firstZeroBit(uint256 word) private pure returns (uint256 bit) {
        // Callers reject all-ones, so the complement has at least one set bit.
        // Binary search uses shifts <=128 and never a shift by the uint256 width.
        uint256 free = ~word;
        if ((free & type(uint128).max) == 0) {
            free >>= 128;
            bit += 128;
        }
        if ((free & type(uint64).max) == 0) {
            free >>= 64;
            bit += 64;
        }
        if ((free & type(uint32).max) == 0) {
            free >>= 32;
            bit += 32;
        }
        if ((free & type(uint16).max) == 0) {
            free >>= 16;
            bit += 16;
        }
        if ((free & type(uint8).max) == 0) {
            free >>= 8;
            bit += 8;
        }
        if ((free & 15) == 0) {
            free >>= 4;
            bit += 4;
        }
        if ((free & 3) == 0) {
            free >>= 2;
            bit += 2;
        }
        if ((free & 1) == 0) ++bit;
    }
}
