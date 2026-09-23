// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCanonicalNativeSalesDeployment as D
} from "../../script/current/StreamCanonicalNativeSalesDeployment.sol";

/// @notice Original companion construction for the two paid discovery hosts.
/// @dev A public library call uses DELEGATECALL in the fixture context. The original
/// deployment helper retains configuration checks, CREATE order, ownership handoff
/// and product validation. Fresh native and export evidence remains required.
library StreamCurrentTestCanonicalCompanions {
    function deploy(D.Configuration memory c) public returns (D.Products memory) {
        return D.deploy(c);
    }
}
