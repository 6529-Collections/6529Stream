// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamEntropyPolicyContinuity as C
} from "../../interfaces/stream/entropy/IStreamEntropyPolicyContinuity.sol";

/// @notice Compact ABI encoding of host-owned, canonical memory records.
/// @dev Internal only: direct host getters remain call-free. Nested memory pointers are flattened
/// into the unchanged external tuples. These helpers never decode untrusted calldata or storage.
library StreamEntropyDirectReadEncoding {
    function policy(C.PolicyExport memory p) internal pure returns (bytes memory encoded) {
        encoded = new bytes(1184);
        assembly ("memory-safe") {
            function copyWords(dst, src, size) {
                for { let end := add(src, size) } lt(src, end) {
                    src := add(src, 32)
                    dst := add(dst, 32)
                } {
                    mstore(dst, mload(src))
                }
            }
            let out := add(encoded, 32)
            copyWords(out, p, 128)
            copyWords(add(out, 128), mload(add(p, 128)), 384)
            let input := mload(add(p, 160))
            copyWords(add(out, 512), input, 224)
            copyWords(add(out, 736), mload(add(input, 224)), 160)
            copyWords(add(out, 896), add(input, 256), 64)
            copyWords(add(out, 960), add(p, 192), 64)
            copyWords(add(out, 1024), mload(add(p, 256)), 160)
        }
    }

    function recovery(C.RecoveryExport memory r) internal pure returns (bytes memory encoded) {
        uint256 count = r.policy.steps.length;
        encoded = new bytes(576 + count * 160);
        assembly ("memory-safe") {
            function copyWords(dst, src, size) {
                for { let end := add(src, size) } lt(src, end) {
                    src := add(src, 32)
                    dst := add(dst, 32)
                } {
                    mstore(dst, mload(src))
                }
            }
            let out := add(encoded, 32)
            mstore(out, 32)
            let tuple := add(out, 32)
            mstore(tuple, mload(r))
            mstore(add(tuple, 32), 288)
            copyWords(add(tuple, 64), add(r, 64), 224)
            let definition := mload(add(r, 32))
            let body := add(tuple, 288)
            copyWords(body, definition, 192)
            mstore(add(body, 192), 224)
            let steps := mload(add(definition, 192))
            let array := add(body, 224)
            mstore(array, count)
            for { let i := 0 } lt(i, count) { i := add(i, 1) } {
                copyWords(
                    add(add(array, 32), mul(i, 160)),
                    mload(add(add(steps, 32), mul(i, 32))),
                    160
                )
            }
        }
    }
}
