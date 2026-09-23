// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    ActualCanonicalDutchWaivedFixture,
    ActualCanonicalDutchDocumentaryFixture
} from "../../experiments/collector-gas/ActualCanonicalDutchPurchase.t.sol";
import { StreamCurrentStackFixture } from "./StreamCurrentStackFixture.sol";
import {
    StreamCanonicalNativeSalesDeployment as CanonicalDeployment
} from "../../script/current/StreamCanonicalNativeSalesDeployment.sol";
import { StreamCurrentTestCanonicalCompanions } from "./StreamCurrentTestCanonicalCompanions.sol";
import { IStreamSplitFactory } from "../../smart-contracts/interfaces/stream/revenue/IStreamSplitFactory.sol";
import {
    IStreamCurrentTestPaidArtistSuiteDeployment,
    StreamCurrentTestPaidWaivedPhaseBase,
    StreamCurrentTestPaidDocumentaryPhaseBase
} from "./StreamCurrentTestPaidArtistSuiteDeployment.sol";

interface IStreamCurrentTestPaidStackDeployment {
    function deployCurrentStack(address artist_, address platform) external;
}

interface IStreamCurrentTestPaidStackFoundation {
    function deployFoundation(address artist_) external;
}
interface IStreamCurrentTestPaidStackProducts {
    function deployProducts(address platform) external;
}
interface IStreamCurrentTestPaidStackActivation {
    function activateStack() external;
}
