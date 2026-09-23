// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamConservationRecordContext.sol";
import "./StreamMediaMasterDefinitions.sol";
import "../../interfaces/stream/metadata/StreamMediaMasterTypes.sol";
import "./StreamCollectionRecordHashes.sol";
import "./StreamRecordFamilies.sol";
import "./StreamRecordArtistIdentityReads.sol";
import "../../interfaces/stream/metadata/IStreamConservationRecordSelection.sol";
import "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import "../../interfaces/stream/metadata/IStreamCollectionRecordReceipts.sol";
import "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistRecordPublicationOwner.sol";
import "../metadata/StreamSchemaDocumentStore.sol";

/// @notice Original MEDIA class6/7 association or original Artist op24 master-waiver publication.
/// @dev No current signer is substituted for the stored original author/class. The fixed consumer
/// supplies its immutable dependency graph; all caller record fields remain untrusted witnesses.
library StreamMediaMasterPublicationReads {
    bytes32 internal constant MASTER_TYPE = keccak256("MEDIA_RELATIONSHIP");
    bytes32 internal constant WAIVER_TYPE = keccak256("ARTIST_STATEMENT");
    bytes32 private constant PUBLICATION_SCHEMA =
        keccak256("6529STREAM_ARTIST_RECORD_PUBLICATION_V1");

    function recorded(
        StreamConservationRecordContext.Dependencies memory d,
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 recordHash,
        IStreamPreservationRecords.CollectionRecord memory record,
        bool isWaiver
    ) public view returns (StreamMediaMasterTypes.RecordEvidence memory e) {
        (bytes32 recordType, bytes32 schemaId, bytes32 schemaHash) = definition(isWaiver);
        IStreamCollectionMetadataV1.RecordReceipt memory receipt = _receipt(d, recordHash);
        IStreamCollectionMetadataV1.RecordPolicy memory policy = _policy(d, recordType);
        if (
            collectionId == 0 || subjectId == 0 || recordHash == 0
                || receipt.collectionId != collectionId || receipt.recorder == address(0)
                || (isWaiver ? receipt.authorizationClass != 1
                    : (receipt.authorizationClass != 6 && receipt.authorizationClass != 7))
                || (policy.authorizationMask & StreamRecordFamilies.bit(receipt.authorizationClass)) == 0
                || (!isWaiver && receipt.artistAuthorization != 0)
                || receipt.recordedAt == 0 || receipt.schemaDefinitionHash != schemaHash
                || receipt.canonicalizationDefinitionHash != StreamWorkRecordDefinitions.CANON_HASH
                || record.recordType != recordType || record.subjectId != subjectId
                || record.schemaId != schemaId || record.contentHash.algorithm != 1
                || record.contentHash.digest.length != 32
                || record.contentHash.canonicalizationId != StreamWorkRecordDefinitions.CANON_ID
                || record.signatureScheme != 0 || record.signatureHash.algorithm != 0
                || record.signatureHash.digest.length != 0
                || record.signatureHash.canonicalizationId != 0 || record.effectiveAt == 0
                || _recordHash(d, collectionId, receipt.recorder, record) != recordHash
        ) revert IStreamConservationRecordSelection.InvalidConservationRecord(recordHash);
        _history(d, recordHash, receipt, recordType);
        e.recordHash = recordHash;
        e.authorizationClass = receipt.authorizationClass;
        e.payloadHash = bytes32(record.contentHash.digest);
        e.recorder = receipt.recorder;
        e.recordedAt = receipt.recordedAt;
        e.recordIndex = receipt.recordIndex;
        e.recordChainHash = receipt.recordChainHash;
        e.receiptHash = keccak256(abi.encode(receipt));
        if (isWaiver) {
            (e.publication, e.publicationEvidenceHash) =
                _artistPublication(d, receipt, record, recordHash);
        }
    }

    function definition(bool isWaiver)
        public
        pure
        returns (bytes32 recordType, bytes32 schemaId, bytes32 schemaHash)
    {
        return isWaiver
            ? (WAIVER_TYPE, StreamMediaMasterDefinitions.WAIVER_SCHEMA_ID,
                StreamMediaMasterDefinitions.WAIVER_SCHEMA_HASH)
            : (MASTER_TYPE, StreamMediaMasterDefinitions.MASTER_SCHEMA_ID,
                StreamMediaMasterDefinitions.MASTER_SCHEMA_HASH);
    }

    function _artistPublication(
        StreamConservationRecordContext.Dependencies memory d,
        IStreamCollectionMetadataV1.RecordReceipt memory receipt,
        IStreamPreservationRecords.CollectionRecord memory record,
        bytes32 recordHash
    ) private view returns (P.Evidence memory evidence, bytes32 evidenceHash) {
        if (receipt.artistAuthorization == 0) {
            revert IStreamConservationRecordSelection.InvalidConservationRecord(recordHash);
        }
        bytes memory raw = _fixed(
            d,
            d.targets[1],
            abi.encodeWithSignature(
                "consumedArtistAuthorization(bytes32)", receipt.artistAuthorization
            ),
            32
        );
        if (_word(raw, 0) != bytes32(uint256(1))) {
            revert IStreamConservationRecordSelection.InvalidConservationRecord(recordHash);
        }
        raw = _fixed(
            d,
            d.artists[4],
            abi.encodeCall(
                IStreamArtistRecordPublicationOwner.publicationAttestation,
                (receipt.artistAuthorization)
            ),
            704
        );
        IStreamArtistRecordPublicationOwner.Record memory saved =
            abi.decode(raw, (IStreamArtistRecordPublicationOwner.Record));
        _canonical(d.artists[4], raw, abi.encode(saved));
        evidence = saved.evidence;
        P.Publication memory p = P.Publication(
            d.targets[1],
            receipt.recorder,
            receipt.collectionId,
            record.subjectId,
            record.recordType,
            record.schemaId,
            record.contentHash.canonicalizationId,
            1,
            bytes32(record.contentHash.digest),
            keccak256(bytes(record.uri)),
            record.effectiveAt,
            recordHash
        );
        if (
            saved.metadataHostCodeHash != d.codeHashes[1]
                || keccak256(abi.encode(saved.publication)) != keccak256(abi.encode(p))
                || evidence.attestationRecordHash != receipt.artistAuthorization
                || evidence.artistId == 0 || evidence.bindingHash == 0
                || evidence.bindingGeneration == 0 || evidence.signer != receipt.recorder
                || evidence.authorityClass != 1
                || evidence.requiredCapability != 1
                || evidence.signedAt == 0 || evidence.signedAt > receipt.recordedAt
                || evidence.publicationHash != keccak256(abi.encode(p))
        ) revert IStreamConservationRecordSelection.InvalidConservationRecord(recordHash);
        _attestation(d, evidence, p, recordHash);
        return (evidence, keccak256(abi.encode(saved)));
    }

    function _attestation(
        StreamConservationRecordContext.Dependencies memory d,
        P.Evidence memory evidence,
        P.Publication memory p,
        bytes32 recordHash
    ) private view {
        bytes memory raw = _fixed(
            d,
            d.artists[4],
            abi.encodeCall(
                IStreamArtistAttributionOwner.attestationRecord, (evidence.attestationRecordHash)
            ),
            224
        );
        T.AttestationRecord memory record = abi.decode(raw, (T.AttestationRecord));
        _canonical(d.artists[4], raw, abi.encode(record));
        bytes memory statement = abi.encode(uint16(1), p);
        if (
            record.recordHash != evidence.attestationRecordHash
                || record.subjectStateHash != bytes32(0)
                || record.schemaId != PUBLICATION_SCHEMA
                || record.statementHash != keccak256(statement)
                || record.generation != evidence.bindingGeneration
                || record.signedAt != evidence.signedAt || record.signer != evidence.signer
        ) revert IStreamConservationRecordSelection.InvalidConservationRecord(recordHash);
        raw = _read(
            d,
            d.artists[4],
            abi.encodeCall(IStreamArtistAttributionOwner.statementBytes, (record.statementHash)),
            480
        );
        bytes memory saved = abi.decode(raw, (bytes));
        _canonical(d.artists[4], raw, abi.encode(saved));
        if (saved.length != 416 || keccak256(saved) != keccak256(statement)) {
            revert IStreamConservationRecordSelection.InvalidConservationRecord(recordHash);
        }
    }

    function _policy(StreamConservationRecordContext.Dependencies memory d, bytes32 recordType)
        private
        view
        returns (IStreamCollectionMetadataV1.RecordPolicy memory policy)
    {
        bytes memory raw = _fixed(
            d,
            d.targets[1],
            abi.encodeCall(IStreamCollectionMetadataV1.recordPolicy, (recordType)),
            96
        );
        policy = abi.decode(raw, (IStreamCollectionMetadataV1.RecordPolicy));
        _canonical(d.targets[1], raw, abi.encode(policy));
        if (!policy.admitted || policy.family != (recordType == WAIVER_TYPE
            ? StreamRecordFamilies.ARTIST : StreamRecordFamilies.MEDIA)) {
            revert IStreamConservationRecordSelection.ConservationSelectionAuthorityRequired();
        }
    }

    function _receipt(StreamConservationRecordContext.Dependencies memory d, bytes32 hash)
        private
        view
        returns (IStreamCollectionMetadataV1.RecordReceipt memory receipt)
    {
        bytes memory raw = _fixed(
            d,
            d.targets[1],
            abi.encodeCall(IStreamCollectionRecordReceipts.collectionRecordReceipt, (hash)),
            288
        );
        receipt = abi.decode(raw, (IStreamCollectionMetadataV1.RecordReceipt));
        _canonical(d.targets[1], raw, abi.encode(receipt));
    }

    function _history(
        StreamConservationRecordContext.Dependencies memory d,
        bytes32 recordHash,
        IStreamCollectionMetadataV1.RecordReceipt memory receipt,
        bytes32 recordType
    ) private view {
        bytes memory raw = _fixed(
            d,
            d.targets[1],
            abi.encodeCall(
                IStreamCollectionMetadataV1.recordHashAt,
                (receipt.collectionId, recordType, receipt.recordIndex)
            ),
            32
        );
        if (_word(raw, 0) != recordHash) {
            revert IStreamConservationRecordSelection.InvalidConservationRecord(recordHash);
        }
        bytes32 previous;
        if (receipt.recordIndex != 0) {
            raw = _fixed(
                d,
                d.targets[1],
                abi.encodeCall(
                    IStreamCollectionMetadataV1.recordHashAt,
                    (receipt.collectionId, recordType, receipt.recordIndex - 1)
                ),
                32
            );
            IStreamCollectionMetadataV1.RecordReceipt memory prior = _receipt(d, _word(raw, 0));
            if (
                prior.collectionId != receipt.collectionId
                    || prior.recordIndex + 1 != receipt.recordIndex
            ) revert IStreamConservationRecordSelection.InvalidConservationRecord(recordHash);
            previous = prior.recordChainHash;
        }
        bytes32 expected = keccak256(
            abi.encode(
                StreamCollectionRecordHashes.CHAIN_DOMAIN,
                d.chainId,
                d.targets[1],
                receipt.collectionId,
                recordType,
                previous,
                recordHash,
                receipt.recordIndex
            )
        );
        if (receipt.recordChainHash != expected) {
            revert IStreamConservationRecordSelection.InvalidConservationRecord(recordHash);
        }
    }

    function payload(
        StreamConservationRecordContext.Dependencies memory d,
        bytes32 recordHash,
        bytes32 payloadHash
    ) public view returns (bytes memory original) {
        bytes memory raw = _fixed(
            d, d.targets[3], abi.encodeWithSignature("chunk(bytes32)", payloadHash), 64
        );
        (address ptr, uint32 size) = abi.decode(raw, (address, uint32));
        _canonical(d.targets[3], raw, abi.encode(ptr, size));
        original = _chunk(d, payloadHash);
        if (
            ptr == address(0) || original.length != size || original.length == 0
                || keccak256(original) != payloadHash
        ) revert IStreamConservationRecordSelection.InvalidConservationRecord(recordHash);
    }

    function _recordHash(
        StreamConservationRecordContext.Dependencies memory d,
        uint256 collectionId,
        address recorder,
        IStreamPreservationRecords.CollectionRecord memory record
    ) private pure returns (bytes32) {
        StreamCollectionRecordHashes.Preimage memory p;
        p.domain = keccak256("6529stream.preservation-record.v2");
        p.chainId = d.chainId;
        p.host = d.targets[1];
        p.core = d.targets[0];
        p.recorder = recorder;
        p.collectionId = collectionId;
        p.recordType = record.recordType;
        p.subjectId = record.subjectId;
        p.contentHash = StreamCollectionRecordHashes.hashRef(
            record.contentHash.algorithm,
            record.contentHash.digest,
            record.contentHash.canonicalizationId
        );
        p.uriHash = keccak256(bytes(record.uri));
        p.schemaId = record.schemaId;
        p.signatureScheme = record.signatureScheme;
        p.signatureHash = StreamCollectionRecordHashes.hashRef(
            record.signatureHash.algorithm,
            record.signatureHash.digest,
            record.signatureHash.canonicalizationId
        );
        p.effectiveAt = record.effectiveAt;
        return keccak256(abi.encode(p));
    }

    function _chunk(StreamConservationRecordContext.Dependencies memory d, bytes32 hash)
        private
        view
        returns (bytes memory chunk)
    {
        bytes memory raw = _read(
            d, d.targets[3], abi.encodeCall(StreamSchemaDocumentStore.readChunk, (hash)), 8256
        );
        chunk = abi.decode(raw, (bytes));
        _canonical(d.targets[3], raw, abi.encode(chunk));
        if (keccak256(chunk) != hash) {
            revert IStreamConservationRecordSelection.ConservationDependencyReadFailed(d.targets[3]);
        }
    }

    function _word(bytes memory raw, uint256 index) private pure returns (bytes32 word) {
        assembly ("memory-safe") { word := mload(add(add(raw, 32), mul(index, 32))) }
    }

    function _canonical(address target, bytes memory raw, bytes memory encoded) private pure {
        if (raw.length != encoded.length || keccak256(raw) != keccak256(encoded)) {
            revert IStreamConservationRecordSelection.ConservationDependencyReadFailed(target);
        }
    }

    function _fixed(
        StreamConservationRecordContext.Dependencies memory d,
        address target,
        bytes memory input,
        uint256 size
    ) private view returns (bytes memory raw) {
        raw = _read(d, target, input, size);
        if (raw.length != size) {
            revert IStreamConservationRecordSelection.ConservationDependencyReadFailed(target);
        }
    }

    function _read(
        StreamConservationRecordContext.Dependencies memory d,
        address target,
        bytes memory input,
        uint256 maximum
    ) private view returns (bytes memory raw) {
        uint256 cap = d.readGas;
        raw = new bytes(maximum);
        if (cap == 0 || cap > type(uint64).max || gasleft() <= cap + cap / 63 + 10000) {
            revert IStreamConservationRecordSelection.ConservationDependencyReadFailed(target);
        }
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(raw, 32), maximum)
            size := returndatasize()
        }
        if (!ok || size > maximum) {
            revert IStreamConservationRecordSelection.ConservationDependencyReadFailed(target);
        }
        assembly ("memory-safe") { mstore(raw, size) }
    }
}
