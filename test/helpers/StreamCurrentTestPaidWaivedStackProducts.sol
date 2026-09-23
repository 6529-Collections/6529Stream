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
contract StreamCurrentTestPaidWaivedStackProducts is StreamCurrentTestPaidWaivedPhaseBase {
    address private immutable _deploymentHost;
    address private immutable _artistSuiteDeployment;
    constructor(address deploymentHost_, address artistSuiteDeployment_) {
        _deploymentHost = deploymentHost_;
        _artistSuiteDeployment = artistSuiteDeployment_;
    }
    function setUp() public override { }
    function deployProducts(address platform) external {
        require(address(this) == _deploymentHost, "original paid host delegatecall required");
        _deployCurrentStackProducts(platform);
    }
    function _deployArtistSuite(
        address core_, address manager_, address roles_, IStreamSplitFactory factory_,
        address executor_, bytes32 deploymentHash
    ) internal override {
        (bool ok, bytes memory result) = _artistSuiteDeployment.delegatecall(
            abi.encodeCall(IStreamCurrentTestPaidArtistSuiteDeployment.deployArtistSuite,
                (core_, manager_, roles_, factory_, executor_, deploymentHash))
        );
        if (!ok) { assembly ("memory-safe") { revert(add(result, 32), mload(result)) } }
    }

    function _deployCanonicalCompanions(CanonicalDeployment.Configuration memory c)
        internal override returns (CanonicalDeployment.Products memory)
    { return StreamCurrentTestCanonicalCompanions.deploy(c); }
}
