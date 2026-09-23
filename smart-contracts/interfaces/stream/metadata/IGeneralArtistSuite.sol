// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistOnboardingTypes
} from "../artist/StreamArtistOnboardingTypes.sol";

interface IGeneralArtistSuite {
    function suiteConfiguration()
        external
        view
        returns (StreamArtistOnboardingTypes.SuiteConfiguration memory);
}
