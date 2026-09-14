// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistRegistryReadExtension.sol";

/// @notice Fixed linked construction for an explicitly bound future facade.
library StreamArtistRegistryExtensionDeployment {
    function deployReader(address host, address coordinator) public returns (address) {
        return address(new StreamArtistRegistryReadExtension(host, coordinator));
    }
}
