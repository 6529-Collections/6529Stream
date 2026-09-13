// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Fixed Coordinator facts used to derive the companion's historical artist trust roots.
/// @dev A caller subset of existing getters, not a new artist admission or module interface.
interface IStreamArtistRecoveryDeployment {
    function suiteConfiguration() external view returns (T.SuiteConfiguration memory);
    function deploymentChainId() external view returns (uint256);
    function finalityRegistry() external view returns (address);
    function finalityRegistryCodeHash() external view returns (bytes32);
}
