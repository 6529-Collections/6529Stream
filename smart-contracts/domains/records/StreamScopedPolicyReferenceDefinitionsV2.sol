// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact additive scoped-policy reference definitions; original profiles remain unchanged.
library StreamScopedPolicyReferenceDefinitionsV2 {
    bytes32 internal constant SCHEMA_ID = keccak256("STREAM_SCOPED_POLICY_REFERENCE_ABI_V2");
    bytes32 internal constant SCHEMA_HASH =
        0x66d9b03f9b6c4aa37c55df3f47a5d21a964a419bd93a83130bbf0487a0a26715;
    uint32 internal constant SCHEMA_BYTES = 26018;
    bytes32 internal constant PROFILE_ID = keccak256("STREAM_SCOPED_POLICY_REFERENCE_PROFILE_V2");
    bytes32 internal constant PROFILE_HASH =
        0x4351690bd9597070d7de6a17071c7103d46a52efc757954a567fe542ecb64a47;
    uint32 internal constant PROFILE_BYTES = 2114;
    bytes32 internal constant CANON_ID = keccak256("STREAM_ABI_SCOPED_POLICY_REFERENCE_V2");
    bytes32 internal constant CANON_HASH =
        0xfd2a277aa777a57d09d19665f0c73a2a9ace95f4fa3c3b9b8340917e53c79028;
    uint32 internal constant CANON_BYTES = 1412;
}
