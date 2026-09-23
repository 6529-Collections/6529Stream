// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistOnboardingTypes as T
} from "../artist/StreamArtistOnboardingTypes.sol";

interface IStreamMetadataArtistConfiguration {
    function suiteConfiguration() external view returns (T.SuiteConfiguration memory);
    function configurationHash() external view returns (bytes32);
    function finalityRegistry() external view returns (address);
    function finalityEvidenceProvider() external view returns (address);
}
