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

/// @dev Deploy phase code from this helper's own nonce; the original paid host
/// still performs exactly its original Artist-helper CREATE before Stack-helper CREATE.
contract StreamCurrentTestPaidDocumentaryArtistSuiteDeployment is StreamCurrentTestPaidDocumentaryPhaseBase, IStreamCurrentTestPaidArtistSuiteDeployment {
    address private immutable _deploymentHost = msg.sender;
    address private immutable _start;
    address private immutable _finish;
    address private immutable _complete;

    constructor() {
        _start = _artistArtifactCreate(
            "test/helpers/StreamCurrentTestPaidDocumentaryArtistSuiteStart.sol:StreamCurrentTestPaidDocumentaryArtistSuiteStart",
            abi.encode(msg.sender)
        );
        _finish = _artistArtifactCreate(
            "test/helpers/StreamCurrentTestPaidDocumentaryArtistSuiteFinish.sol:StreamCurrentTestPaidDocumentaryArtistSuiteFinish",
            abi.encode(msg.sender)
        );
        _complete = _artistArtifactCreate(
            "test/helpers/StreamCurrentTestPaidDocumentaryArtistSuiteComplete.sol:StreamCurrentTestPaidDocumentaryArtistSuiteComplete",
            abi.encode(msg.sender)
        );
    }

    function setUp() public override { }

    function deployArtistSuite(
        address core_, address manager_, address roles_, IStreamSplitFactory factory_,
        address executor_, bytes32 deploymentHash
    ) external override {
        require(address(this) == _deploymentHost, "original paid host delegatecall required");
        bytes memory result = _delegate(_start, abi.encodeCall(
            IStreamCurrentTestPaidArtistSuiteStart.startArtistSuite,
            (core_, manager_, roles_, executor_, deploymentHash)
        ));
        T.SuiteConfiguration memory suite = abi.decode(result, (T.SuiteConfiguration));
        _delegate(_finish, abi.encodeCall(
            IStreamCurrentTestPaidArtistSuiteFinish.finishArtistSuite,
            (suite, core_, factory_, executor_, deploymentHash)
        ));
    }

    function completeArtistSuite(bytes calldata rendererCatalog) external override {
        require(address(this) == _deploymentHost, "original paid host delegatecall required");
        _delegate(_complete, abi.encodeCall(
            IStreamCurrentTestPaidArtistSuiteComplete.completeArtistSuite, (rendererCatalog)
        ));
    }

    function _delegate(address target, bytes memory data) private returns (bytes memory result) {
        bool ok;
        (ok, result) = target.delegatecall(data);
        if (!ok) {
            assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        }
    }

    function _deployCanonicalCompanions(CanonicalDeployment.Configuration memory c)
        internal override returns (CanonicalDeployment.Products memory)
    { return StreamCurrentTestCanonicalCompanions.deploy(c); }
}
