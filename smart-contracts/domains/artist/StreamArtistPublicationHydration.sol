// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistAttestationHydration.sol";
import "./StreamArtistRecordPublicationRules.sol";
import {
    StreamArtistPublicationHydrationTypes as PubH
} from "../../interfaces/stream/artist/IStreamArtistPublicationAuthorityHydration.sol";

/// @notice Original publication records and evidence, never a Metadata consumption-state import.
library StreamArtistPublicationHydration {
    bytes32 internal constant SCHEMA =
        keccak256("6529STREAM_ARTIST_PUBLICATION_HYDRATION_STATE_V1");

    function isState(bytes calldata raw) internal pure returns (bool) {
        return raw.length >= 32 && bytes32(raw[:32]) == SCHEMA;
    }

    function decode(bytes memory raw) public pure returns (PubH.Bundle memory b) {
        (b.schema, b.sourceRegistry, b.state, b.generation, b.records) =
            abi.decode(raw, (bytes32, address, uint8, uint64, PubH.Row[]));
        if (
            b.schema != SCHEMA || b.sourceRegistry == address(0) || b.state != 2
                || b.generation != 1 || b.records.length == 0 || b.records.length > 128
        ) revert T.InvalidRecord();
    }

    function exportState(
        AS.State storage s,
        StreamArtistHashes.Environment memory e,
        AH.Query memory q,
        RH.AttestationInput[] memory inputs
    ) public view returns (bytes memory) {
        uint256 count = StreamArtistNativeReceipts.count();
        if (
            count != inputs.length || count == 0 || count > 128
                || s.attributions[q.collectionId].state != 2
                || s.attributions[q.collectionId].generation != 1
        ) revert T.UnsupportedProfile();
        PubH.Row[] memory rows = new PubH.Row[](count);
        bool publication;
        for (uint256 j; j < count; ++j) {
            H.Receipt memory n = StreamArtistNativeReceipts.at(j);
            if (n.operation != 24 || n.artistId != q.artistId || n.collectionId != q.collectionId) {
                revert T.UnsupportedProfile();
            }
            T.AttestationRecord memory r = s.records[n.recordHash];
            rows[j] = PubH.Row(
                RH.AttestationRow(
                    inputs[j],
                    r,
                    s.attestationClasses[n.recordHash],
                    s.attestationAssociations[n.recordHash],
                    s.statements[r.statementHash]
                ),
                s.publications[n.recordHash]
            );
            validate(e, q, rows[j]);
            if (r.recordHash != n.recordHash) revert T.InvalidRecord();
            if (_publication(inputs[j].terms.subjectKind)) publication = true;
        }
        if (!publication) revert T.UnsupportedProfile();
        for (uint256 j; j < count; ++j) {
            bool latest = true;
            bytes32 key = _key(q.collectionId, inputs[j].terms);
            for (uint256 k = j + 1; k < count; ++k) {
                if (_key(q.collectionId, inputs[k].terms) == key) latest = false;
            }
            if (
                latest
                    && keccak256(abi.encode(s.attestations[key]))
                        != keccak256(abi.encode(rows[j].attestation.record))
            ) revert T.InvalidRecord();
        }
        return abi.encode(SCHEMA, e.registry, uint8(2), uint64(1), rows);
    }

    function importState(
        AS.State storage s,
        StreamArtistHashes.Environment memory e,
        AH.Query memory q,
        bytes memory raw
    ) public {
        PubH.Bundle memory b = decode(raw);
        e.registry = b.sourceRegistry;
        if (s.attributions[q.collectionId].generation != 0) revert T.InvalidRecord();
        s.attributions[q.collectionId] = AS.Attribution(b.state, b.generation);
        bool publication;
        for (uint256 j; j < b.records.length; ++j) {
            PubH.Row memory row = b.records[j];
            validate(e, q, row);
            RH.AttestationRow memory r = row.attestation;
            bytes32 record = r.record.recordHash;
            if (
                s.records[record].recordHash != 0
                    || s.publications[record].evidence.attestationRecordHash != 0
            ) revert T.InvalidRecord();
            s.records[record] = r.record;
            s.attestationClasses[record] = r.authorityClass;
            s.attestationAssociations[record] = r.association;
            s.attestations[_key(q.collectionId, r.input.terms)] = r.record;
            if (_publication(r.input.terms.subjectKind)) {
                s.publications[record] = row.publication;
                publication = true;
            }
            if (s.statements[r.record.statementHash].length == 0) {
                s.statements[r.record.statementHash] = r.statement;
            }
            StreamArtistPayloadStore.store(keccak256("ARTIST_PUBLICATION_STATEMENT"), r.statement);
        }
        if (!publication) revert T.UnsupportedProfile();
    }

    /// @dev Applies original record shape, and independently joins every retained publication field.
    function validate(
        StreamArtistHashes.Environment memory e,
        AH.Query memory q,
        PubH.Row memory row
    ) public pure {
        RH.AttestationRow memory r = row.attestation;
        bool publication = _publication(r.input.terms.subjectKind);
        StreamArtistAttestationHydration.shape(e, q, r, publication);
        if (!publication) {
            IStreamArtistRecordPublicationOwner.Record memory empty;
            if (keccak256(abi.encode(row.publication)) != keccak256(abi.encode(empty))) {
                revert T.InvalidRecord();
            }
            return;
        }
        (P.Publication memory p, uint32 capability) =
            StreamArtistRecordPublicationRules.decode(r.input.terms, r.statement);
        P.Evidence memory a = row.publication.evidence;
        if (
            row.publication.metadataHostCodeHash == 0
                || keccak256(abi.encode(p)) != keccak256(abi.encode(row.publication.publication))
                || a.attestationRecordHash != r.record.recordHash || a.artistId != q.artistId
                || a.bindingHash != q.bindingHash || a.bindingGeneration != 1
                || a.signer != r.record.signer || a.signer != p.recorder || a.authorityClass != 1
                || a.requiredCapability != capability || a.signedAt != r.record.signedAt
                || a.publicationHash != keccak256(abi.encode(p))
        ) revert T.InvalidRecord();
        // The original direct publication callback predates Association. Only an exactly
        // empty Association is historical; a present one must join its admitted host facts.
        if (
            r.association.artistId != 0
                && (r.association.fact.owner != p.metadataHost
                    || r.association.fact.ownerCodeHash != row.publication.metadataHostCodeHash)
        ) revert T.InvalidRecord();
    }

    function readinessState(PubH.Bundle memory b) public pure returns (bytes memory) {
        RH.AttestationRow[] memory rows = new RH.AttestationRow[](b.records.length);
        for (uint256 j; j < rows.length; ++j) {
            rows[j] = b.records[j].attestation;
        }
        return abi.encode(
            keccak256("6529STREAM_ARTIST_ATTESTATION_HYDRATION_STATE_V1"),
            b.sourceRegistry,
            b.state,
            b.generation,
            rows
        );
    }

    function _publication(uint8 kind) private pure returns (bool) {
        return kind == 7 || kind == 8;
    }

    function _key(uint256 collectionId, T.Attestation memory p) private pure returns (bytes32) {
        return keccak256(abi.encode(collectionId, p.subjectKind, p.subjectId));
    }
}
