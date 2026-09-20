// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Closed additive VIEW preservation BYTE_EXACT definitions.
library StreamViewPreservationReferenceDefinitionsV1 {
    bytes32 internal constant SCHEMA_ID =
        keccak256("STREAM_VIEW_PRESERVATION_REFERENCE_RENDER_ABI_V1");
    bytes32 internal constant SCHEMA_HASH =
        0x02f129343fa85335c68732f44a41361ac0891401de7fb6a2037c42c2bba212a2;
    uint32 internal constant SCHEMA_BYTES = 20629;
    bytes32 internal constant PROFILE_ID =
        keccak256("STREAM_VIEW_PRESERVATION_REFERENCE_RENDER_PROFILE_V1");
    bytes32 internal constant PROFILE_HASH =
        0x7d57b0f7d128ad476120e43445c6361a80089baa1205b75d776bdcadad5ed684;
    uint32 internal constant PROFILE_BYTES = 1553;
    bytes32 internal constant CANON_ID = keccak256("STREAM_VIEW_PRESERVATION_REFERENCE_CANON_V1");
    bytes32 internal constant CANON_HASH =
        0x63cdb25fc76dd8d9cbbdd8be7f1444c092b0bf96f6a0199a7bee20abe2107491;
    uint32 internal constant CANON_BYTES = 870;
}
