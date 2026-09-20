// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Additive closed scoped reference definitions; original registered definitions stay unchanged.
library StreamScopedReferenceDefinitions {
    bytes32 internal constant SCHEMA_ID = keccak256("STREAM_SCOPED_REFERENCE_RENDER_ABI_V1");
    bytes32 internal constant SCHEMA_HASH =
        0xc7bd3633c9f2ef980414947cfa95c202a12be1852e065a2c3c8933408cd8ece2;
    uint32 internal constant SCHEMA_BYTES = 13010;
    bytes32 internal constant PROFILE_ID = keccak256("STREAM_SCOPED_REFERENCE_RENDER_PROFILE_V1");
    bytes32 internal constant PROFILE_HASH =
        0x763dd7a75e0a1f750e2dd5ea12b5e2ff2c11f1063f6f2e676d20cc6f3e6084a2;
    uint32 internal constant PROFILE_BYTES = 2195;
    bytes32 internal constant CANON_ID = keccak256("STREAM_SOLIDITY_ABI_V1");
    bytes32 internal constant CANON_HASH =
        0x88c5f5a1b04f40ebae17a2c6f85ba5cd88c32d9139a809f0a1b209afbe15e883;
    uint32 internal constant CANON_BYTES = 274;
}
