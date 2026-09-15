// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistOnboardingTypes.sol";

/// @notice Existing immutable Coordinator deployment facts for bounded record readers.
interface IStreamArtistSuiteReads {
    function suiteConfiguration()
        external
        view
        returns (StreamArtistOnboardingTypes.SuiteConfiguration memory);
    function deploymentChainId() external view returns (uint256);
}
