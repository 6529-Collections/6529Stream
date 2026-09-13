// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistRegistryFinalityReadExtension.sol";

/// @notice Compiler-linked CREATE preserves the facade as creator and its third child nonce.
library StreamArtistFinalityReadDeployment {
    function deployReader(address coordinator) public returns (address) {
        return address(new StreamArtistRegistryFinalityReadExtension(address(this), coordinator));
    }
}
