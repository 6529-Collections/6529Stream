// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @dev Constructor-only slicing of compiler-generated, linked creation code.
library StreamArtistCreationParts {
    uint256 internal constant SPLIT = 16_384;
    error InvalidCreationPart();

    function part(bytes memory creation, uint8 index) internal pure returns (bytes memory result) {
        if (index > 1 || creation.length <= SPLIT || creation.length > 2 * SPLIT) {
            revert InvalidCreationPart();
        }
        uint256 start = index == 0 ? 0 : SPLIT;
        uint256 length = index == 0 ? SPLIT : creation.length - SPLIT;
        // STOP prevents the retained code bytes from being executed, including an EF prefix.
        result = new bytes(length + 1);
        assembly ("memory-safe") {
            let src := add(add(creation, 32), start)
            let dst := add(result, 33)
            let cursor := 0
            for { } lt(add(cursor, 31), length) { cursor := add(cursor, 32) } {
                mstore(add(dst, cursor), mload(add(src, cursor)))
            }
            for { } lt(cursor, length) { cursor := add(cursor, 1) } {
                mstore8(add(dst, cursor), byte(0, mload(add(src, cursor))))
            }
        }
    }
}
