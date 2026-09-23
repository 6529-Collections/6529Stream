// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    ActualCanonicalDutchWaivedFixture,
    ActualCanonicalDutchDocumentaryFixture
} from "../../experiments/collector-gas/ActualCanonicalDutchPurchase.t.sol";
import { StreamArtistSuiteFixture } from "./StreamArtistSuiteFixture.sol";
import { StreamArtistActivationPlan } from "../../script/current/StreamArtistActivationPlan.sol";
import { StreamArtistOnboardingTypes as T } from "../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamCanonicalNativeSalesDeployment as CanonicalDeployment
} from "../../script/current/StreamCanonicalNativeSalesDeployment.sol";
import { StreamCurrentTestCanonicalCompanions } from "./StreamCurrentTestCanonicalCompanions.sol";
import { IStreamSplitFactory } from "../../smart-contracts/interfaces/stream/revenue/IStreamSplitFactory.sol";

interface IStreamCurrentTestPaidArtistSuiteDeployment {
    function deployArtistSuite(
        address core_, address manager_, address roles_, IStreamSplitFactory factory_,
        address executor_, bytes32 deploymentHash
    ) external;
    function completeArtistSuite(bytes calldata rendererCatalog) external;
}

interface IStreamCurrentTestPaidArtistSuiteStart {
    function startArtistSuite(
        address core_, address manager_, address roles_, address executor_, bytes32 deploymentHash
    ) external returns (T.SuiteConfiguration memory);
}

interface IStreamCurrentTestPaidArtistSuiteFinish {
    function finishArtistSuite(
        T.SuiteConfiguration calldata suite, address core_, IStreamSplitFactory factory_,
        address executor_, bytes32 deploymentHash
    ) external;
}

interface IStreamCurrentTestPaidArtistSuiteComplete {
    function completeArtistSuite(bytes calldata rendererCatalog) external;
}


/// @dev Phase code retains the exact fixture storage prefix. During delegatecall,
/// `this` is the paid host, whose original callback bodies remain reachable.
/// Calls directed at the helper itself must never execute fixture callbacks.
abstract contract StreamCurrentTestPaidWaivedPhaseBase is ActualCanonicalDutchWaivedFixture {
    error PhaseCallbackOnHelper();
    function executeCurrentGovernorCall(address, bytes calldata) external override {
        revert PhaseCallbackOnHelper();
    }
    function scheduleArtistActivationForTest(StreamArtistActivationPlan.Plan calldata, uint64)
        external override { revert PhaseCallbackOnHelper(); }
    function executeSavedArtistActivation(StreamArtistActivationPlan.Plan calldata, bytes32, address)
        external override { revert PhaseCallbackOnHelper(); }
}

abstract contract StreamCurrentTestPaidDocumentaryPhaseBase is ActualCanonicalDutchDocumentaryFixture {
    error PhaseCallbackOnHelper();
    function executeCurrentGovernorCall(address, bytes calldata) external override {
        revert PhaseCallbackOnHelper();
    }
    function scheduleArtistActivationForTest(StreamArtistActivationPlan.Plan calldata, uint64)
        external override { revert PhaseCallbackOnHelper(); }
    function executeSavedArtistActivation(StreamArtistActivationPlan.Plan calldata, bytes32, address)
        external override { revert PhaseCallbackOnHelper(); }
}
