// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact additive COLLECTION V2 documents; no historical definition is changed.
library StreamPolicySnapshotDefinitionsV2 {
    bytes32 internal constant SCHEMA_ID = keccak256("STREAM_POLICY_COLLECTION_SNAPSHOT_ABI_V2");
    bytes32 internal constant SCHEMA_HASH =
        0x6ce0b16d401945bed7819da4e930d5b1900216c9b6587729043cedbaa4e9c95f;
    uint256 internal constant SCHEMA_BYTES = 13761;
    bytes32 internal constant PROFILE_ID =
        keccak256("STREAM_POLICY_COLLECTION_SNAPSHOT_PROFILE_V2");
    bytes32 internal constant PROFILE_HASH =
        0xd8338f881f829b89f9ddebc5b9ca77b263953d6f9479a9c9d40da92a445b8433;
    uint256 internal constant PROFILE_BYTES = 995;
    bytes32 internal constant CANON_ID = keccak256("STREAM_ABI_POLICY_COLLECTION_SNAPSHOT_V2");
    bytes32 internal constant CANON_HASH =
        0x37956c437d3ddbda99c7b2cd3ed0445659d2fbab4adeb3b0532b3efd9a30fc63;
    uint256 internal constant CANON_BYTES = 853;
}
