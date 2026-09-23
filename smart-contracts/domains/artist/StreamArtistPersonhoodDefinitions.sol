// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Additive interpretation of the existing evidence schema; no old definition is replaced.
library StreamArtistPersonhoodDefinitions {
    bytes32 internal constant EVIDENCE_SCHEMA =
        keccak256("6529STREAM_ARTIST_PERSONHOOD_EVIDENCE_V1");
    bytes32 internal constant WAIVER_SCHEMA = keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1");
    bytes32 internal constant PROFILE_ID =
        keccak256("STREAM_ARTIST_PERSONHOOD_REFERENCE_JSON_PROFILE_V1");
    bytes32 internal constant PROFILE_HASH =
        0x06eaf449a0abe6a4305706d589bc597f14f7d23f62acc661b4b1fff128b921c3;
    uint256 internal constant PROFILE_BYTES = 1837;
}
