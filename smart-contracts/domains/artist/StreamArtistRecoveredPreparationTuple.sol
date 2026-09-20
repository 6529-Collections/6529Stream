// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

/// @notice ABI tuple framing for complete single-dynamic-argument encodings from fixed stages.
/// @dev No target, selector, or call is accepted here. Each caller fixes the exact typed method.
/// Nested offsets stay relative to their own tuple/array heads; only the outer heads change.
library StreamArtistRecoveredPreparationTuple {
    function two(bytes memory a, bytes memory b) internal pure returns (bytes memory) {
        bytes memory aa = body(a);
        bytes memory bb = body(b);
        return bytes.concat(abi.encode(uint256(64), 64 + aa.length), aa, bb);
    }

    function oneWithTwoWords(bytes memory a, uint256 b, uint256 c)
        internal
        pure
        returns (bytes memory)
    {
        return bytes.concat(abi.encode(uint256(96), b, c), body(a));
    }

    function four(bytes memory a, bytes memory b, bytes memory c, bytes memory d)
        internal
        pure
        returns (bytes memory)
    {
        bytes memory aa = body(a);
        bytes memory bb = body(b);
        bytes memory cc = body(c);
        bytes memory dd = body(d);
        uint256 ob = 128 + aa.length;
        uint256 oc = ob + bb.length;
        return bytes.concat(abi.encode(uint256(128), ob, oc, oc + cc.length), aa, bb, cc, dd);
    }

    function fourAndMode(bytes memory a, bytes memory b, bytes memory c, bytes memory d, uint8 mode)
        internal
        pure
        returns (bytes memory)
    {
        bytes memory aa = body(a);
        bytes memory bb = body(b);
        bytes memory cc = body(c);
        bytes memory dd = body(d);
        uint256 ob = 160 + aa.length;
        uint256 oc = ob + bb.length;
        return bytes.concat(abi.encode(uint256(160), ob, oc, oc + cc.length, mode), aa, bb, cc, dd);
    }

    function fourModeAndRows(
        bytes memory a,
        bytes memory b,
        bytes memory c,
        bytes memory d,
        uint8 mode,
        bytes memory rows
    ) internal pure returns (bytes memory) {
        bytes memory aa = body(a);
        bytes memory bb = body(b);
        bytes memory cc = body(c);
        bytes memory dd = body(d);
        bytes memory rr = body(rows);
        uint256 ob = 192 + aa.length;
        uint256 oc = ob + bb.length;
        uint256 od = oc + cc.length;
        return bytes.concat(
            abi.encode(uint256(192), ob, oc, od, mode, od + dd.length), aa, bb, cc, dd, rr
        );
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
            revert RH.InvalidRecoveredHydrationProfile();
        }
    }

    function result(bool ok, bytes memory raw) internal pure returns (bytes memory) {
        if (!ok) {
            assembly ("memory-safe") { revert(add(raw, 0x20), mload(raw)) }
        }
        return raw;
    }
}
