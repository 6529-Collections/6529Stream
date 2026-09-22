// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistPrimaryCollaboratorTypes as G
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

/// @notice Bounded view of the complete five-field Proof, only consumed after canonical decoding.
library StreamArtistPrimaryCollaboratorProofFrame {
    function body(bytes calldata raw) internal pure returns (bytes calldata) {
        if (raw.length < 32) assembly ("memory-safe") { revert(0, 0) }
        uint256 at;
        assembly ("memory-safe") { at := calldataload(raw.offset) }
        if (at > raw.length || raw.length - at < 160) assembly ("memory-safe") { revert(0, 0) }
        return raw[at:];
    }

    function bindingBody(bytes calldata raw) internal pure returns (bytes calldata) {
        bytes calldata parent = body(raw);
        uint256 at;
        assembly ("memory-safe") { at := calldataload(add(parent.offset, 32)) }
        if (at > parent.length || parent.length - at < 96) {
            assembly ("memory-safe") { revert(0, 0) }
        }
        return parent[at:];
    }

    function proof(bytes calldata raw) internal pure returns (G.Proof calldata p) {
        uint256 at;
        assembly ("memory-safe") { at := calldataload(raw.offset) }
        if (raw.length < 192 || raw.length % 32 != 0 || at != 32) {
            assembly ("memory-safe") { revert(0, 0) }
        }
        assembly ("memory-safe") { p := add(raw.offset, 32) }
    }
}
