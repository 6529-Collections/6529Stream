// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamPreservationRecords
} from "../../interfaces/stream/preservation/IStreamPreservationRecords.sol";
import {
    IStreamCollectionMetadataV1
} from "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    StreamArtistRecordPublicationTypes as P
} from "../../interfaces/stream/artist/StreamArtistRecordPublicationTypes.sol";
import { StreamCollectionRecordHashes } from "../records/StreamCollectionRecordHashes.sol";

import { StreamMetadataSubjects } from "./StreamMetadataSubjects.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

import { StreamRecordFamilies } from "../records/StreamRecordFamilies.sol";
import { StreamRecordDocumentReads } from "../records/StreamRecordDocumentReads.sol";

/// @notice Fixed encoding of the original Metadata publication and subject recipes.
/// @dev Delegatecall retains the Metadata host in every original candidate hash.
import { StreamMetadataRecordPayloads } from "./StreamMetadataRecordPayloads.sol";
import { StreamSnapshotManifestBytes as Bytes } from "../records/StreamSnapshotManifestBytes.sol";

library StreamMetadataPublicationEncoding {
    function requireSubject(
        address core,
        uint256 collectionId,
        bytes32 subjectId,
        uint256 savedCollectionId
    ) public view {
        bytes32 collectionSubject = StreamMetadataSubjects.scopeSubject(
            block.chainid,
            core,
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, collectionId, 0, 0)
        );
        if (subjectId != collectionSubject && savedCollectionId != collectionId) {
            revert IStreamCollectionMetadataV1.UnknownMetadataSubject(subjectId);
        }
    }

    struct CandidateContext {
        address core;
        address schema;
        bytes32 schemaHash;
        address store;
        bytes32 storeHash;
        uint256 cap;
        uint256 maximum;
    }

    function candidate(
        CandidateContext memory c,
        P.Publication memory p,
        IStreamCollectionMetadataV1.RecordPolicy memory policy
    ) public view returns (bytes32 hash, uint8 kind) {
        if (
            p.metadataHost != address(this) || p.recorder == address(0) || p.payloadAlgorithm != 1
                || p.effectiveAt == 0 || !policy.admitted
                || (policy.authorizationMask & StreamRecordFamilies.bit(1)) == 0
                || (policy.family != StreamRecordFamilies.ARTIST
                    && !(policy.family == StreamRecordFamilies.CURATOR
                        && p.recordType == keccak256("WORK_DESCRIPTION")))
        ) revert IStreamCollectionMetadataV1.InvalidMetadataRecord();
        _code(c.schema, c.schemaHash);
        _code(c.store, c.storeHash);
        StreamRecordDocumentReads.activeSchema(c.schema, p.schemaId, p.canonicalizationId, c.cap);
        _code(c.store, c.storeHash);
        bytes memory payload = StreamRecordDocumentReads.chunk(c.store, p.payloadHash, c.cap);
        if (
            payload.length == 0 || payload.length > c.maximum || keccak256(payload) != p.payloadHash
        ) revert IStreamCollectionMetadataV1.InvalidMetadataRecord();
        kind = artistSubjectKind(p.recordType, p.schemaId);
        hash = StreamCollectionRecordHashes.publicationHash(c.core, p);
        if (hash != p.candidateRecordHash) {
            revert IStreamCollectionMetadataV1.InvalidMetadataRecord();
        }
    }

    function candidatePrepared(
        mapping(bytes32 => Bytes.Manifest) storage prepared,
        CandidateContext memory c,
        P.Publication memory p,
        IStreamCollectionMetadataV1.RecordPolicy memory policy
    ) public view returns (bytes32 hash, uint8 kind) {
        if (
            p.metadataHost != address(this) || p.recorder == address(0) || p.payloadAlgorithm != 1
                || p.effectiveAt == 0 || !policy.admitted
                || (policy.authorizationMask & StreamRecordFamilies.bit(1)) == 0
                || (policy.family != StreamRecordFamilies.ARTIST
                    && !(policy.family == StreamRecordFamilies.CURATOR
                        && p.recordType == keccak256("WORK_DESCRIPTION")))
        ) revert IStreamCollectionMetadataV1.InvalidMetadataRecord();
        _code(c.schema, c.schemaHash);
        _code(c.store, c.storeHash);
        StreamRecordDocumentReads.activeSchema(c.schema, p.schemaId, p.canonicalizationId, c.cap);
        _code(c.store, c.storeHash);
        bytes memory payload =
            StreamMetadataRecordPayloads.candidateBytes(prepared, c.store, p.payloadHash, c.cap);
        if (
            payload.length == 0 || payload.length > c.maximum || keccak256(payload) != p.payloadHash
        ) revert IStreamCollectionMetadataV1.InvalidMetadataRecord();
        kind = artistSubjectKind(p.recordType, p.schemaId);
        hash = StreamCollectionRecordHashes.publicationHash(c.core, p);
        if (hash != p.candidateRecordHash) {
            revert IStreamCollectionMetadataV1.InvalidMetadataRecord();
        }
    }

    function _code(address target, bytes32 expected) private view {
        if (target.code.length == 0 || target.codehash != expected) {
            revert IStreamCollectionMetadataV1.MetadataDependencyChanged(target);
        }
    }

    function publication(
        address core,
        address recorder,
        uint256 collectionId,
        IStreamPreservationRecords.CollectionRecord calldata record
    ) public view returns (P.Publication memory p) {
        p.metadataHost = address(this);
        p.recorder = recorder;
        p.collectionId = collectionId;
        p.subjectId = record.subjectId;
        p.recordType = record.recordType;
        p.schemaId = record.schemaId;
        p.canonicalizationId = record.contentHash.canonicalizationId;
        p.payloadAlgorithm = record.contentHash.algorithm;
        p.payloadHash = bytes32(record.contentHash.digest);
        p.uriHash = keccak256(bytes(record.uri));
        p.effectiveAt = record.effectiveAt;
        p.candidateRecordHash =
            StreamCollectionRecordHashes.recordHash(core, recorder, collectionId, record);
    }

    function artistSubjectKind(bytes32 recordType, bytes32 schemaId) public pure returns (uint8) {
        if (
            (recordType == keccak256("ARTIST_INTENT")
                    && schemaId == keccak256("STREAM_ARTIST_INTENT_V1"))
                || (recordType == keccak256("ARTIST_INTENT_WAIVER")
                    && schemaId == keccak256("STREAM_ARTIST_INTENT_WAIVER_V1"))
        ) return 7;
        if (
            (recordType == keccak256("ARTIST_STATEMENT")
                    && (schemaId == keccak256("STREAM_ARTIST_INTERVIEW_V1")
                        || schemaId == keccak256("STREAM_ARTIST_STATEMENT_V1")))
                || (recordType == keccak256("ARTIST_SEMANTIC_ASSERTION")
                    && schemaId == keccak256("STREAM_SEMANTIC_ASSERTION_V1"))
                || (recordType == keccak256("WORK_DESCRIPTION")
                    && schemaId == keccak256("STREAM_WORK_DESCRIPTION_V1"))
        ) return 8;
        revert IStreamCollectionMetadataV1.InvalidMetadataRecord();
    }
}
