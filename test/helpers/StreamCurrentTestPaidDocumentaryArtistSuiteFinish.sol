// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamCurrentTestPaidArtistSuiteDeployment,
    IStreamCurrentTestPaidArtistSuiteStart,
    IStreamCurrentTestPaidArtistSuiteFinish,
    IStreamCurrentTestPaidArtistSuiteComplete,
    StreamCurrentTestPaidWaivedPhaseBase,
    StreamCurrentTestPaidDocumentaryPhaseBase
} from "./StreamCurrentTestPaidArtistSuiteDeployment.sol";
import { StreamArtistOnboardingTypes as T } from "../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import { StreamArtistSuiteFixture } from "./StreamArtistSuiteFixture.sol";
import { IStreamSplitFactory } from "../../smart-contracts/interfaces/stream/revenue/IStreamSplitFactory.sol";
import { StreamCanonicalNativeSalesDeployment as CanonicalDeployment } from "../../script/current/StreamCanonicalNativeSalesDeployment.sol";
import { StreamCurrentTestCanonicalCompanions } from "./StreamCurrentTestCanonicalCompanions.sol";

/// @dev Same inherited storage prefix as the paid host; only one original phase is reachable.
contract StreamCurrentTestPaidDocumentaryArtistSuiteFinish is StreamCurrentTestPaidDocumentaryPhaseBase {
    address private immutable _deploymentHost;
    constructor(address deploymentHost_) { _deploymentHost = deploymentHost_; }
    function setUp() public override { }
    function finishArtistSuite(
        T.SuiteConfiguration calldata suite, address core_, IStreamSplitFactory factory_,
        address executor_, bytes32 deploymentHash
    ) external {
        require(address(this) == _deploymentHost, "original paid host delegatecall required");
        _deployArtistSuiteFinish(suite, core_, factory_, executor_, deploymentHash);
    }
}
