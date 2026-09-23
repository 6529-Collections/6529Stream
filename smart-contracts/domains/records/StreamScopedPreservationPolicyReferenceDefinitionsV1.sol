// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact additive preservation reference definitions; original profiles remain unchanged.
library StreamScopedPreservationPolicyReferenceDefinitionsV1 {
    bytes32 internal constant SCHEMA_ID =
        keccak256("STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_ABI_V1");
    bytes32 internal constant SCHEMA_HASH =
        0x8eb87b0f336b32f20a37fcecf387a627f4fdef957c05354cf2fcf5c41785de63;
    uint32 internal constant SCHEMA_BYTES = 27975;
    bytes32 internal constant PROFILE_ID =
        keccak256("STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_PROFILE_V1");
    bytes32 internal constant PROFILE_HASH =
        0xb297ef8dc5a22b2f7f2c2be2aa39200f1da5ddfd5e16b87f1f66ba55585015ba;
    uint32 internal constant PROFILE_BYTES = 2867;
    bytes32 internal constant CANON_ID =
        keccak256("STREAM_ABI_SCOPED_PRESERVATION_POLICY_REFERENCE_V1");
    bytes32 internal constant CANON_HASH =
        0xf2b69c19e3ad019ee9ce80e52ecd47a909ea785e1e23d249a14cbdaa474de7b5;
    uint32 internal constant CANON_BYTES = 1958;
}
