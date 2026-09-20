// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library StreamViewPreservationContentDefinitionsV1 {
    bytes32 internal constant PROFILE = keccak256("6529STREAM_VIEW_PRESERVATION_CONTENT_ROOT_V1");
    bytes32 internal constant SCHEMA_ID = keccak256("STREAM_VIEW_PRESERVATION_CONTENT_ROOT_V1");
    bytes32 internal constant SCHEMA_HASH =
        0x71b098d934ddbb3cabec5596e8062caafe5ae9dfed667070ec1de6756bf52d3e;
    uint256 internal constant SCHEMA_BYTES = 4738;
    bytes32 internal constant CANON_ID = keccak256("STREAM_ABI_VIEW_PRESERVATION_CONTENT_ROOT_V1");
    bytes32 internal constant CANON_HASH =
        0x4f00c5f5b949500583ddd0e68c30ed863c4496e76dca14b44c963c443eca8103;
    uint256 internal constant CANON_BYTES = 833;
}
