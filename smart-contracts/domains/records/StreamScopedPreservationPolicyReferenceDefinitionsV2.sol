// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact V2 token-preservation family reference definitions; all V1 bytes remain unchanged.
library StreamScopedPreservationPolicyReferenceDefinitionsV2 {
    bytes32 internal constant SCHEMA_ID =
        keccak256("STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_ABI_V2");
    bytes32 internal constant SCHEMA_HASH =
        0xaa86ba8fd6a4a9d4eecbee301ee99cea49e9efdecf728f4d57d4a6a6cfc88727;
    uint32 internal constant SCHEMA_BYTES = 28358;
    bytes32 internal constant PROFILE_ID =
        keccak256("STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_PROFILE_V2");
    bytes32 internal constant PROFILE_HASH =
        0x19764e02e956ee4855d429fd13fa632392d97454b0807eb7a439686a20da6be5;
    uint32 internal constant PROFILE_BYTES = 3250;
    bytes32 internal constant CANON_ID =
        keccak256("STREAM_ABI_SCOPED_PRESERVATION_POLICY_REFERENCE_V2");
    bytes32 internal constant CANON_HASH =
        0xd2149a31cf326579ae91ad48f5cbe10d2721a77c0001082a1b2812fef2f25039;
    uint32 internal constant CANON_BYTES = 2341;
}
