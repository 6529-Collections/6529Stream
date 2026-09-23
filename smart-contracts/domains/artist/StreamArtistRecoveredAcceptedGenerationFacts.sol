// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredBindingGenerations as Generations
} from "./StreamArtistRecoveredBindingGenerations.sol";
import {
    StreamArtistRecoveredHydrationChronology as Chronology
} from "./StreamArtistRecoveredHydrationChronology.sol";

/// @notice Original Identity evidence for every accepted/refused binding, not only the latest row.
/// @dev Source collectors already authenticate all semantic owners and complete nonce inventories.
library StreamArtistRecoveredAcceptedGenerationFacts {
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

    function validate(
        IH.Bundle calldata identity,
        Generations.Bundle calldata bindings,
        AH.Query calldata query,
        RH.Provenance calldata provenance
    ) public pure {
        _rows(
            IdentityRows(identity.artistId, identity.documents, identity.signatures),
            bindings,
            Scope(query.artistId, query.collectionId, query.bindingHash),
            provenance
        );
    }

    function _rows(
        IdentityRows memory identity,
        Generations.Bundle memory bindings,
        Scope memory q,
        RH.Provenance memory p
    ) private pure {
        if (
            identity.artistId != q.artistId || bindings.artistId != q.artistId
                || bindings.collectionId != q.collectionId || bindings.bindingHash != q.bindingHash
                || bindings.rows.length < 2 || bindings.rows.length > 128
                || !bindings.current.accepted || bindings.current.bindingHash != q.bindingHash
        ) _invalid();
        uint256 accepted;
        for (uint256 i; i < bindings.rows.length; ++i) {
            Generations.Row memory row = bindings.rows[i];
            if (row.item.artistId != q.artistId || row.item.generation != i + 1) _invalid();
            _document(identity, row.item.identityRecordHash);
            RH.Point memory proposal = _occurrence(p, 0, 1, row.item.bindingHash, q);
            if (row.item.accepted) {
                if (accepted >= p.journals[3].length) _invalid();
                RH.JournalEntry memory j = p.journals[3][accepted++];
                RH.Point memory point = _occurrence(p, 3, 2, j.receipt.recordHash, q);
                if (point.environmentHash != proposal.environmentHash) _invalid();
                _signature(identity, j.receipt.recordHash);
            } else if (row.terminal.kind == 1) {
                RH.Point memory refusal = _occurrence(p, 0, 3, row.terminal.recordHash, q);
                if (!Chronology.before(p, proposal, refusal)) _invalid();
                _signature(identity, row.terminal.recordHash);
            } else if (row.terminal.kind != 2 || row.terminal.recordHash != 0) {
                _invalid();
            }
        }
        if (accepted != p.journals[3].length || accepted < 2) _invalid();
        for (uint256 i; i < p.journals[2].length; ++i) {
            uint16 op = p.journals[2][i].receipt.operation;
            if (op == 2 || op == 3 || op == 4 || op == 44 || op == 45 || op == 47) _invalid();
        }
        for (uint256 i; i < p.journals[4].length; ++i) {
            RH.JournalEntry memory j = p.journals[4][i];
            if (
                j.receipt.operation != 44 || j.receipt.artistId != q.artistId
                    || j.receipt.collectionId != q.collectionId
            ) _invalid();
            Chronology.validatePoint(p, j.position.point);
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
