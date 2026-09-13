// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact prospective conservation documents, with no registration claim.
library StreamConservationDefinitions {
    bytes32 internal constant INTERVIEW_SCHEMA_ID = keccak256("STREAM_ARTIST_INTERVIEW_V1");
    bytes32 internal constant INTERVIEW_SCHEMA_HASH =
        0x826e7082f5ddcdb972c22411bca7adfd71b7feac7980eaabeb5dc5ec79eb3963;
    uint256 internal constant INTERVIEW_SCHEMA_BYTES = 11052;
    bytes32 internal constant INTERVIEW_PROFILE_ID =
        keccak256("STREAM_ARTIST_INTERVIEW_JSON_PROFILE_V1");
    bytes32 internal constant INTERVIEW_PROFILE_HASH =
        0x1533a5140b53a7b0bc3f76524cb01d44c62391c8db570cbdff11fbc9dea6e9cf;
    uint256 internal constant INTERVIEW_PROFILE_BYTES = 3820;
    bytes32 internal constant INTENT_SCHEMA_ID = keccak256("STREAM_ARTIST_INTENT_V1");
    bytes32 internal constant INTENT_SCHEMA_HASH =
        0x733ff58eb9521aedd7d74c0b53620306095720e5688cbe5b7d94228665f9a009;
    uint256 internal constant INTENT_SCHEMA_BYTES = 10223;
    bytes32 internal constant INTENT_PROFILE_ID = keccak256("STREAM_ARTIST_INTENT_JSON_PROFILE_V1");
    bytes32 internal constant INTENT_PROFILE_HASH =
        0x1522f0f9498ac4a0f652ff201b0681a3711234a15189713cf5e71f71ba53c9c6;
    uint256 internal constant INTENT_PROFILE_BYTES = 3814;
    bytes32 internal constant WAIVER_SCHEMA_ID = keccak256("STREAM_ARTIST_INTENT_WAIVER_V1");
    bytes32 internal constant WAIVER_SCHEMA_HASH =
        0xbd017f973eb0c21bc4c1e57bebafd7e48774e8dc91b2424a14597b96a5edfc93;
    uint256 internal constant WAIVER_SCHEMA_BYTES = 4927;
    bytes32 internal constant WAIVER_PROFILE_ID =
        keccak256("STREAM_ARTIST_INTENT_WAIVER_JSON_PROFILE_V1");
    bytes32 internal constant WAIVER_PROFILE_HASH =
        0xdce44685b162b745cde2e4611d571612c3dc40ab890bedc73436bcd2408f41e1;
    uint256 internal constant WAIVER_PROFILE_BYTES = 3828;
    bytes32 internal constant CATALOG_SCHEMA_ID =
        keccak256("STREAM_CONSERVATION_FORMAT_CATALOG_V1");
    bytes32 internal constant CATALOG_SCHEMA_HASH =
        0xb751512d8420de5e72907298460560aa25e274617b9ff25607bf80f1ffa982df;
    uint256 internal constant CATALOG_SCHEMA_BYTES = 2059;
    bytes32 internal constant CATALOG_PROFILE_ID =
        keccak256("STREAM_CONSERVATION_FORMAT_CATALOG_JSON_PROFILE_V1");
    bytes32 internal constant CATALOG_PROFILE_HASH =
        0x5e3712a9d1b640532be098b10855d013323bd7a852cf3b548dfff9babbdb7b3c;
    uint256 internal constant CATALOG_PROFILE_BYTES = 3842;
}
