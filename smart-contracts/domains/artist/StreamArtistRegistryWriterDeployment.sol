// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistRegistryWriterExtension.sol";

/// @notice Fixed linked construction for an explicitly bound future facade.
library StreamArtistRegistryWriterDeployment {
    function deployWriter(address host, address coordinator) public returns (address) {
        return address(new StreamArtistRegistryWriterExtension(host, coordinator));
    }
}
