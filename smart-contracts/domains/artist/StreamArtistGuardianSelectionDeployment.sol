// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistGuardianSelectionPreparation
} from "./StreamArtistGuardianSelectionPreparation.sol";

/// @notice Fixed Recovery-child construction, keeping preparation creation code out of its factory.
library StreamArtistGuardianSelectionDeployment {
    function deploy(address owner, address registry) public returns (address) {
        return address(new StreamArtistGuardianSelectionPreparation(owner, registry));
    }
}
