// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact prospective owner-notice schema/profile documents; no registration claim.
library StreamOwnerNoticeDefinitions {
    bytes32 internal constant STEWARD_SCHEMA_ID = keccak256("STREAM_STEWARD_DESIGNATION_V1");
    bytes32 internal constant STEWARD_SCHEMA_HASH =
        0xe6d13067056e0f81773d5f66feba198a371e76bb073f7e1fd7d6dd2bc1ffc022;
    uint256 internal constant STEWARD_SCHEMA_BYTES = 3482;
    bytes32 internal constant STEWARD_PROFILE_ID =
        keccak256("STREAM_STEWARD_DESIGNATION_JSON_PROFILE_V1");
    bytes32 internal constant STEWARD_PROFILE_HASH =
        0xe397665661963aff1fcc44c4c67c6bad990be52e3ee04e674c8ce26cb758a440;
    uint256 internal constant STEWARD_PROFILE_BYTES = 2271;
    bytes32 internal constant RESPONSE_SCHEMA_ID = keccak256("STREAM_RECOVERY_RESPONSE_V1");
    bytes32 internal constant RESPONSE_SCHEMA_HASH =
        0x898ad55cd6c9e2ab7d1d7092e7c377f97b6fd0021066c672d02d31c5b5554024;
    uint256 internal constant RESPONSE_SCHEMA_BYTES = 2463;
    bytes32 internal constant RESPONSE_PROFILE_ID =
        keccak256("STREAM_RECOVERY_RESPONSE_JSON_PROFILE_V1");
    bytes32 internal constant RESPONSE_PROFILE_HASH =
        0x83184d0cf45e040aa15ec66352261e745f13b10943052cf030327867fb6f1d88;
    uint256 internal constant RESPONSE_PROFILE_BYTES = 2346;
}
