// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice ABI tuple framing for complete single-dynamic-argument encodings from fixed stages.
/// @dev No target, selector, or call is accepted here. Each caller fixes the exact typed method.
/// Nested offsets stay relative to their own tuple/array heads; only the outer heads change.
library StreamArtistRecoveredIdentitySourceTuple {
    function two(bytes memory a, bytes memory b) internal pure returns (bytes memory) {
        bytes memory aa = body(a);
        bytes memory bb = body(b);
        return bytes.concat(abi.encode(uint256(64), 64 + aa.length), aa, bb);
    }

    function wordAndOne(address word, bytes memory a) internal pure returns (bytes memory) {
        return bytes.concat(abi.encode(word, uint256(64)), body(a));
    }

    function wordAndTwo(address word, bytes memory a, bytes memory b)
        internal
        pure
        returns (bytes memory)
    {
        bytes memory aa = body(a);
        return bytes.concat(abi.encode(word, uint256(96), 96 + aa.length), aa, body(b));
    }

    function body(bytes memory single) internal pure returns (bytes memory result) {
        requireSingle(single);
        result = new bytes(single.length - 32);
        // Both byte arrays are word-aligned ABI encodings. The last copied word is wholly
        // inside the allocated source and destination; no nested offsets are rewritten.
        for (uint256 i; i < result.length; i += 32) {
            assembly ("memory-safe") {
                mstore(add(add(result, 0x20), i), mload(add(add(single, 0x40), i)))
            }
        }
    }

    function requireSingle(bytes memory single) internal pure {
        uint256 offset;
        assembly ("memory-safe") { offset := mload(add(single, 0x20)) }
        if (single.length < 64 || single.length % 32 != 0 || offset != 32) {
            assembly ("memory-safe") { revert(0, 0) }
        }
    }

    function result(bool ok, bytes memory raw) internal pure returns (bytes memory) {
        if (!ok) {
            assembly ("memory-safe") { revert(add(raw, 0x20), mload(raw)) }
        }
        return raw;
    }
}
