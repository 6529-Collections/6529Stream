// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Original native policy and module identity for one indexed coordinator.
/// @dev Runtime is observed by inventory indexing; this is not a mint-time code proof.
struct StreamFinalityCoordinatorPolicy {
    address coordinator;
    bytes32 indexedCodeHash;
    uint256 firstTokenIndex;
    bool frozen;
    bytes32 moduleVersion;
    bytes32 moduleManifestHash;
    bytes32 moduleSchemaHash;
    bytes32 deploymentManifestHash;
    bytes32 policyHash;
    address provider;
    uint32 epoch;
    bytes32 salt;
    bytes32 componentDataHash;
}

/// @notice Ordered complete current policy set for an authenticated original-source inventory.
/// @dev No token-output/seed, external oracle code, archive or finality readiness claim.
struct StreamFinalityCoordinatorPolicyEvidence {
    bytes32 planId;
    bytes32 inventoryHash;
    bytes32 policyChainHash;
    uint256 policyCount;
    bool allFrozen;
    StreamFinalityCoordinatorPolicy[] policies;
}
