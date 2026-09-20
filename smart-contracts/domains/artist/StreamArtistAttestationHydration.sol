// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistC2PACredentials.sol";
import "./StreamArtistAttributionStateTypes.sol";
import "./StreamArtistNativeReceipts.sol";
import "./StreamArtistPayloadStore.sol";
import "../../interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    StreamArtistReadinessHydrationTypes as RH
} from "../../interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import { StreamArtistAttributionStateTypes as AS } from "./StreamArtistAttributionStateTypes.sol";

library StreamArtistAttestationHydration {
    bytes32 internal constant SCHEMA =
        keccak256("6529STREAM_ARTIST_ATTESTATION_HYDRATION_STATE_V1");

    function isState(bytes calldata raw) internal pure returns (bool) {
        return raw.length >= 32 && bytes32(raw[:32]) == SCHEMA;
    }

    function decode(bytes memory raw) public pure returns (RH.AttributionBundle memory b) {
        (b.schema, b.sourceRegistry, b.state, b.generation, b.records) =
            abi.decode(raw, (bytes32, address, uint8, uint64, RH.AttestationRow[]));
        if (
            b.schema != SCHEMA || b.records.length == 0 || b.records.length > 128
                || b.sourceRegistry == address(0) || b.state != 2 || b.generation != 1
        ) revert T.InvalidRecord();
    }

    /// @dev Original owner arguments decoded once in the fixed read worker.
    function exportEncoded(
        AS.State storage s,
        StreamArtistHashes.Environment memory e,
        bytes calldata data
    ) public view returns (bytes memory) {
        (AH.Query memory q, RH.AttestationInput[] memory inputs) =
            abi.decode(data[4:], (AH.Query, RH.AttestationInput[]));
        return exportState(s, e, q, inputs);
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
        RH.AttestationRow[] memory rows = new RH.AttestationRow[](count);
        for (uint256 j; j < count; ++j) {
            H.Receipt memory n = StreamArtistNativeReceipts.at(j);
            if (n.operation != 24 || n.artistId != q.artistId || n.collectionId != q.collectionId) {
                revert T.UnsupportedProfile();
            }
            T.AttestationRecord memory r = s.records[n.recordHash];
            rows[j] = RH.AttestationRow(
                inputs[j],
                r,
                s.attestationClasses[n.recordHash],
                s.attestationAssociations[n.recordHash],
                s.statements[r.statementHash]
            );
            shape(e, q, rows[j], false);
            if (
                r.recordHash != n.recordHash
                    || s.publications[n.recordHash].evidence.attestationRecordHash != 0
            ) revert T.InvalidRecord();
        }
        for (uint256 j; j < count; ++j) {
            bool latest = true;
            bytes32 key = _key(q.collectionId, inputs[j].terms);
            for (uint256 k = j + 1; k < count; ++k) {
                if (_key(q.collectionId, inputs[k].terms) == key) latest = false;
            }
            if (
                latest
                    && keccak256(abi.encode(s.attestations[key]))
                        != keccak256(abi.encode(rows[j].record))
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
        RH.AttributionBundle memory b = decode(raw);
        e.registry = b.sourceRegistry;
        if (s.attributions[q.collectionId].generation != 0) revert T.InvalidRecord();
        s.attributions[q.collectionId] = AS.Attribution(b.state, b.generation);
        for (uint256 j; j < b.records.length; ++j) {
            RH.AttestationRow memory r = b.records[j];
            shape(e, q, r, false);
            bytes32 record = r.record.recordHash;
            if (s.records[record].recordHash != 0) revert T.InvalidRecord();
            s.records[record] = r.record;
            s.attestationClasses[record] = r.authorityClass;
            s.attestationAssociations[record] = r.association;
            s.attestations[_key(q.collectionId, r.input.terms)] = r.record;
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

    function _key(uint256 collectionId, T.Attestation memory p) private pure returns (bytes32) {
        return keccak256(abi.encode(collectionId, p.subjectKind, p.subjectId));
    }

    function shape(
        StreamArtistHashes.Environment memory e,
        AH.Query memory q,
        RH.AttestationRow memory r,
        bool publication
    ) public pure {
        T.Attestation memory p = r.input.terms;
        T.AttestationRecord memory record = r.record;
        Attest.Association memory a = r.association;
        if (p.subjectKind == 10 && p.schemaId == StreamArtistC2PACredentials.SCHEMA) {
            StreamArtistC2PACredentials.decode(r.statement, q.artistId, p.subjectStateHash);
            if (p.subjectId != q.artistId) revert T.InvalidRecord();
        }
        if (
            p.collectionId != q.collectionId || p.subjectKind == 0 || p.subjectKind > 10
                || ((p.subjectKind == 7 || p.subjectKind == 8) && !publication)
                || r.authorityClass != 1 || record.generation != 1 || record.signer == address(0)
                || record.signedAt == 0 || r.statement.length == 0 || r.statement.length > 8192
                || bytes(p.statementURI).length > 2048 || p.statementHash != keccak256(r.statement)
                || record.statementHash != p.statementHash || record.schemaId != p.schemaId
                || record.subjectStateHash != p.subjectStateHash
                || record.recordHash
                    != StreamArtistHashes.attestationRecordForAuthority(
                        e, p, q.artistId, record.signer, 1, r.input.nonce, record.signedAt
                    )
        ) revert T.InvalidRecord();
        if (a.artistId == 0) {
            Attest.Association memory empty;
            if (
                (p.subjectKind != 9
                        && p.subjectKind != 10
                        && !(publication && (p.subjectKind == 7 || p.subjectKind == 8)))
                    || keccak256(abi.encode(a)) != keccak256(abi.encode(empty))
            ) revert T.InvalidRecord();
        } else if (
            a.artistId != q.artistId || a.bindingHash != q.bindingHash || a.generation != 1
                || a.delegation != 0 || a.fact.owner == address(0) || a.fact.ownerCodeHash == 0
                || a.fact.subjectId != p.subjectId || a.fact.stateHash != p.subjectStateHash
        ) {
            revert T.InvalidRecord();
        }
    }
}
