// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistPrimaryCollaboratorProofBinding0 as Part0
} from "./StreamArtistPrimaryCollaboratorProofBinding0.sol";
import {
    StreamArtistPrimaryCollaboratorProofBinding1 as Part1
} from "./StreamArtistPrimaryCollaboratorProofBinding1.sol";
import {
    StreamArtistPrimaryCollaboratorProofBinding2 as Part2
} from "./StreamArtistPrimaryCollaboratorProofBinding2.sol";

/// @notice Complete original BindingInventory canonical bytes; all three nested fields decode first.
library StreamArtistPrimaryCollaboratorProofPart1 {
    function decode(bytes calldata raw) public pure returns (bytes memory result) {
        bytes[3] memory parts;
        parts[0] = Part0.decode(raw);
        parts[1] = Part1.decode(raw);
        parts[2] = Part2.decode(raw);
        uint256 length = 128;
        for (uint256 i; i < 3; ++i) {
            length += parts[i].length - 32;
        }
        result = new bytes(length);
        assembly ("memory-safe") { mstore(add(result, 32), 32) }
        uint256 tail = 128;
        for (uint256 i; i < 3; ++i) {
            bytes memory part = parts[i];
            assembly ("memory-safe") { mstore(add(add(result, 64), mul(i, 32)), sub(tail, 32)) }
            for (uint256 at = 32; at < part.length; at += 32) {
                assembly ("memory-safe") {
                    mstore(add(add(result, 32), tail), mload(add(add(part, 32), at)))
                }
                tail += 32;
            }
        }
    }
}
