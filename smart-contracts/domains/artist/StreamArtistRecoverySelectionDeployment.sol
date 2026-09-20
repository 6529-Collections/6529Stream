// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoverySelectionPreparation
} from "./StreamArtistRecoverySelectionPreparation.sol";

library StreamArtistRecoverySelectionDeployment {
    function deploy(address owner, address registry) public returns (address) {
        return address(new StreamArtistRecoverySelectionPreparation(owner, registry));
    }
}
