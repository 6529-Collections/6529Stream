// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredBindingGenerations as Generations
} from "./StreamArtistRecoveredBindingGenerations.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationChronology as Chronology
} from "./StreamArtistRecoveredHydrationChronology.sol";

/// @notice Slim linked worker joining pending-generation records to original Identity evidence.
/// @dev The facade projects every field consumed by the original validator. Complete source
/// provenance and fixed-owner codec authentication remain prerequisites.
library StreamArtistRecoveredBindingGenerationFactRows {
    struct IdentityRows {
        bytes32 artistId;
        IH.DocumentRow[] documents;
        IH.SignatureRow[] signatures;
    }

    struct Scope {
        bytes32 artistId;
        uint256 collectionId;
        bytes32 bindingHash;
    }

    function validateRows(
        IdentityRows memory identity,
        Generations.Bundle memory bindings,
        Scope memory q,
        RH.Provenance memory p
    ) public pure {
        uint256 count = bindings.rows.length;
        if (
            q.artistId == 0 || q.collectionId == 0 || q.bindingHash == 0
                || identity.artistId != q.artistId || bindings.artistId != q.artistId
                || bindings.collectionId != q.collectionId || bindings.bindingHash != q.bindingHash
                || count < 2 || count > 128 || bindings.current.generation != count
                || bindings.current.bindingHash != q.bindingHash || !bindings.current.accepted
                || keccak256(abi.encode(bindings.current))
                    != keccak256(abi.encode(bindings.rows[count - 1].item))
                || p.journals[3].length != 1
        ) _invalid();

        // Only complete original op24 history can extend this final accepted generation.
        // Its complete typed records and original Identity admissions are joined separately
        // before any import. Disputes, corrections and other attribution mutations stay refused.
        for (uint256 i; i < p.journals[4].length; ++i) {
            RH.JournalEntry memory row = p.journals[4][i];
            if (
                row.receipt.operation != 24 || row.receipt.artistId != q.artistId
                    || row.receipt.collectionId != q.collectionId
                    || row.position.point.ownerIndex != 4
            ) _invalid();
            Chronology.validatePoint(p, row.position.point);
        }

        RH.Point memory finalProposal;
        for (uint256 i; i < count; ++i) {
            Generations.Row memory row = bindings.rows[i];
            if (row.item.artistId != q.artistId || row.item.generation != i + 1) _invalid();
            _document(identity, row.item.identityRecordHash);
            RH.Point memory proposal = _occurrence(p, 0, 1, row.item.bindingHash, q);
            if (i + 1 == count) {
                finalProposal = proposal;
            } else if (row.terminal.kind == 1) {
                RH.Point memory refusal = _occurrence(p, 0, 3, row.terminal.recordHash, q);
                if (!Chronology.before(p, proposal, refusal)) _invalid();
                _signature(identity, row.terminal.recordHash);
            } else if (row.terminal.kind != 2 || row.terminal.recordHash != 0) {
                _invalid();
            }
        }

        RH.JournalEntry memory accepted = p.journals[3][0];
        RH.Point memory acceptance = _occurrence(p, 3, 2, accepted.receipt.recordHash, q);
        // Binding and Acceptance have independent revision counters. Their original producer
        // joins are authenticated by the fixed-source maps; only their origin must agree here.
        if (acceptance.environmentHash != finalProposal.environmentHash) _invalid();
        _signature(identity, accepted.receipt.recordHash);

        // Original2/3 Identity authorization commits no native receipt. Refusal's native row
        // belongs to Binding, and final acceptance's belongs to Acceptance, never Identity.
        for (uint256 i; i < p.journals[2].length; ++i) {
            uint16 operation = p.journals[2][i].receipt.operation;
            if (operation == 2 || operation == 3 || operation == 4) _invalid();
        }
    }

    function _document(IdentityRows memory identity, bytes32 hash) private pure {
        if (hash == 0) _invalid();
        bool found;
        for (uint256 i; i < identity.documents.length; ++i) {
            if (identity.documents[i].documentHash != hash) continue;
            if (found || keccak256(identity.documents[i].document) != hash) _invalid();
            found = true;
        }
        // The original registration document and every previous/revised original25 document
        // survive in this exact source-authenticated set, even when no longer operative.
        if (!found) _invalid();
    }

    function _signature(IdentityRows memory identity, bytes32 record) private pure {
        bool found;
        for (uint256 i; i < identity.signatures.length; ++i) {
            if (identity.signatures[i].recordHash != record) continue;
            if (found || identity.signatures[i].signature.length > 4096) _invalid();
            found = true;
        }
        // Empty direct/Safe evidence and nonempty opaque signatures are both retained exactly.
        if (!found) _invalid();
    }

    function _occurrence(
        RH.Provenance memory p,
        uint8 ownerIndex,
        uint16 operation,
        bytes32 record,
        Scope memory q
    ) private pure returns (RH.Point memory point) {
        if (record == 0) _invalid();
        bool found;
        for (uint256 i; i < p.journals[ownerIndex].length; ++i) {
            RH.JournalEntry memory row = p.journals[ownerIndex][i];
            if (row.receipt.recordHash != record) continue;
            if (
                found || row.receipt.operation != operation || row.receipt.artistId != q.artistId
                    || row.receipt.collectionId != q.collectionId
                    || row.position.point.ownerIndex != ownerIndex
            ) _invalid();
            Chronology.validatePoint(p, row.position.point);
            point = row.position.point;
            found = true;
        }
        if (!found) _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
