// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact additive COLLECTION policy-reference definitions, independent of V1.
library StreamPolicyReferenceDefinitionsV2 {
    bytes32 internal constant SCHEMA_ID = keccak256("STREAM_POLICY_COLLECTION_REFERENCE_ABI_V2");
    bytes32 internal constant SCHEMA_HASH =
        0x2c3ca0f8024e93c0d56432cf0de6fe366e23f61c351fb0dde5f6cb57393905dd;
    uint32 internal constant SCHEMA_BYTES = 25617;
    bytes32 internal constant PROFILE_ID =
        keccak256("STREAM_POLICY_COLLECTION_REFERENCE_PROFILE_V2");
    bytes32 internal constant PROFILE_HASH =
        0x8ca1d41960302384b3e6c4c9bdce081051e5a2ddc30499fced919075a537865c;
    uint32 internal constant PROFILE_BYTES = 1465;
    bytes32 internal constant CANON_ID = keccak256("STREAM_ABI_POLICY_COLLECTION_REFERENCE_V2");
    bytes32 internal constant CANON_HASH =
        0xa360444f7e1e5f31c8bcdd8a2bb305a26a58fe612f7d3013d08c9b1dc16fb212;
    uint32 internal constant CANON_BYTES = 921;
}
