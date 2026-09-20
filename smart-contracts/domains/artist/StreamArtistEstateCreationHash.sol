// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistIdentityEstateExtension } from "./StreamArtistIdentityEstateExtension.sol";

/// @dev Fixed linked canonical image hash, kept outside Factory initcode's EIP-3860 budget.
library StreamArtistEstateCreationHash {
    function expected() public pure returns (bytes32) {
        return keccak256(type(StreamArtistIdentityEstateExtension).creationCode);
    }
}
