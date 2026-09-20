// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { Base64 } from "../../vendor/openzeppelin/Base64.sol";

/// @notice Exact terminal-profile JSON fields; the V1 matcher remains unchanged.
library StreamPolicyContentBytesV2 {
    function matches(bytes memory json, bytes memory html, bytes memory tokenData)
        internal
        pure
        returns (bool)
    {
        bytes memory suffix = abi.encodePacked(
            ',"animation_url":"data:text/html;base64,', Base64.encode(html), '"}'
        );
        if (suffix.length > json.length) return false;
        bytes32 tail;
        assembly ("memory-safe") {
            tail := keccak256(add(add(json, 32), sub(mload(json), mload(suffix))), mload(suffix))
        }
        return tail == keccak256(suffix)
            && _field(
            json,
            abi.encodePacked(
            ',"token_data_base64":"', Base64.encode(tokenData), '","properties":{"stream":'
        )
        );
    }

    function _field(bytes memory json, bytes memory field) private pure returns (bool found) {
        if (field.length > json.length) return false;
        // Both fixed field encodings above exceed one word. Candidate bytes and the full
        // hashed span therefore remain in-bounds, including the final allowed position.
        bytes32 expected = keccak256(field);
        assembly ("memory-safe") {
            function at(p) -> b { b := byte(and(p, 31), mload(and(p, not(31)))) }
            let start := add(json, 32)
            let limit := add(start, sub(mload(json), mload(field)))
            let first := mload(add(field, 32))
            for { let p := start } iszero(gt(p, limit)) { p := add(p, 1) } {
                // Most of the large field is Base64. A word without ',' cannot begin a
                // match. Retain byte-position comparisons whenever a comma is possible.
                if iszero(lt(sub(limit, p), 31)) {
                    let x :=
                        xor(
                            mload(p),
                            0x2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c
                        )
                    if iszero(
                        and(
                            and(
                                sub(
                                    x,
                                    0x0101010101010101010101010101010101010101010101010101010101010101
                                ),
                                not(x)
                            ),
                            0x8080808080808080808080808080808080808080808080808080808080808080
                        )
                    ) {
                        p := add(p, 31)
                        continue
                    }
                }
                if and(eq(at(p), 44), eq(at(add(p, 1)), 34)) {
                    if eq(mload(p), first) {
                        if eq(keccak256(p, mload(field)), expected) {
                            found := 1
                            break
                        }
                    }
                }
            }
        }
    }
}
