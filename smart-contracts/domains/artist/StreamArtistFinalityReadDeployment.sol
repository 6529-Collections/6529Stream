// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistRegistryFinalityReadExtension.sol";

/// @notice Fixed linked construction for an explicitly bound future facade.
library StreamArtistFinalityReadDeployment {
    function deployReader(address host, address coordinator) public returns (address) {
        return address(new StreamArtistRegistryFinalityReadExtension(host, coordinator));
    }
}
