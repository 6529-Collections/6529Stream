// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistOnboardingTypes as T
} from "./StreamArtistOnboardingTypes.sol";

interface IStreamRepudiationSuite {
    function suiteConfiguration() external view returns (T.SuiteConfiguration memory);
}
