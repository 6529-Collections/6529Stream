// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistPrimaryCollaboratorClocks as Clocks
} from "./StreamArtistPrimaryCollaboratorClocks.sol";

/// @notice Exact typed clocks projection of the fixed SourceCollection's complete encoding.
/// @dev Caller first authenticates the full observed Proof. The full Source.Result is produced
/// by that fixed worker; this helper is a projection, not independent source admission.
library StreamArtistPrimaryCollaboratorSourceResultClocks {
    function decode(bytes calldata raw) public pure returns (Clocks.Result memory clocks) {
        if (raw.length < 96 || raw.length % 32 != 0) assembly ("memory-safe") { revert(0, 0) }
        uint256 at;
        assembly ("memory-safe") { at := calldataload(raw.offset) }
        if (at != 32) assembly ("memory-safe") { revert(0, 0) }
        clocks = abi.decode(raw[32:], (Clocks.Result));
    }
}
