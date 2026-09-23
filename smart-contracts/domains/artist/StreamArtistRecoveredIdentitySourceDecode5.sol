// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentitySourceDecode5A as First
} from "./StreamArtistRecoveredIdentitySourceDecode5A.sol";
import {
    StreamArtistRecoveredIdentitySourceDecode5B as Second
} from "./StreamArtistRecoveredIdentitySourceDecode5B.sol";

/// @notice Exact five-array tuple for Bundle fields 24 through 28, decoded in declaration order.
/// @dev The two fixed parts each return a canonical tuple. Relocate only their outer offsets.
library StreamArtistRecoveredIdentitySourceDecode5 {
    function decode(bytes calldata raw, bool withSchema) public pure returns (bytes memory out) {
        bytes memory first = First.decode(raw, withSchema);
        bytes memory second = Second.decode(raw, withSchema);
        out = new bytes(first.length + second.length);
        // Two heads grow from 64 to 160 bytes; three heads also skip the first part's tail.
        for (uint256 i; i < 2; ++i) {
            uint256 value;
            assembly ("memory-safe") { value := mload(add(add(first, 32), mul(i, 32))) }
            value += 96;
            assembly ("memory-safe") { mstore(add(add(out, 32), mul(i, 32)), value) }
        }
        for (uint256 i; i < 3; ++i) {
            uint256 value;
            assembly ("memory-safe") { value := mload(add(add(second, 32), mul(i, 32))) }
            value += first.length;
            assembly ("memory-safe") { mstore(add(add(out, 96), mul(i, 32)), value) }
        }
        uint256 cursor = 160;
        for (uint256 at = 64; at < first.length; at += 32) {
            assembly ("memory-safe") { mstore(
                add(add(out, 32), cursor),
                mload(add(add(first, 32), at))
            ) }
            cursor += 32;
        }
        for (uint256 at = 96; at < second.length; at += 32) {
            assembly ("memory-safe") { mstore(
                add(add(out, 32), cursor),
                mload(add(add(second, 32), at))
            ) }
            cursor += 32;
        }
    }
}
