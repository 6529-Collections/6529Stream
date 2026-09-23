// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistExtensionFactory } from "./StreamArtistExtensionFactory.sol";

/// @notice Compiler-linked expected runtime hash for the fixed Artist extension factory.
library StreamArtistExtensionFactoryRuntime {
    function expected() public pure returns (bytes32) {
        return keccak256(type(StreamArtistExtensionFactory).runtimeCode);
    }
}
