// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredIdentitySourceDecode0 as Part0
} from "./StreamArtistRecoveredIdentitySourceDecode0.sol";
import {
    StreamArtistRecoveredIdentitySourceDecode1 as Part1
} from "./StreamArtistRecoveredIdentitySourceDecode1.sol";
import {
    StreamArtistRecoveredIdentitySourceDecode2 as Part2
} from "./StreamArtistRecoveredIdentitySourceDecode2.sol";
import {
    StreamArtistRecoveredIdentitySourceDecode3 as Part3
} from "./StreamArtistRecoveredIdentitySourceDecode3.sol";
import {
    StreamArtistRecoveredIdentitySourceDecode4 as Part4
} from "./StreamArtistRecoveredIdentitySourceDecode4.sol";
import {
    StreamArtistRecoveredIdentitySourceDecode5 as Part5
} from "./StreamArtistRecoveredIdentitySourceDecode5.sol";
import {
    StreamArtistRecoveredIdentitySourceDecode6 as Part6
} from "./StreamArtistRecoveredIdentitySourceDecode6.sol";
import {
    StreamArtistRecoveredIdentitySourceDecode7 as Part7
} from "./StreamArtistRecoveredIdentitySourceDecode7.sol";

/// @notice Complete original typed decoding and canonical Bundle encoding in fixed field groups.
/// @dev Each part uses Solidity abi.decode with the original bounded byte slice. Only outer
/// tuple offsets are relocated; each nested tuple and array retains its compiler-generated ABI.
library StreamArtistRecoveredIdentitySourceCanonical {
    function canonical(bytes calldata raw, bool withSchema)
        public
        pure
        returns (bytes memory result)
    {
        bytes[] memory parts = new bytes[](8);
        parts[0] = Part0.decode(raw, withSchema);
        parts[1] = Part1.decode(raw, withSchema);
        parts[2] = Part2.decode(raw, withSchema);
        parts[3] = Part3.decode(raw, withSchema);
        parts[4] = Part4.decode(raw, withSchema);
        parts[5] = Part5.decode(raw, withSchema);
        parts[6] = Part6.decode(raw, withSchema);
        parts[7] = Part7.decode(raw, withSchema);
        uint256[8] memory heads = [
            uint256(1536),
            uint256(128),
            uint256(160),
            uint256(192),
            uint256(32),
            uint256(160),
            uint256(32),
            uint256(128)
        ];
        uint256[8] memory masks = [
            uint256(140737488355776),
            uint256(15),
            uint256(31),
            uint256(63),
            uint256(1),
            uint256(31),
            uint256(1),
            uint256(15)
        ];
        uint256 length = 32;
        for (uint256 i; i < parts.length; ++i) {
            length += parts[i].length;
        }
        result = new bytes(length);
        assembly ("memory-safe") { mstore(add(result, 32), 32) }
        uint256 headCursor = 32;
        uint256 tailCursor = 2400; // Single Bundle offset plus its 74-word ABI head.
        for (uint256 i; i < parts.length; ++i) {
            bytes memory part = parts[i];
            uint256 head = heads[i];
            for (uint256 word; word < head / 32; ++word) {
                uint256 value;
                assembly ("memory-safe") { value := mload(add(add(part, 32), mul(word, 32))) }
                if ((masks[i] & (uint256(1) << word)) != 0) {
                    value = tailCursor - 32 + value - head;
                }
                assembly ("memory-safe") { mstore(add(add(result, 32), headCursor), value) }
                headCursor += 32;
            }
            for (uint256 at = head; at < part.length; at += 32) {
                assembly ("memory-safe") {
                    mstore(add(add(result, 32), tailCursor), mload(add(add(part, 32), at)))
                }
                tailCursor += 32;
            }
        }
    }
}
