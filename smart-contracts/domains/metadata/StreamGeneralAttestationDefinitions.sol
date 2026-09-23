// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Prospective exact definitions. Registration is checked at typed publication time.
library StreamGeneralAttestationDefinitions {
    bytes32 internal constant SCHEMA_ID = keccak256("STREAM_IDENTITY_NOTARIZATION_V1");
    bytes32 internal constant SCHEMA_HASH =
        0x11a81f69ded4ebd38a35ece1efe185e1d7c42414678b988c3064c2983ced9b2a;
    uint256 internal constant SCHEMA_BYTES = 4236;
    bytes32 internal constant PROFILE_ID =
        keccak256("STREAM_IDENTITY_NOTARIZATION_JSON_PROFILE_V1");
    bytes32 internal constant PROFILE_HASH =
        0x17c1c2815ee237ba26bc0017eaf1c8491aa640c173b9840924ec0f8fb8bdd93b;
    uint256 internal constant PROFILE_BYTES = 1488;
}
