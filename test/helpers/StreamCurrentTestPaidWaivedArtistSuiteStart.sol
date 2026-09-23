// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamCurrentTestPaidWaivedPhaseBase } from "./StreamCurrentTestPaidArtistSuiteDeployment.sol";
import { StreamArtistOnboardingTypes as T } from "../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @dev Same inherited storage prefix as the paid host; only one original phase is reachable.
contract StreamCurrentTestPaidWaivedArtistSuiteStart is StreamCurrentTestPaidWaivedPhaseBase {
    address private immutable _deploymentHost;
    constructor(address deploymentHost_) { _deploymentHost = deploymentHost_; }
    function setUp() public override { }
    function startArtistSuite(
        address core_, address manager_, address roles_, address executor_, bytes32 deploymentHash
    ) external returns (T.SuiteConfiguration memory) {
        require(address(this) == _deploymentHost, "original paid host delegatecall required");
        return _deployArtistSuiteStart(core_, manager_, roles_, executor_, deploymentHash);
    }
}
