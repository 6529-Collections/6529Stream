// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamCurrentTestPaidStackDeployment,
    IStreamCurrentTestPaidStackFoundation,
    IStreamCurrentTestPaidStackProducts,
    IStreamCurrentTestPaidStackActivation
} from "./StreamCurrentTestPaidStackDeployment.sol";
import {
    IStreamCurrentTestPaidArtistSuiteDeployment,
    StreamCurrentTestPaidWaivedPhaseBase,
    StreamCurrentTestPaidDocumentaryPhaseBase
} from "./StreamCurrentTestPaidArtistSuiteDeployment.sol";
import { IStreamSplitFactory } from "../../smart-contracts/interfaces/stream/revenue/IStreamSplitFactory.sol";
import { StreamCanonicalNativeSalesDeployment as CanonicalDeployment } from "../../script/current/StreamCanonicalNativeSalesDeployment.sol";
import { StreamCurrentTestCanonicalCompanions } from "./StreamCurrentTestCanonicalCompanions.sol";

/// @dev Exact paid-host storage prefix and one sequential phase of the original stack.
contract StreamCurrentTestPaidWaivedStackActivation is StreamCurrentTestPaidWaivedPhaseBase {
    address private immutable _deploymentHost;
    address private immutable _artistSuiteDeployment;
    constructor(address deploymentHost_, address artistSuiteDeployment_) {
        _deploymentHost = deploymentHost_;
        _artistSuiteDeployment = artistSuiteDeployment_;
    }
    function setUp() public override { }
    function activateStack() external {
        require(address(this) == _deploymentHost, "original paid host delegatecall required");
        ledger.transferOwnership(address(executor));
        sale.transferOwnership(address(executor));
        auction.transferOwnership(address(executor));
        _activateFixtureGraphPrerequisites();
        _completeFixtureArtistSuite(_currentGraphRendererCatalog(1));
        _assertDeployableProductionContracts();
    }
    function _completeFixtureArtistSuite(bytes memory rendererCatalog) internal override {
        (bool ok, bytes memory result) = _artistSuiteDeployment.delegatecall(
            abi.encodeCall(IStreamCurrentTestPaidArtistSuiteDeployment.completeArtistSuite,
                (rendererCatalog))
        );
        if (!ok) { assembly ("memory-safe") { revert(add(result, 32), mload(result)) } }
    }

    function _deployCanonicalCompanions(CanonicalDeployment.Configuration memory c)
        internal override returns (CanonicalDeployment.Products memory)
    { return StreamCurrentTestCanonicalCompanions.deploy(c); }
}
