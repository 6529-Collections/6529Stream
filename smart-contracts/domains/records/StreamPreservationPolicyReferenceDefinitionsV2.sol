// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact V2 token-preservation family reference definitions; all V1 bytes remain unchanged.
library StreamPreservationPolicyReferenceDefinitionsV2 {
    bytes32 internal constant SCHEMA_ID =
        keccak256("STREAM_PRESERVATION_POLICY_COLLECTION_REFERENCE_ABI_V2");
    bytes32 internal constant SCHEMA_HASH =
        0x015dc229364e4b3b82225ac96d9010c04d570a173dd011bc0db96e860b8d913a;
    uint32 internal constant SCHEMA_BYTES = 29589;
    bytes32 internal constant PROFILE_ID =
        keccak256("STREAM_PRESERVATION_POLICY_COLLECTION_REFERENCE_PROFILE_V2");
    bytes32 internal constant PROFILE_HASH =
        0xe2263771b4e5178c556bf9e321f57d4a8b3844b9a2e7577f233720f6fc088bda;
    uint32 internal constant PROFILE_BYTES = 2029;
    bytes32 internal constant CANON_ID =
        keccak256("STREAM_ABI_PRESERVATION_POLICY_COLLECTION_REFERENCE_V2");
    bytes32 internal constant CANON_HASH =
        0xd2a02feba1926199b5a2b1bd736c0cb6d1f08a8024561d59db224a90c294800d;
    uint32 internal constant CANON_BYTES = 1368;
}
