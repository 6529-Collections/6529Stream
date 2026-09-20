// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistPublicationHydration.sol";
import "./StreamArtistMultipleDelegationCodec.sol";
import "./StreamArtistMultipleHydrationOperations.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import {
    StreamArtistMultipleRecordsTypes as MR
} from "../../interfaces/stream/artist/IStreamArtistMultipleRecordsHydration.sol";

library StreamArtistMultipleRecordsAttestations {
    function collect(
        T.SuiteConfiguration memory s,
        MD.Inventory memory inv,
        MR.CollectionWitness[] memory inputs,
        MD.Identities memory identities
    ) public view returns (bytes memory) {
        MR.Attribution memory b;
        b.sourceRegistry = s.registry;
        b.collections = inv.collections;
        b.records = new PubH.Row[](inv.receipts[4].length);
        uint256[] memory used = new uint256[](inputs.length);
        StreamArtistHashes.Environment memory e =
            StreamArtistHashes.Environment(block.chainid, s.registry, s.core, s.mintManager);
        for (uint256 j; j < b.records.length; ++j) {
            H.Receipt memory n = inv.receipts[4][j];
            uint256 c = _collection(inv.collections, n.collectionId);
            if (used[c] >= inputs[c].attestations.length) revert T.InvalidRecord();
            PubH.Row memory row;
            row.attestation.input = inputs[c].attestations[used[c]++];
            row.attestation.record =
                IStreamArtistAttributionOwner(s.owners[4]).attestationRecord(n.recordHash);
            row.attestation.authorityClass = IStreamArtistReadinessAttributionOwner(s.owners[4])
                .attestationAuthorityClass(n.recordHash);
            row.attestation.association = IStreamArtistAuthenticatedAttestationOwner(s.owners[4])
                .attestationAssociation(n.recordHash);
            row.attestation.statement = IStreamArtistAttributionOwner(s.owners[4])
                .statementBytes(row.attestation.record.statementHash);
            row.publication = IStreamArtistRecordPublicationOwner(s.owners[4])
                .publicationAttestation(n.recordHash);
            StreamArtistPublicationHydration.validate(e, inv.collections[c], row);
            uint256 a;
            while (a < identities.rows.length && identities.rows[a].artistId != n.artistId) ++a;
            if (a == identities.rows.length) revert T.InvalidRecord();
            DH.Identity memory identity =
                StreamArtistDelegationHydrationCodec.identity(identities.rows[a].state);
            AH.Identity memory original = abi.decode(identity.baseline, (AH.Identity));
            if (
                row.attestation.record.recordHash != n.recordHash
                    || row.attestation.record.signer != original.item.authorityAddress
            ) revert T.InvalidRecord();
            b.records[j] = row;
        }
        for (uint256 c; c < inputs.length; ++c) {
            if (used[c] != inputs[c].attestations.length) revert T.InvalidRecord();
        }
        for (uint256 j; j < b.records.length; ++j) {
            RH.AttestationRow memory row = b.records[j].attestation;
            bool last = true;
            bytes32 key = _key(row.input.terms);
            for (uint256 k = j + 1; k < b.records.length; ++k) {
                if (_key(b.records[k].attestation.input.terms) == key) last = false;
            }
            if (
                last
                    && keccak256(abi.encode(row.record))
                        != keccak256(
                            abi.encode(
                                IStreamArtistAttributionOwner(s.owners[4])
                                    .attestation(
                                        row.input.terms.collectionId,
                                        row.input.terms.subjectKind,
                                        row.input.terms.subjectId
                                    )
                            )
                        )
            ) revert T.InvalidRecord();
        }
        _credentials(s.owners[4], b, identities);
        return abi.encode(MR.ATTRIBUTION, b);
    }

    function _credentials(address owner, MR.Attribution memory b, MD.Identities memory identities)
        private
        view
    {
        for (uint256 a; a < identities.rows.length; ++a) {
            bytes32 artist = identities.rows[a].artistId;
            C2PA.Head memory expected;
            for (uint256 j; j < b.records.length; ++j) {
                RH.AttestationRow memory row = b.records[j].attestation;
                T.Attestation memory p = row.input.terms;
                uint256 c = _collection(b.collections, p.collectionId);
                AH.Query memory q = b.collections[c];
                if (
                    q.artistId != artist || p.subjectKind != 10
                        || p.schemaId != StreamArtistC2PACredentials.SCHEMA
                ) continue;
                C2PA.Payload memory payload =
                    StreamArtistC2PACredentials.decode(row.statement, artist, p.subjectStateHash);
                if (payload.previousRecordHash != expected.recordHash) revert T.InvalidRecord();
                expected = C2PA.Head(
                    expected.revision + 1,
                    row.record.recordHash,
                    expected.recordHash,
                    artist,
                    p.collectionId,
                    q.bindingHash,
                    1,
                    p.subjectStateHash,
                    row.record.statementHash,
                    b.sourceRegistry
                );
                if (
                    keccak256(
                            abi.encode(
                                IStreamArtistC2PAReads(owner)
                                    .c2paCredentialRecord(expected.recordHash)
                            )
                        ) != keccak256(abi.encode(expected))
                ) revert T.InvalidRecord();
            }
            if (
                keccak256(abi.encode(IStreamArtistC2PAReads(owner).c2paCredentialHead(artist)))
                    != keccak256(abi.encode(expected))
            ) revert T.InvalidRecord();
        }
        for (uint256 c; c < b.collections.length; ++c) {
            AH.Query memory q = b.collections[c];
            T.AttestationRecord memory expected;
            for (uint256 j; j < b.records.length; ++j) {
                RH.AttestationRow memory row = b.records[j].attestation;
                T.Attestation memory p = row.input.terms;
                if (
                    p.collectionId == q.collectionId && p.subjectKind == 10
                        && StreamArtistC2PACredentials.isPersonhood(p.schemaId)
                ) expected = row.record;
            }
            if (
                keccak256(
                        abi.encode(
                            IStreamArtistC2PAReads(owner)
                                .personhoodAttestation(q.collectionId, q.artistId)
                        )
                    ) != keccak256(abi.encode(expected))
            ) revert T.InvalidRecord();
        }
    }

    function importState(
        AS.State storage s,
        StreamArtistHashes.Environment memory e,
        bytes memory raw
    ) public {
        (bytes32 tag, MR.Attribution memory b) = abi.decode(raw, (bytes32, MR.Attribution));
        if (
            tag != MR.ATTRIBUTION || b.sourceRegistry == address(0) || b.collections.length == 0
                || b.collections.length > 128 || b.records.length > 128
        ) revert T.InvalidRecord();
        e.registry = b.sourceRegistry;
        for (uint256 c; c < b.collections.length; ++c) {
            AH.Query memory q = b.collections[c];
            if (
                q.collectionId == 0
                    || (c != 0 && q.collectionId <= b.collections[c - 1].collectionId)
                    || s.attributions[q.collectionId].generation != 0
            ) revert T.InvalidRecord();
            s.attributions[q.collectionId] = AS.Attribution(2, 1);
        }
        for (uint256 j; j < b.records.length; ++j) {
            PubH.Row memory row = b.records[j];
            RH.AttestationRow memory r = row.attestation;
            AH.Query memory q =
                b.collections[_collection(b.collections, r.input.terms.collectionId)];
            StreamArtistPublicationHydration.validate(e, q, row);
            bytes32 record = r.record.recordHash;
            if (
                s.records[record].recordHash != 0
                    || s.publications[record].evidence.attestationRecordHash != 0
            ) revert T.InvalidRecord();
            s.records[record] = r.record;
            s.attestationClasses[record] = r.authorityClass;
            s.attestationAssociations[record] = r.association;
            s.attestations[_key(r.input.terms)] = r.record;
            if (r.input.terms.subjectKind == 7 || r.input.terms.subjectKind == 8) {
                s.publications[record] = row.publication;
            }
            if (s.statements[r.record.statementHash].length == 0) {
                s.statements[r.record.statementHash] = r.statement;
            }
            StreamArtistPayloadStore.store(keccak256("ARTIST_PUBLICATION_STATEMENT"), r.statement);
            StreamArtistC2PACredentials.note(
                b.sourceRegistry,
                q.artistId,
                q.bindingHash,
                r.input.terms,
                r.record,
                r.statement,
                false
            );
        }
    }

    function _collection(AH.Query[] memory rows, uint256 id) private pure returns (uint256) {
        for (uint256 c; c < rows.length; ++c) {
            if (rows[c].collectionId == id) return c;
        }
        revert T.InvalidRecord();
    }

    function _key(T.Attestation memory p) private pure returns (bytes32) {
        return keccak256(abi.encode(p.collectionId, p.subjectKind, p.subjectId));
    }
}
