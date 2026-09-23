// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamCurrentTestPaidDocumentaryPhaseBase } from "./StreamCurrentTestPaidArtistSuiteDeployment.sol";
import { StreamCanonicalNativeSalesDeployment as CanonicalDeployment } from "../../script/current/StreamCanonicalNativeSalesDeployment.sol";
import { StreamCurrentTestCanonicalCompanions } from "./StreamCurrentTestCanonicalCompanions.sol";

/// @dev Runs the original artist, mint, and handoff operations in paid-host storage.
contract StreamCurrentTestPaidDocumentaryStackArtistActivation is StreamCurrentTestPaidDocumentaryPhaseBase {
    address private immutable _deploymentHost;

    constructor(address deploymentHost_) {
        _deploymentHost = deploymentHost_;
    }

    function setUp() public override { }

    function activateStack() external {
        require(address(this) == _deploymentHost, "original paid host delegatecall required");
        _activateArtistAuthority();
        _activateRevealAuthority();
        _prepareArtistOnboarding();
        _onboardFixtureArtist(artist);
        _expandArtistReadBudget();
        _configureMintPhase(PHASE, address(sale));
        _configureMintPhase(AUCTION_PHASE, address(auction));
        _configureAdditionalProducts();
        _handoffManager();
    }

    function _deployCanonicalCompanions(CanonicalDeployment.Configuration memory c)
        internal override returns (CanonicalDeployment.Products memory)
    { return StreamCurrentTestCanonicalCompanions.deploy(c); }
}
