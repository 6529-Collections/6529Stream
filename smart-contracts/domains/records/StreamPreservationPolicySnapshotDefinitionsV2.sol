// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact fixed-family V2 documents; all original V1 documents remain unchanged.
library StreamPreservationPolicySnapshotDefinitionsV2 {
    bytes32 internal constant SCHEMA_ID =
        keccak256("STREAM_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_ABI_V2");
    bytes32 internal constant SCHEMA_HASH =
        0xc134c9c28e87f89ba1bfeb6b1fc2a8da0da95731ae51310f95ee1dd5f5c66df3;
    uint256 internal constant SCHEMA_BYTES = 15067;
    bytes32 internal constant PROFILE_ID =
        keccak256("STREAM_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_PROFILE_V2");
    bytes32 internal constant PROFILE_HASH =
        0x35aa9ac3dc7dc9c84d70f1010b26856a2b9cb99090f07e4eeba19497ba0f5069;
    uint256 internal constant PROFILE_BYTES = 1921;
    bytes32 internal constant CANON_ID =
        keccak256("STREAM_ABI_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_V2");
    bytes32 internal constant CANON_HASH =
        0x8b9344fea9019c2628f43b9fd09361a2fdcf4e59ae858aadba93493316d2e128;
    uint256 internal constant CANON_BYTES = 917;
}
