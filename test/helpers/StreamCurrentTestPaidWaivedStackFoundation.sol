// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamCurrentTestPaidWaivedPhaseBase } from "./StreamCurrentTestPaidArtistSuiteDeployment.sol";
import { StreamCanonicalNativeSalesDeployment as CanonicalDeployment } from "../../script/current/StreamCanonicalNativeSalesDeployment.sol";
import { StreamCurrentTestCanonicalCompanions } from "./StreamCurrentTestCanonicalCompanions.sol";

/// @dev Exact paid-host storage prefix and one sequential phase of the original stack.
contract StreamCurrentTestPaidWaivedStackFoundation is StreamCurrentTestPaidWaivedPhaseBase {
    address private immutable _deploymentHost;
    constructor(address deploymentHost_) { _deploymentHost = deploymentHost_; }
    function setUp() public override { }
    function deployFoundation(address artist_) external {
        require(address(this) == _deploymentHost, "original paid host delegatecall required");
        _deployCurrentStackFoundation(artist_);
    }

    function _deployCanonicalCompanions(CanonicalDeployment.Configuration memory c)
        internal override returns (CanonicalDeployment.Products memory)
    { return StreamCurrentTestCanonicalCompanions.deploy(c); }
}
