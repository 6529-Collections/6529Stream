// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";

/// @notice Projects checked owner4 dispute binding rows after dispute installation.
library StreamArtistRecoveredMultipleDisputeAttributionBindings {
    function bindingHashes(bytes calldata raw) public pure returns (bytes32[][] memory hashes) {
        G.Inventory memory inventory = abi.decode(raw, (G.Inventory));
        hashes = new bytes32[][](inventory.bindings.length);
        for (uint256 k; k < hashes.length; ++k) {
            hashes[k] = new bytes32[](inventory.bindings[k].bindings.rows.length);
            for (uint256 g; g < hashes[k].length; ++g) {
                hashes[k][g] = inventory.bindings[k].bindings.rows[g].item.bindingHash;
            }
        }
    }
}
