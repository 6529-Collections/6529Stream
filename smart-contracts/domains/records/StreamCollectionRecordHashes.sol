// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/preservation/IStreamPreservationRecords.sol";
import {
    StreamArtistRecordPublicationTypes as P
} from "../../interfaces/stream/artist/StreamArtistRecordPublicationTypes.sol";

/// @notice The existing fourteen-word generic record preimage, shared by direct and detached writes.
library StreamCollectionRecordHashes {
    bytes32 internal constant RECORD_DOMAIN = keccak256("6529stream.preservation-record.v2");
    bytes32 internal constant CHAIN_DOMAIN =
        0x0e7a0feb85d4a4a3e90074703c19de35786e11afaae8f9868aa2a911bcfa1609;

    struct Preimage {
        bytes32 domain;
        uint256 chainId;
        address host;
        address core;
        address recorder;
        uint256 collectionId;
        bytes32 recordType;
        bytes32 subjectId;
        bytes32 contentHash;
        bytes32 uriHash;
        bytes32 schemaId;
        bytes32 signatureScheme;
        bytes32 signatureHash;
        uint64 effectiveAt;
    }

    function hashRef(uint16 algorithm, bytes memory digest, bytes32 canonicalizationId)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(algorithm, keccak256(digest), canonicalizationId));
    }

    function recordHash(
        address core,
        address recorder,
        uint256 collectionId,
        IStreamPreservationRecords.CollectionRecord memory record
    ) internal view returns (bytes32) {
        Preimage memory p;
        p.domain = RECORD_DOMAIN;
        p.chainId = block.chainid;
        p.host = address(this);
        p.core = core;
        p.recorder = recorder;
        p.collectionId = collectionId;
        p.recordType = record.recordType;
        p.subjectId = record.subjectId;
        p.contentHash = hashRef(
            record.contentHash.algorithm,
            record.contentHash.digest,
            record.contentHash.canonicalizationId
        );
        p.uriHash = keccak256(bytes(record.uri));
        p.schemaId = record.schemaId;
        p.signatureScheme = record.signatureScheme;
        p.signatureHash = hashRef(
            record.signatureHash.algorithm,
            record.signatureHash.digest,
            record.signatureHash.canonicalizationId
        );
        p.effectiveAt = record.effectiveAt;
        return keccak256(abi.encode(p));
    }

    function publicationHash(address core, P.Publication memory publication)
        internal
        view
        returns (bytes32)
    {
        Preimage memory p;
        p.domain = RECORD_DOMAIN;
        p.chainId = block.chainid;
        p.host = publication.metadataHost;
        p.core = core;
        p.recorder = publication.recorder;
        p.collectionId = publication.collectionId;
        p.recordType = publication.recordType;
        p.subjectId = publication.subjectId;
        p.contentHash = hashRef(
            publication.payloadAlgorithm,
            abi.encode(publication.payloadHash),
            publication.canonicalizationId
        );
        p.uriHash = publication.uriHash;
        p.schemaId = publication.schemaId;
        p.signatureHash = hashRef(0, bytes(""), 0);
        p.effectiveAt = publication.effectiveAt;
        return keccak256(abi.encode(p));
    }

    function nextChain(
        uint256 scopeKey,
        bytes32 recordType,
        bytes32 previous,
        bytes32 hash,
        uint64 index
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                CHAIN_DOMAIN,
                block.chainid,
                address(this),
                scopeKey,
                recordType,
                previous,
                hash,
                index
            )
        );
    }
}
