// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistHashes.sol";
import "./StreamArtistRecordPublicationRules.sol";
import "../../interfaces/stream/artist/IStreamArtistRecordPublicationOwner.sol";

/// @notice Exact publication attestation mechanics in the Attribution owner's compiler-linked context.
/// @dev The owner keeps the callback guard, current-authority/attribution admission and its one commit.
library StreamArtistRecordPublicationState {
    struct Input {
        StreamArtistHashes.Environment environment;
        T.Binding binding_;
        T.Attestation terms;
        R.AuthorityFact authority;
        uint256 nonce;
        uint64 signedAt;
        bytes statement;
        bytes32 metadataHostCodeHash;
    }

    event ArtistAttestationRecorded(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint8 indexed subjectKind,
        address indexed signer,
        bytes32 subjectId,
        bytes32 subjectStateHash,
        bytes32 schemaId,
        bytes32 statementHash,
        bytes32 statementURIHash,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt,
        bytes32 attestationRecordHash
    );

    function record(
        mapping(bytes32 => T.AttestationRecord) storage records,
        mapping(bytes32 => T.AttestationRecord) storage latest,
        mapping(bytes32 => bytes) storage statements,
        mapping(bytes32 => IStreamArtistRecordPublicationOwner.Record) storage publications,
        Input memory x
    ) public returns (bytes32 recordHash, bytes32 actionHash, bytes32 stateDelta) {
        T.Attestation memory p = x.terms;
        if (
            x.statement.length == 0 || p.statementHash == 0
                || keccak256(x.statement) != p.statementHash
        ) {
            revert T.InvalidRecord();
        }
        if (x.statement.length > 8192) revert T.BoundExceeded(x.statement.length, 8192);
        if (bytes(p.statementURI).length > 2048) {
            revert T.BoundExceeded(bytes(p.statementURI).length, 2048);
        }
        (P.Publication memory publication, uint32 capability) =
            StreamArtistRecordPublicationRules.decode(p, x.statement);
        address signer = x.authority.authorityAddress;
        if (publication.recorder != signer) revert T.InvalidRecord();
        recordHash = StreamArtistHashes.attestationRecordForAuthority(
            x.environment,
            p,
            x.binding_.artistId,
            signer,
            x.authority.authorityClass,
            x.nonce,
            x.signedAt
        );
        if (records[recordHash].recordHash != 0) revert T.InvalidRecord();
        T.AttestationRecord memory item = T.AttestationRecord(
            recordHash,
            p.subjectStateHash,
            p.schemaId,
            p.statementHash,
            x.binding_.generation,
            x.signedAt,
            signer
        );
        records[recordHash] = item;
        latest[keccak256(abi.encode(p.collectionId, p.subjectKind, p.subjectId))] = item;
        if (statements[p.statementHash].length == 0) statements[p.statementHash] = x.statement;
        publications[recordHash] = IStreamArtistRecordPublicationOwner.Record(
            publication,
            P.Evidence(
                recordHash,
                x.binding_.artistId,
                x.binding_.bindingHash,
                x.binding_.generation,
                signer,
                x.authority.authorityClass,
                capability,
                x.signedAt,
                keccak256(abi.encode(publication))
            ),
            x.metadataHostCodeHash
        );
        stateDelta = keccak256(abi.encode(p.collectionId, p.subjectKind, p.subjectId, item));
        stateDelta = keccak256(abi.encode(stateDelta, publications[recordHash]));
        actionHash = keccak256(
            abi.encode(x.binding_, p, signer, x.nonce, x.signedAt, keccak256(x.statement))
        );
        // The host's subsequent commit neither calls externally nor emits a log; a failure rolls this back.
        _emit(p, x, signer, recordHash);
    }

    function _emit(T.Attestation memory p, Input memory x, address signer, bytes32 recordHash)
        private
    {
        emit ArtistAttestationRecorded(
            1,
            p.collectionId,
            p.subjectKind,
            signer,
            p.subjectId,
            p.subjectStateHash,
            p.schemaId,
            p.statementHash,
            keccak256(bytes(p.statementURI)),
            x.authority.authorityClass,
            x.nonce,
            x.signedAt,
            recordHash
        );
    }
}
