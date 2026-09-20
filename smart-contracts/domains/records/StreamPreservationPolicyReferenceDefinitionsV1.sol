// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact additive COLLECTION preservation reference definitions; all old profiles remain unchanged.
library StreamPreservationPolicyReferenceDefinitionsV1 {
    bytes32 internal constant SCHEMA_ID =
        keccak256("STREAM_PRESERVATION_POLICY_COLLECTION_REFERENCE_ABI_V1");
    bytes32 internal constant SCHEMA_HASH =
        0x387fe93e70bc204ac0685617b90611b3eccebe7f8e9be78fee5f0cce1b495379;
    uint32 internal constant SCHEMA_BYTES = 29206;
    bytes32 internal constant PROFILE_ID =
        keccak256("STREAM_PRESERVATION_POLICY_COLLECTION_REFERENCE_PROFILE_V1");
    bytes32 internal constant PROFILE_HASH =
        0xfd74f1fb7a6d60a999685ada5840d612042fe0e98e87ae7a145da13f7257d0d3;
    uint32 internal constant PROFILE_BYTES = 1646;
    bytes32 internal constant CANON_ID =
        keccak256("STREAM_ABI_PRESERVATION_POLICY_COLLECTION_REFERENCE_V1");
    bytes32 internal constant CANON_HASH =
        0xcc5a1a28dafcc642ebfd3d6510aa9a4aac651a4329f6dc539c4e344b0a882ee4;
    uint32 internal constant CANON_BYTES = 985;
}
