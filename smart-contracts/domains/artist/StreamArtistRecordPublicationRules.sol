// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/artist/StreamArtistRecordPublicationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Exact canonical publication-envelope profile inside the unchanged op24 statement payload.
library StreamArtistRecordPublicationRules {
    bytes32 internal constant SCHEMA = keccak256("6529STREAM_ARTIST_RECORD_PUBLICATION_V1");

    function decode(T.Attestation memory p, bytes memory statement)
        public
        pure
        returns (
            StreamArtistRecordPublicationTypes.Publication memory publication,
            uint32 capability
        )
    {
        if (
            statement.length != 416 || p.schemaId != SCHEMA
                || keccak256(statement) != p.statementHash
        ) {
            revert T.InvalidRecord();
        }
        uint16 version;
        (version, publication) =
            abi.decode(statement, (uint16, StreamArtistRecordPublicationTypes.Publication));
        if (
            version != 1 || keccak256(abi.encode(version, publication)) != p.statementHash
                || publication.metadataHost == address(0) || publication.recorder == address(0)
                || publication.collectionId == 0 || publication.collectionId != p.collectionId
                || publication.subjectId == 0 || publication.subjectId != p.subjectId
                || publication.schemaId == 0 || publication.canonicalizationId == 0
                || publication.payloadAlgorithm != 1 || publication.payloadHash == 0
                || publication.candidateRecordHash == 0
                || publication.uriHash != keccak256(bytes(p.statementURI))
        ) revert T.InvalidRecord();
        uint8 kind;
        (kind, capability) = family(publication.recordType, publication.schemaId);
        if (
            p.subjectKind != kind
                || p.subjectStateHash != (kind == 7 ? publication.candidateRecordHash : bytes32(0))
        ) {
            revert T.InvalidRecord();
        }
    }

    /// @dev Metadata independently verifies the actual registered family/schema and canonical bytes.
    function family(bytes32 recordType, bytes32 schemaId)
        public
        pure
        returns (uint8 kind, uint32 capability)
    {
        if (
            recordType == keccak256("ARTIST_INTENT")
                && schemaId == keccak256("STREAM_ARTIST_INTENT_V1")
        ) {
            return (7, 64);
        }
        if (
            recordType == keccak256("ARTIST_INTENT_WAIVER")
                && schemaId == keccak256("STREAM_ARTIST_INTENT_WAIVER_V1")
        ) {
            return (7, 64);
        }
        if (
            recordType == keccak256("ARTIST_SEMANTIC_ASSERTION")
                && schemaId == keccak256("STREAM_SEMANTIC_ASSERTION_V1")
        ) return (8, 1);
        if (
            recordType == keccak256("WORK_DESCRIPTION")
                && schemaId == keccak256("STREAM_WORK_DESCRIPTION_V1")
        ) return (8, 1);
        if (
            recordType == keccak256("ARTIST_STATEMENT") && schemaId != 0
                && schemaId != keccak256("STREAM_ARTIST_INTENT_V1")
                && schemaId != keccak256("STREAM_ARTIST_INTENT_WAIVER_V1")
        ) return (8, 1);
        revert T.UnsupportedProfile();
    }
}
