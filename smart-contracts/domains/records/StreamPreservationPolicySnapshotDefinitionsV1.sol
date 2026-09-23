// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact additive COLLECTION preservation documents; no historical definition is changed.
library StreamPreservationPolicySnapshotDefinitionsV1 {
    bytes32 internal constant SCHEMA_ID =
        keccak256("STREAM_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_ABI_V1");
    bytes32 internal constant SCHEMA_HASH =
        0xcf598f895a8c5b3f875c0a6438a0d3ffd0a0c6554fa5695c92eda33b74bee61c;
    uint256 internal constant SCHEMA_BYTES = 14452;
    bytes32 internal constant PROFILE_ID =
        keccak256("STREAM_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_PROFILE_V1");
    bytes32 internal constant PROFILE_HASH =
        0x687304485540d9b39c14e7158ed4f36b56799ad84bbc115b0ac63750a59a8d0e;
    uint256 internal constant PROFILE_BYTES = 1306;
    bytes32 internal constant CANON_ID =
        keccak256("STREAM_ABI_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_V1");
    bytes32 internal constant CANON_HASH =
        0x9710811fcfb6f47e87c22b603c062300d76b78f7b462b334c73addb351788890;
    uint256 internal constant CANON_BYTES = 917;
}
