// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";

/// @notice Bounded single-Bundle ABI view used only with the complete canonical serializer.
/// @dev Bundle's original ABI head is 74 words (including static Snapshot and Heads tuples).
/// Every dynamic field is then traversed by Solidity's complete typed encoder, not skipped.
library StreamArtistRecoveredIdentitySourceFrame {
    /// @dev This is the same full Bundle head bound as the original ABI decoder. Dynamic
    /// offsets are checked by each typed group decoder against this slice's own end.
    function body(bytes calldata raw, bool withSchema) internal pure returns (bytes calldata) {
        uint256 word = withSchema ? 32 : 0;
        if (raw.length < word + 32) assembly ("memory-safe") { revert(0, 0) }
        uint256 offset;
        assembly ("memory-safe") { offset := calldataload(add(raw.offset, word)) }
        if (offset > raw.length || raw.length - offset < 2368) {
            assembly ("memory-safe") { revert(0, 0) }
        }
        return raw[offset:];
    }

    function bundle(bytes calldata raw) internal pure returns (IH.Bundle calldata b) {
        uint256 offset;
        assembly ("memory-safe") { offset := calldataload(raw.offset) }
        if (raw.length < 2400 || raw.length % 32 != 0 || offset != 32) {
            assembly ("memory-safe") { revert(0, 0) }
        }
        assembly ("memory-safe") { b := add(raw.offset, 32) }
    }
}
