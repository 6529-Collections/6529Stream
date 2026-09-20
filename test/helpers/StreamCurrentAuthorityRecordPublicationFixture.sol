// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityDeferredScopedPolicyAssemblyFixture
} from "./StreamCurrentAuthorityDeferredScopedPolicyAssemblyFixture.sol";
import {
    StreamArtistOnboardingTypes as PublicationArtist
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecordPublicationTypes as PublicationTypes
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistRecordPublicationTypes.sol";
import {
    StreamArtistRecordPublicationRules as PublicationRules
} from "../../smart-contracts/domains/artist/StreamArtistRecordPublicationRules.sol";
import {
    IStreamArtistRecordPublicationOwner as PublicationOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistRecordPublicationOwner.sol";
import {
    IStreamPreservationRecords as PublicationRecords
} from "../../smart-contracts/interfaces/stream/preservation/IStreamPreservationRecords.sol";
import {
    IStreamCollectionMetadataV1 as PublicationMetadata
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";

/// @notice Scope-aware actual op24 publication through the currently selected original/successor.
/// @dev Callers must first admit the canonical subject and record policy. This helper grants no
/// authority, substitutes no owner state, and retains the actual signed witness for later import.
abstract contract StreamCurrentAuthorityRecordPublicationFixture is
    StreamCurrentAuthorityDeferredScopedPolicyAssemblyFixture
{
    struct ActualPublication {
        bytes32 recordHash;
        bytes32 authorizationHash;
        uint256 nonce;
        PublicationArtist.Attestation attestation;
        PublicationTypes.Publication publication;
        PublicationTypes.Evidence evidence;
        PublicationMetadata.RecordReceipt receipt;
    }

    function _publishCurrentAuthorityRecord(
        PublicationRecords.CollectionRecord memory record,
        bytes memory raw
    ) internal returns (ActualPublication memory result) {
        require(record.subjectId != 0 && record.contentHash.algorithm == 1);
        require(
            record.contentHash.digest.length == 32
                && keccak256(record.contentHash.digest) == keccak256(abi.encode(keccak256(raw))),
            "exact scoped canonical payload"
        );
        require(
            assemblyMetadata.prepareRecordPayload(raw) == keccak256(raw),
            "actual complete payload preparation precedes op24 candidate validation"
        );
        (, uint64 beforeCount) = assemblyMetadata.recordChainHash(1, record.recordType);
        PublicationTypes.Publication memory publication;
        publication.metadataHost = address(assemblyMetadata);
        publication.recorder = address(assemblyArtist);
        publication.collectionId = 1;
        publication.subjectId = record.subjectId;
        publication.recordType = record.recordType;
        publication.schemaId = record.schemaId;
        publication.canonicalizationId = record.contentHash.canonicalizationId;
        publication.payloadAlgorithm = 1;
        publication.payloadHash = keccak256(raw);
        publication.uriHash = keccak256(bytes(record.uri));
        publication.effectiveAt = record.effectiveAt;
        publication.candidateRecordHash =
            assemblyMetadata.deriveCollectionRecordHashFor(address(assemblyArtist), 1, record);
        (uint8 subjectKind, uint32 capability) =
            PublicationRules.family(record.recordType, record.schemaId);
        require(subjectKind == 7 || subjectKind == 8, "explicit supported op24 family");
        bytes memory statement = abi.encode(uint16(1), publication);
        require(statement.length == 416, "unchanged canonical publication envelope");
        PublicationArtist.Attestation memory attestation = PublicationArtist.Attestation(
            1,
            subjectKind,
            record.subjectId,
            subjectKind == 7 ? publication.candidateRecordHash : bytes32(0),
            keccak256("6529STREAM_ARTIST_RECORD_PUBLICATION_V1"),
            keccak256(statement),
            record.uri
        );
        PublicationArtist.Authorization memory authorization = _assemblyAuthorization(true);
        authorization.signature = _assemblyArtistProof(
            assemblyArtists.attestationDigest(attestation, authorization), authorization.nonce
        );
        bytes32 recordAuthorization =
            assemblyArtists.recordArtistAttestation(attestation, authorization, statement);
        _authorityAttestation(attestation, authorization.nonce, recordAuthorization);
        PublicationTypes.Evidence memory evidence =
            assemblyArtists.requireRecordPublication(recordAuthorization, publication);
        require(
            evidence.attestationRecordHash == recordAuthorization
                && evidence.artistId == assemblyArtistId
                && evidence.signer == address(assemblyArtist) && evidence.authorityClass == 1
                && evidence.requiredCapability == capability
                && evidence.signedAt == authorization.time
                && evidence.publicationHash == keccak256(abi.encode(publication)),
            "actual selected Artist Safe op24 evidence"
        );
        PublicationOwner.Record memory saved =
            PublicationOwner(assemblySuite.owners[4]).publicationAttestation(recordAuthorization);
        require(
            keccak256(abi.encode(saved.publication)) == keccak256(abi.encode(publication))
                && keccak256(abi.encode(saved.evidence)) == keccak256(abi.encode(evidence))
                && saved.metadataHostCodeHash == address(assemblyMetadata).codehash,
            "actual current owner's retained publication"
        );
        bytes32 recordHash = assemblyMetadata.recordArtistCollectionRecordWithPayload(
            address(assemblyArtist), 1, record, raw, recordAuthorization
        );
        (
            PublicationRecords.CollectionRecord memory savedRecord,
            PublicationMetadata.RecordReceipt memory receipt
        ) = assemblyMetadata.collectionRecord(recordHash);
        (bytes32 chainAfter, uint64 countAfter) =
            assemblyMetadata.recordChainHash(1, record.recordType);
        require(
            recordHash == publication.candidateRecordHash
                && keccak256(abi.encode(savedRecord)) == keccak256(abi.encode(record))
                && receipt.collectionId == 1 && receipt.recorder == address(assemblyArtist)
                && receipt.authorizationClass == 1
                && receipt.artistAuthorization == recordAuthorization
                && receipt.recordIndex == beforeCount && countAfter == beforeCount + 1
                && receipt.recordChainHash == chainAfter && chainAfter != 0
                && assemblyMetadata.recordHashAt(1, record.recordType, beforeCount) == recordHash
                && assemblyMetadata.latestCollectionRecordHashFor(
                    1, record.recordType, record.subjectId, address(assemblyArtist)
                ) == recordHash
                && assemblyMetadata.consumedArtistAuthorization(recordAuthorization),
            "exact scoped record and nonzero history-index backlink"
        );
        (, bytes memory storedPayload) = assemblyMetadata.recordPayload(recordHash);
        require(keccak256(storedPayload) == keccak256(raw), "retained full scoped payload");
        result = ActualPublication(
            recordHash,
            recordAuthorization,
            authorization.nonce,
            attestation,
            publication,
            evidence,
            receipt
        );
    }
}
