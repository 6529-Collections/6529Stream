// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistRegistryReadExtension.sol";

/// @notice Compiler-linked constructor code; CREATE retains the calling Registry as creator.
/// @dev The immutable reader host is address(this) in delegatecall context, never caller-supplied.
library StreamArtistRegistryExtensionDeployment {
    function deployReader(address coordinator) public returns (address) {
        return address(new StreamArtistRegistryReadExtension(address(this), coordinator));
    }
}
