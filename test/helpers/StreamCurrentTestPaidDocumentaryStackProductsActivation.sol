// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamCurrentTestPaidDocumentaryPhaseBase } from "./StreamCurrentTestPaidArtistSuiteDeployment.sol";
import { StreamCanonicalNativeSalesDeployment as CanonicalDeployment } from "../../script/current/StreamCanonicalNativeSalesDeployment.sol";
import { StreamCurrentTestCanonicalCompanions } from "./StreamCurrentTestCanonicalCompanions.sol";

/// @dev Runs the original initial-products activation in the paid host's storage.
contract StreamCurrentTestPaidDocumentaryStackProductsActivation is StreamCurrentTestPaidDocumentaryPhaseBase {
    address private immutable _deploymentHost;

    constructor(address deploymentHost_) {
        _deploymentHost = deploymentHost_;
    }

    function setUp() public override { }

    function activateStack() external {
        require(address(this) == _deploymentHost, "original paid host delegatecall required");
        _activateInitialProducts();
    }

    function _deployCanonicalCompanions(CanonicalDeployment.Configuration memory c)
        internal override returns (CanonicalDeployment.Products memory)
    { return StreamCurrentTestCanonicalCompanions.deploy(c); }
}
