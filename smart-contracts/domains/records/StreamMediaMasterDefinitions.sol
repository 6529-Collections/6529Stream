// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact prospective documents; registration remains a separate governed action.
library StreamMediaMasterDefinitions {
    bytes32 internal constant MASTER_SCHEMA_ID = keccak256("STREAM_MEDIA_MASTER_ASSOCIATION_V1");
    bytes32 internal constant MASTER_SCHEMA_HASH = 0xffa74f87b27c73aced2cf2e9f9da7d8255b947b1a7627b0a71536c2a35b8f0e5;
    uint256 internal constant MASTER_SCHEMA_BYTES = 1042;
    bytes32 internal constant WAIVER_SCHEMA_ID = keccak256("STREAM_MASTER_WAIVER_V1");
    bytes32 internal constant WAIVER_SCHEMA_HASH = 0x7e437d7591cb009ab71fbdf006e3286e64a74846d66bac9eabef46840d0eb069;
    uint256 internal constant WAIVER_SCHEMA_BYTES = 2121;
    bytes32 internal constant PROFILE_ID = keccak256("STREAM_MEDIA_MASTER_SELECTED_SLOTS_PROFILE_V1");
    bytes32 internal constant PROFILE_HASH = 0x77133c55381ef35de45e4824c63983ae7ff021a4fb2b8da2a036ec06c0126ff2;
    uint256 internal constant PROFILE_BYTES = 2039;
}
