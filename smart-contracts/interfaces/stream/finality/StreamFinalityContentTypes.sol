// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Current, complete collection content joined to its artist-approved Router publication.
/// @dev These are content facts for the typed evidence provider, not the complete finality inputs.
///      leafCoverageHash covers the leaf-list artifact only; it is never full bundle coverage.
struct StreamFinalityContentEvidence {
    bytes32 rootRecordHash;
    bytes32 verifiedManifestRecordHash;
    bytes32 checkpointHash;
    bytes32 leafArtifactHash;
    bytes32 leafCoverageHash;
    bytes32 artistId;
    bytes32 bindingHash;
    bytes32 inventoryHash;
    bytes32 servingStateHash;
    bytes32 contentRoot;
    bytes32 manifestHash;
    uint64 bindingGeneration;
    uint64 leafCount;
}
