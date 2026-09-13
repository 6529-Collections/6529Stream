// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact constructor targets; every address must be deployed and reciprocally bound.
struct StreamFinalityRecoveryTargets {
    address core;
    address executor;
    address originalFinality;
    address artist;
    address ownerEvidence;
}

/// @notice Immutable module-document identity for a new recovery companion.
struct StreamFinalityRecoveryDeploymentConfiguration {
    bytes32 deploymentManifestHash;
    string manifestURI;
    bytes32 manifestHash;
}
