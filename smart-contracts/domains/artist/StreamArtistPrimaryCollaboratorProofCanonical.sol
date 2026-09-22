// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistPrimaryCollaboratorProofPart0 as Part0
} from "./StreamArtistPrimaryCollaboratorProofPart0.sol";
import {
    StreamArtistPrimaryCollaboratorProofPart1 as Part1
} from "./StreamArtistPrimaryCollaboratorProofPart1.sol";
import {
    StreamArtistPrimaryCollaboratorProofPart2 as Part2
} from "./StreamArtistPrimaryCollaboratorProofPart2.sol";
import {
    StreamArtistPrimaryCollaboratorProofPart3 as Part3
} from "./StreamArtistPrimaryCollaboratorProofPart3.sol";
import {
    StreamArtistPrimaryCollaboratorProofPart4 as Part4
} from "./StreamArtistPrimaryCollaboratorProofPart4.sol";

/// @notice Complete original Proof decoding in declaration order; no field or nested tail is skipped.
library StreamArtistPrimaryCollaboratorProofCanonical {
    function canonical(bytes calldata raw) public pure returns (bytes memory result) {
        bytes[5] memory parts;
        parts[0] = Part0.decode(raw);
        parts[1] = Part1.decode(raw);
        parts[2] = Part2.decode(raw);
        parts[3] = Part3.decode(raw);
        parts[4] = Part4.decode(raw);
        uint256 length = 192;
        for (uint256 i; i < 5; ++i) {
            length += parts[i].length - 32;
        }
        result = new bytes(length);
        assembly ("memory-safe") { mstore(add(result, 32), 32) }
        uint256 tail = 192;
        for (uint256 i; i < 5; ++i) {
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
