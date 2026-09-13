// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Constructor-fixed module identity and archival counterpart for canonical finality.
struct StreamFinalityDeploymentConfiguration {
    address artifactCoverage;
    bytes32 deploymentManifestHash;
    string manifestURI;
    bytes32 manifestHash;
}
