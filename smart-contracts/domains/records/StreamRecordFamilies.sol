// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Existing family identifiers and numeric authorization-class masks from CMC-AUTHZ.
library StreamRecordFamilies {
    bytes32 internal constant ARTIST = keccak256("6529STREAM_RECORD_FAMILY_ARTIST_V1");
    bytes32 internal constant OWNER = keccak256("6529STREAM_RECORD_FAMILY_OWNER_V1");
    bytes32 internal constant INDEPENDENT = keccak256("6529STREAM_RECORD_FAMILY_INDEPENDENT_V1");
    bytes32 internal constant CURATOR = keccak256("6529STREAM_RECORD_FAMILY_CURATOR_V1");
    bytes32 internal constant INSTITUTION = keccak256("6529STREAM_RECORD_FAMILY_INSTITUTION_V1");
    bytes32 internal constant RIGHTS = keccak256("6529STREAM_RECORD_FAMILY_RIGHTS_V1");
    bytes32 internal constant ARCHIVE = keccak256("6529STREAM_RECORD_FAMILY_ARCHIVE_V1");
    bytes32 internal constant FIXITY = keccak256("6529STREAM_RECORD_FAMILY_FIXITY_V1");
    bytes32 internal constant C2PA = keccak256("6529STREAM_RECORD_FAMILY_C2PA_V1");
    bytes32 internal constant IIIF = keccak256("6529STREAM_RECORD_FAMILY_IIIF_V1");
    bytes32 internal constant MEDIA = keccak256("6529STREAM_RECORD_FAMILY_MEDIA_RELATIONSHIP_V1");
    bytes32 internal constant IDENTITY = keccak256("6529STREAM_RECORD_FAMILY_IDENTITY_DISPLAY_V1");
    bytes32 internal constant SNAPSHOT = keccak256("6529STREAM_RECORD_FAMILY_SNAPSHOT_V1");
    bytes32 internal constant AGENT = keccak256("6529STREAM_RECORD_FAMILY_AGENT_V1");

    function bit(uint8 authorizationClass) internal pure returns (uint16) {
        return uint16(1) << authorizationClass;
    }

    function allowed(bytes32 family) internal pure returns (uint16) {
        if (family == ARTIST) return bit(1);
        if (family == OWNER) return bit(2);
        if (family == INDEPENDENT) return bit(5);
        if (family == CURATOR) return bit(3) | bit(8);
        if (family == INSTITUTION) return bit(4);
        if (family == RIGHTS || family == IDENTITY || family == SNAPSHOT || family == AGENT) {
            return bit(7) | bit(8);
        }
        if (family == ARCHIVE) return bit(6) | bit(8);
        if (family == FIXITY || family == C2PA) return bit(4) | bit(6) | bit(8);
        if (family == IIIF) return bit(6) | bit(7) | bit(8);
        if (family == MEDIA) return bit(6) | bit(7);
        return 0;
    }
}
