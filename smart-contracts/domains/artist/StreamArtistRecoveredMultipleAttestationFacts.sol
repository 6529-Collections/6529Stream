// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistPublicationHydrationTypes as PubH
} from "../../interfaces/stream/artist/IStreamArtistPublicationAuthorityHydration.sol";
import {
    StreamArtistC2PATypes as C2PA
} from "../../interfaces/stream/artist/IStreamArtistC2PA.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredAttestationHydration as Original
} from "./StreamArtistRecoveredAttestationHydration.sol";
import {
    StreamArtistRecoveredHistoryRecordRows as Semantic
} from "./StreamArtistRecoveredHistoryRecordRows.sol";
import {
    StreamArtistRecoveredMultipleAttestationRows as Rows
} from "./StreamArtistRecoveredMultipleAttestationRows.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredMultipleCollectionRows as Collections
} from "./StreamArtistRecoveredMultipleCollectionRows.sol";
import {
    StreamArtistRecoveredMultipleCodec as Scope
} from "./StreamArtistRecoveredMultipleCodec.sol";
import { StreamArtistC2PACredentials as Credentials } from "./StreamArtistC2PACredentials.sol";

/// @notice Original op24 facts across a complete accepted generation-one aggregate.
/// @dev Inputs remain canonical original bundles and whole provenance. The enclosing flow
/// authenticates actual source bytes, accepted PRIMARY_ONLY bindings, Identity state and all
/// seven owners. This pure worker does not infer present authority, compare saved live C2PA
/// heads, install state or conclude grant equality across consent and attestation operations.
/// Exact per-collection owner4 acceptance clocks must be authenticated from original Archive
/// envelopes by the enclosing flow; era counters never establish within-era completion order.
library StreamArtistRecoveredMultipleAttestationFacts {
    struct Context {
        Rows.IdentityRows[] identities;
        Original.Bundle[] attestations;
        uint256[] cursors;
        uint256[] summaries;
        C2PA.Head[] heads;
        uint256[] proposals;
        uint256[] proposalEras;
    }

    /// @dev Arrays align scope.artists/collections; scope.rows is intentionally not consumed.
    /// Empty per-collection histories are permitted; profile selection belongs to the caller.
    function validate(
        bytes[] calldata canonicalIdentities,
        M.State calldata scope,
        bytes[] calldata canonicalAttestations,
        RH.Provenance calldata p
    ) public pure returns (uint256[][] memory uses) {
        RH.OwnerProvenance memory owner = RH.ownerProvenance(p, 4);
        Provenance.validateOwner(owner, 4);
        RH.OwnerProvenance memory bindings = RH.ownerProvenance(p, 0);
        Provenance.validateOwner(bindings, 0);
        // Validate the complete scope independently of owner-specific opaque rows. A fresh
        // struct avoids mutating a caller's scope or accidentally requiring another row codec.
        M.State memory checkedScope =
            M.State(scope.artists, scope.collections, new bytes[](scope.collections.length));
        Scope.validate(4, checkedScope, owner);
        if (
            canonicalIdentities.length != scope.artists.length
                || canonicalAttestations.length != scope.collections.length
        ) _invalid();
        Context memory c;
        c.identities = new Rows.IdentityRows[](scope.artists.length);
        uses = new uint256[][](scope.artists.length);
        for (uint256 a; a < scope.artists.length; ++a) {
            c.identities[a] = Rows.identity(canonicalIdentities[a], scope.artists[a].artistId);
            uses[a] = new uint256[](c.identities[a].delegations.length);
        }
        c.attestations = new Original.Bundle[](scope.collections.length);
        c.cursors = new uint256[](scope.collections.length);
        c.summaries = new uint256[](scope.collections.length);
        c.heads = new C2PA.Head[](scope.artists.length);
        c.proposals = new uint256[](p.eras.length);
        c.proposalEras = new uint256[](scope.collections.length);
        bytes32 whole = RH.ownerProvenanceHash(owner, 4);
        uint256 total;
        for (uint256 k; k < scope.collections.length; ++k) {
            AH.Query memory q = scope.collections[k];
            Original.Bundle memory b = abi.decode(canonicalAttestations[k], (Original.Bundle));
            if (
                keccak256(canonicalAttestations[k]) != keccak256(abi.encode(b))
                    || b.provenance != whole || b.artistId != q.artistId
                    || b.collectionId != q.collectionId || b.bindingHash != q.bindingHash
                    || b.item.state != 2 || b.item.generation != 1 || b.records.length > 128
                    || b.personhood.length > 128 || q.records.length != b.records.length
            ) _invalid();
            for (uint256 r; r < b.records.length; ++r) {
                if (q.records[r] != b.records[r].attestation.record.recordHash) _invalid();
            }
            c.attestations[k] = b;
            total += b.records.length;
            RH.JournalEntry memory proposal = Collections.occurrence(bindings, q, 1, q.bindingHash);
            uint256 e = Collections.era(owner, proposal.position.point.environmentHash);
            c.proposalEras[k] = e;
            ++c.proposals[e];
        }
        if (total != owner.journal.length || owner.aliases.length != 0) _invalid();
        _eras(owner, c.proposals);
        // The original owner journal determines execution order, not collection grouping.
        for (uint256 i; i < owner.journal.length; ++i) {
            RH.JournalEntry memory native_ = owner.journal[i];
            if (native_.receipt.operation != 24) _invalid();
            for (uint256 j; j < i; ++j) {
                if (owner.journal[j].receipt.recordHash == native_.receipt.recordHash) _invalid();
            }
            uint256 k = Scope.collection(checkedScope, native_.receipt.collectionId);
            uint256 a = Scope.artist(checkedScope, native_.receipt.artistId);
            AH.Query memory q = scope.collections[k];
            if (
                q.artistId != native_.receipt.artistId
                    || c.cursors[k] >= c.attestations[k].records.length
            ) _invalid();
            uint256 e = Collections.era(owner, native_.position.point.environmentHash);
            if (e < c.proposalEras[k]) _invalid();
            PubH.Row memory row = c.attestations[k].records[c.cursors[k]++];
            if (row.attestation.record.recordHash != native_.receipt.recordHash) _invalid();
            Semantic.validateRow(q, p.origins[e], row, 1);
            uint256 g = Rows.validate(
                c.identities[a],
                row.attestation,
                Rows.Scope(q.artistId, q.collectionId, q.bindingHash),
                p,
                native_
            );
            if (g != type(uint256).max) ++uses[a][g];
            T.Attestation memory t = row.attestation.input.terms;
            if (t.subjectKind == 10 && Credentials.isPersonhood(t.schemaId)) {
                if (c.summaries[k] >= c.attestations[k].personhood.length) _invalid();
                Semantic.validateSummary(
                    q,
                    p.origins[e],
                    row.attestation,
                    c.attestations[k].personhood[c.summaries[k]++],
                    1
                );
            }
            if (t.subjectKind == 10 && t.schemaId == Credentials.SCHEMA) {
                C2PA.Payload memory payload =
                    Credentials.decode(row.attestation.statement, q.artistId, t.subjectStateHash);
                C2PA.Head memory previous = c.heads[a];
                if (payload.previousRecordHash != previous.recordHash) _invalid();
                c.heads[a] = C2PA.Head(
                    previous.revision + 1,
                    row.attestation.record.recordHash,
                    previous.recordHash,
                    q.artistId,
                    q.collectionId,
                    q.bindingHash,
                    1,
                    t.subjectStateHash,
                    t.statementHash,
                    p.origins[e].registry
                );
            }
        }
        for (uint256 k; k < scope.collections.length; ++k) {
            if (
                c.cursors[k] != c.attestations[k].records.length
                    || c.summaries[k] != c.attestations[k].personhood.length
            ) _invalid();
        }
    }

    function _eras(RH.OwnerProvenance memory p, uint256[] memory proposals) private pure {
        uint256 cursor;
        for (uint256 e; e < p.eras.length; ++e) {
            RH.OwnerEra memory era = p.eras[e];
            if (
                era.lowerRevision != (e == 0 ? 0 : 1)
                    || era.checkpoint.ownerState.revision
                        != era.lowerRevision + 2 * proposals[e] + era.nativeCount
                    || era.checkpoint.replayCount != 0 || era.checkpoint.replayRoot != 0
                    || era.checkpoint.nonceIndexCount != 0 || era.checkpoint.nonceRoot != 0
            ) _invalid();
            uint64 previous = era.lowerRevision;
            for (uint256 n; n < era.nativeCount; ++n) {
                uint64 revision = p.journal[cursor++].position.point.ownerRevision;
                if (revision <= previous) _invalid();
                previous = revision;
            }
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
