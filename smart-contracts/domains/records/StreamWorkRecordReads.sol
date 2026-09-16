// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamWorkRecordContext.sol";
import "./StreamWorkRecordJson.sol";
import "./StreamCollectionRecordHashes.sol";
import "./StreamRecordFamilies.sol";
import "./StreamRecordArtistIdentityReads.sol";
import "../../interfaces/stream/metadata/IStreamWorkRecordSelection.sol";
import "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import "../../interfaces/stream/metadata/IStreamCollectionRecordReceipts.sol";
import "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistRecordPublicationOwner.sol";
import "../metadata/StreamSchemaDocumentStore.sol";

/// @notice Complete WORK bytes, registered definitions and original publication evidence.
/// @dev Dependencies are supplied only by an immutable-bound consumer. Witnesses confer no authority.
library StreamWorkRecordReads {
    bytes32 internal constant RECORD_TYPE = keccak256("WORK_DESCRIPTION");
    bytes32 private constant PUBLICATION_SCHEMA =
        keccak256("6529STREAM_ARTIST_RECORD_PUBLICATION_V1");

    function curatorAuthority(
        StreamWorkRecordContext.Dependencies memory d,
        uint256 collectionId,
        address caller
    ) public view returns (uint8 authClass, uint256 grantScope, uint64 revision) {
        IStreamCollectionMetadataV1.RecordPolicy memory policy = _policy(d);
        uint8[2] memory classes = [uint8(3), uint8(8)];
        for (uint256 c; c < 2; ++c) {
            if ((policy.authorizationMask & StreamRecordFamilies.bit(classes[c])) == 0) continue;
            for (uint256 i; i < 2; ++i) {
                uint256 scope = i == 0 ? collectionId : 0;
                bytes memory raw = _fixed(
                    d,
                    d.targets[1],
                    abi.encodeCall(
                        IStreamCollectionMetadataV1.familyWriter,
                        (scope, StreamRecordFamilies.CURATOR, classes[c], caller)
                    ),
                    64
                );
                (bool enabled, uint64 rev) = abi.decode(raw, (bool, uint64));
                _canonical(d.targets[1], raw, abi.encode(enabled, rev));
                if (enabled && rev != 0) return (classes[c], scope, rev);
            }
        }
        revert IStreamWorkRecordSelection.WorkSelectionAuthorityRequired();
    }

    function recorded(
        StreamWorkRecordContext.Dependencies memory d,
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 recordHash,
        IStreamWorkRecordSelection.Witness memory supplied
    ) public view returns (IStreamWorkRecordSelection.Selection memory selected) {
        IStreamPreservationRecords.CollectionRecord memory record = supplied.original;
        StreamWorkRecordTypes.Description memory witness = supplied.description;
        IStreamCollectionMetadataV1.RecordReceipt memory receipt = _receipt(d, recordHash);
        IStreamCollectionMetadataV1.RecordPolicy memory policy = _policy(d);
        if (
            collectionId == 0 || subjectId == 0 || recordHash == 0
                || receipt.collectionId != collectionId || receipt.recorder == address(0)
                || (receipt.authorizationClass != 1
                    && receipt.authorizationClass != 3
                    && receipt.authorizationClass != 8)
                || (policy.authorizationMask & StreamRecordFamilies.bit(receipt.authorizationClass))
                    == 0 || receipt.recordedAt == 0
                || receipt.schemaDefinitionHash != StreamWorkRecordDefinitions.SCHEMA_HASH
                || receipt.canonicalizationDefinitionHash != StreamWorkRecordDefinitions.CANON_HASH
                || record.recordType != RECORD_TYPE || record.subjectId != subjectId
                || record.schemaId != StreamWorkRecordDefinitions.SCHEMA_ID
                || record.contentHash.algorithm != 1 || record.contentHash.digest.length != 32
                || record.contentHash.canonicalizationId != StreamWorkRecordDefinitions.CANON_ID
                || record.signatureScheme != 0 || record.signatureHash.algorithm != 0
                || record.signatureHash.digest.length != 0
                || record.signatureHash.canonicalizationId != 0 || record.effectiveAt == 0
                || witness.subjectId != subjectId
                || witness.profileHash != StreamWorkRecordDefinitions.PROFILE_HASH
                || _recordHash(d, collectionId, receipt.recorder, record) != recordHash
        ) revert IStreamWorkRecordSelection.InvalidWorkRecord(recordHash);
        _history(d, recordHash, receipt);
        selected.payloadHash = bytes32(record.contentHash.digest);
        StreamWorkRecordJson.requireExact(witness, _payload(d, recordHash, selected.payloadHash));
        selected.recordHash = recordHash;
        selected.predecessor = witness.predecessor;
        selected.recordIndex = receipt.recordIndex;
        selected.recordChainHash = receipt.recordChainHash;
        selected.recorder = receipt.recorder;
        selected.recorderAuthorizationClass = receipt.authorizationClass;
        selected.form = witness.form;
        if (witness.form == StreamWorkRecordTypes.Form.FULL) {
            selected.creatorKind = witness.full.creator.kind;
            selected.creatorAssociation = association(d, collectionId);
            StreamWorkRecordTypes.Creator memory creator = witness.full.creator;
            if (creator.kind == StreamWorkRecordTypes.CreatorKind.ARTIST) {
                if (
                    creator.artistId == 0
                        || creator.artistId != selected.creatorAssociation.artistId
                        || creator.bindingHash != selected.creatorAssociation.bindingHash
                        || creator.bindingGeneration != selected.creatorAssociation.generation
                ) revert IStreamWorkRecordSelection.WorkAssociationChanged();
            } else if (selected.creatorAssociation.artistId != 0) {
                revert IStreamWorkRecordSelection.WorkAssociationChanged();
            }
            if (witness.full.format.kind == StreamWorkRecordTypes.FormatKind.CATALOG) {
                bytes memory catalog =
                    StreamWorkFormatJson.catalogDocument(witness.full.format.catalog);
                selected.catalogId = keccak256(bytes(witness.full.format.catalog.name));
                selected.catalogHash = keccak256(catalog);
                bytes memory original = StreamWorkRecordContext.definition(
                    d,
                    selected.catalogId,
                    IStreamSchemaRegistry.DocumentKind.CATALOG,
                    selected.catalogHash,
                    catalog.length,
                    StreamWorkRecordDefinitions.CANON_ID,
                    false
                );
                StreamRecordJson.requirePayload(catalog, original);
            }
        }
        if (receipt.authorizationClass == 1) {
            (selected.artistPublication, selected.artistPublicationEvidenceHash) =
                _artistPublication(d, receipt, record, recordHash);
            IStreamWorkRecordSelection.Association memory current = association(d, collectionId);
            if (
                current.artistId != selected.artistPublication.artistId
                    || current.bindingHash != selected.artistPublication.bindingHash
                    || current.generation != selected.artistPublication.bindingGeneration
            ) revert IStreamWorkRecordSelection.WorkAssociationChanged();
        } else if (receipt.artistAuthorization != 0) {
            revert IStreamWorkRecordSelection.InvalidWorkRecord(recordHash);
        }
    }

    function requireSelectedAssociation(
        StreamWorkRecordContext.Dependencies memory d,
        uint256 collectionId,
        IStreamWorkRecordSelection.Selection memory selected
    ) public view {
        if (
            selected.form == StreamWorkRecordTypes.Form.FULL
                || selected.recorderAuthorizationClass == 1
        ) {
            IStreamWorkRecordSelection.Association memory current = association(d, collectionId);
            if (
                selected.form == StreamWorkRecordTypes.Form.FULL
                    && keccak256(abi.encode(current))
                        != keccak256(abi.encode(selected.creatorAssociation))
            ) revert IStreamWorkRecordSelection.WorkAssociationChanged();
            if (
                selected.recorderAuthorizationClass == 1
                    && (current.artistId != selected.artistPublication.artistId
                        || current.bindingHash != selected.artistPublication.bindingHash
                        || current.generation != selected.artistPublication.bindingGeneration)
            ) revert IStreamWorkRecordSelection.WorkAssociationChanged();
        }
        if (selected.catalogId != 0) {
            // Its exact immutable declaration/hash is retained; byte length comes from the pinned registry.
            IStreamSchemaDocumentFacts.DocumentFacts memory row =
                StreamWorkRecordContext.document(d, selected.catalogId);
            StreamWorkRecordContext.definition(
                d,
                selected.catalogId,
                IStreamSchemaRegistry.DocumentKind.CATALOG,
                selected.catalogHash,
                row.totalBytes,
                StreamWorkRecordDefinitions.CANON_ID,
                false
            );
        }
    }

    function association(StreamWorkRecordContext.Dependencies memory d, uint256 collectionId)
        public
        view
        returns (IStreamWorkRecordSelection.Association memory a)
    {
        bytes memory raw = _fixed(
            d, d.artists[3], abi.encodeCall(IStreamArtistBindingOwner.binding, (collectionId)), 320
        );
        T.Binding memory b = abi.decode(raw, (T.Binding));
        _canonical(d.artists[3], raw, abi.encode(b));
        if (b.artistId == 0) {
            T.Binding memory empty;
            if (keccak256(raw) != keccak256(abi.encode(empty))) {
                revert IStreamWorkRecordSelection.WorkAssociationChanged();
            }
            return a;
        }
        raw = _fixed(
            d,
            d.artists[4],
            abi.encodeCall(IStreamArtistAttributionOwner.attributionState, (collectionId)),
            64
        );
        (uint8 status, uint64 generation) = abi.decode(raw, (uint8, uint64));
        _canonical(d.artists[4], raw, abi.encode(status, generation));
        if (
            !b.accepted || (status != 2 && status != 3) || b.bindingHash == 0 || b.generation == 0
                || b.generation != generation || b.identityRecordHash == 0
                || b.artistAddress == address(0)
        ) revert IStreamWorkRecordSelection.WorkAssociationChanged();
        StreamRecordArtistIdentityReads.Pins memory pins;
        for (uint256 i; i < 3; ++i) {
            pins.targets[i] = d.artists[i];
            pins.codeHashes[i] = d.artistCodeHashes[i];
        }
        bytes32 identity = StreamRecordArtistIdentityReads.knownIdentity(
            d.targets[1], d.targets[0], d.chainId, pins, b.artistId, d.readGas
        );
        if (identity != b.identityRecordHash) {
            revert IStreamWorkRecordSelection.WorkAssociationChanged();
        }
        return
            IStreamWorkRecordSelection.Association(
                b.artistId, b.bindingHash, b.generation, identity
            );
    }

    function _artistPublication(
        StreamWorkRecordContext.Dependencies memory d,
        IStreamCollectionMetadataV1.RecordReceipt memory receipt,
        IStreamPreservationRecords.CollectionRecord memory record,
        bytes32 recordHash
    ) private view returns (P.Evidence memory evidence, bytes32 evidenceHash) {
        if (receipt.artistAuthorization == 0) {
            revert IStreamWorkRecordSelection.InvalidWorkRecord(recordHash);
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
            revert IStreamWorkRecordSelection.InvalidWorkRecord(recordHash);
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
            RECORD_TYPE,
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
                || (evidence.authorityClass != 1 && evidence.authorityClass != 3)
                || evidence.requiredCapability != 1 || evidence.signedAt == 0
                || evidence.signedAt > receipt.recordedAt
                || evidence.publicationHash != keccak256(abi.encode(p))
        ) revert IStreamWorkRecordSelection.InvalidWorkRecord(recordHash);
        _attestation(d, evidence, p, recordHash);
        return (evidence, keccak256(abi.encode(saved)));
    }

    function _attestation(
        StreamWorkRecordContext.Dependencies memory d,
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
            record.recordHash != evidence.attestationRecordHash || record.subjectStateHash != 0
                || record.schemaId != PUBLICATION_SCHEMA
                || record.statementHash != keccak256(statement)
                || record.generation != evidence.bindingGeneration
                || record.signedAt != evidence.signedAt || record.signer != evidence.signer
        ) revert IStreamWorkRecordSelection.InvalidWorkRecord(recordHash);
        raw = _read(
            d,
            d.artists[4],
            abi.encodeCall(IStreamArtistAttributionOwner.statementBytes, (record.statementHash)),
            480
        );
        bytes memory saved = abi.decode(raw, (bytes));
        _canonical(d.artists[4], raw, abi.encode(saved));
        if (saved.length != 416 || keccak256(saved) != keccak256(statement)) {
            revert IStreamWorkRecordSelection.InvalidWorkRecord(recordHash);
        }
    }

    function _policy(StreamWorkRecordContext.Dependencies memory d)
        private
        view
        returns (IStreamCollectionMetadataV1.RecordPolicy memory policy)
    {
        bytes memory raw = _fixed(
            d,
            d.targets[1],
            abi.encodeCall(IStreamCollectionMetadataV1.recordPolicy, (RECORD_TYPE)),
            96
        );
        policy = abi.decode(raw, (IStreamCollectionMetadataV1.RecordPolicy));
        _canonical(d.targets[1], raw, abi.encode(policy));
        if (!policy.admitted || policy.family != StreamRecordFamilies.CURATOR) {
            revert IStreamWorkRecordSelection.WorkSelectionAuthorityRequired();
        }
    }

    function _receipt(StreamWorkRecordContext.Dependencies memory d, bytes32 hash)
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
        StreamWorkRecordContext.Dependencies memory d,
        bytes32 recordHash,
        IStreamCollectionMetadataV1.RecordReceipt memory receipt
    ) private view {
        bytes memory raw = _fixed(
            d,
            d.targets[1],
            abi.encodeCall(
                IStreamCollectionMetadataV1.recordHashAt,
                (receipt.collectionId, RECORD_TYPE, receipt.recordIndex)
            ),
            32
        );
        if (_word(raw, 0) != recordHash) {
            revert IStreamWorkRecordSelection.InvalidWorkRecord(recordHash);
        }
        bytes32 previous;
        if (receipt.recordIndex != 0) {
            raw = _fixed(
                d,
                d.targets[1],
                abi.encodeCall(
                    IStreamCollectionMetadataV1.recordHashAt,
                    (receipt.collectionId, RECORD_TYPE, receipt.recordIndex - 1)
                ),
                32
            );
            IStreamCollectionMetadataV1.RecordReceipt memory prior = _receipt(d, _word(raw, 0));
            if (
                prior.collectionId != receipt.collectionId
                    || prior.recordIndex + 1 != receipt.recordIndex
            ) revert IStreamWorkRecordSelection.InvalidWorkRecord(recordHash);
            previous = prior.recordChainHash;
        }
        bytes32 expected = keccak256(
            abi.encode(
                StreamCollectionRecordHashes.CHAIN_DOMAIN,
                d.chainId,
                d.targets[1],
                receipt.collectionId,
                RECORD_TYPE,
                previous,
                recordHash,
                receipt.recordIndex
            )
        );
        if (receipt.recordChainHash != expected) {
            revert IStreamWorkRecordSelection.InvalidWorkRecord(recordHash);
        }
    }

    function _payload(
        StreamWorkRecordContext.Dependencies memory d,
        bytes32 recordHash,
        bytes32 payloadHash
    ) private view returns (bytes memory original) {
        bytes memory raw = _fixed(
            d, d.targets[3], abi.encodeWithSignature("chunk(bytes32)", payloadHash), 64
        );
        (address ptr, uint32 size) = abi.decode(raw, (address, uint32));
        _canonical(d.targets[3], raw, abi.encode(ptr, size));
        original = _chunk(d, payloadHash);
        if (
            ptr == address(0) || original.length != size || original.length == 0
                || keccak256(original) != payloadHash
        ) revert IStreamWorkRecordSelection.InvalidWorkRecord(recordHash);
    }

    function _recordHash(
        StreamWorkRecordContext.Dependencies memory d,
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

    function _chunk(StreamWorkRecordContext.Dependencies memory d, bytes32 hash)
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
            revert IStreamWorkRecordSelection.WorkDependencyReadFailed(d.targets[3]);
        }
    }

    function _word(bytes memory raw, uint256 index) private pure returns (bytes32 word) {
        assembly ("memory-safe") { word := mload(add(add(raw, 32), mul(index, 32))) }
    }

    function _canonical(address target, bytes memory raw, bytes memory encoded) private pure {
        if (raw.length != encoded.length || keccak256(raw) != keccak256(encoded)) {
            revert IStreamWorkRecordSelection.WorkDependencyReadFailed(target);
        }
    }

    function _fixed(
        StreamWorkRecordContext.Dependencies memory d,
        address target,
        bytes memory input,
        uint256 size
    ) private view returns (bytes memory raw) {
        raw = _read(d, target, input, size);
        if (raw.length != size) revert IStreamWorkRecordSelection.WorkDependencyReadFailed(target);
    }

    function _read(
        StreamWorkRecordContext.Dependencies memory d,
        address target,
        bytes memory input,
        uint256 maximum
    ) private view returns (bytes memory raw) {
        uint256 cap = d.readGas;
        raw = new bytes(maximum);
        if (cap == 0 || cap > type(uint64).max || gasleft() <= cap + cap / 63 + 10000) {
            revert IStreamWorkRecordSelection.WorkDependencyReadFailed(target);
        }
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(raw, 32), maximum)
            size := returndatasize()
        }
        if (!ok || size > maximum) {
            revert IStreamWorkRecordSelection.WorkDependencyReadFailed(target);
        }
        assembly ("memory-safe") { mstore(raw, size) }
    }
}
