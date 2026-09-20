// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact additive scoped-snapshot definitions; original COLLECTION definitions remain unchanged.
library StreamScopedSnapshotDefinitions {
    bytes32 internal constant SCHEMA_ID = keccak256("STREAM_SCOPED_STATIC_SNAPSHOT_ABI_V1");
    bytes32 internal constant SCHEMA_HASH =
        0x499f3da8e9edac9c6fc724c2416768ec04333b31a128aed36b16b5364d91c68f;
    uint256 internal constant SCHEMA_BYTES = 6108;
    bytes32 internal constant PROFILE_ID = keccak256("STREAM_SCOPED_STATIC_SNAPSHOT_PROFILE_V1");
    bytes32 internal constant PROFILE_HASH =
        0xa8863cf6dac274c227895b49ab106c43176ce1f3bc9120e81229d16027352135;
    uint256 internal constant PROFILE_BYTES = 1454;
    bytes32 internal constant CANON_ID = keccak256("STREAM_SOLIDITY_ABI_V1");
    bytes32 internal constant CANON_HASH =
        0x88c5f5a1b04f40ebae17a2c6f85ba5cd88c32d9139a809f0a1b209afbe15e883;
    uint256 internal constant CANON_BYTES = 274;
}
