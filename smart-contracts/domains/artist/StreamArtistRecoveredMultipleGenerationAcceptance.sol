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
    IStreamArtistAcceptanceOwner as Acceptance
} from "../../interfaces/stream/artist/IStreamArtistAcceptanceOwner.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationGuards as Guards
} from "./StreamArtistRecoveredMultipleGenerationGuards.sol";
import {
    StreamArtistRecoveredMultipleCollectionRows as Native
} from "./StreamArtistRecoveredMultipleCollectionRows.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";

/// @notice Every original accepted generation's record/time and its one global owner3 occurrence.
library StreamArtistRecoveredMultipleGenerationAcceptance {
    bytes32 private constant KEY = keccak256("acceptance_lifecycle.replay.record_uniqueness");

    function collect(
        address source,
        M.State memory scope,
        RH.OwnerProvenance memory p,
        G.Inventory memory inventory
    ) public view returns (A.AcceptanceBundle[] memory rows) {
        Provenance.validateOwnerSource(p, 3, source);
        rows = new A.AcceptanceBundle[](scope.collections.length);
        for (uint256 k; k < rows.length; ++k) {
            AH.Query memory q = scope.collections[k];
            A.AcceptanceBundle memory b;
            b.provenance = RH.ownerProvenanceHash(p, 3);
            b.artistId = q.artistId;
            b.collectionId = q.collectionId;
            b.bindingHash = q.bindingHash;
            uint256 count;
            for (uint256 g; g < inventory.generations[k].length; ++g) {
                if (inventory.generations[k][g].accepted) ++count;
            }
            b.rows = new A.Acceptance[](count);
            count = 0;
            for (uint256 g; g < inventory.generations[k].length; ++g) {
                A.Generation memory generation = inventory.generations[k][g];
                if (!generation.accepted) continue;
                b.rows[count++] = A.Acceptance(
                    generation.bindingHash,
                    generation.generation,
                    Acceptance(source).acceptanceRecord(generation.bindingHash),
                    Acceptance(source).acceptedAt(generation.bindingHash)
                );
            }
            rows[k] = b;
        }
        validate(rows, scope, p, inventory);
    }

    function validate(
        A.AcceptanceBundle[] memory rows,
        M.State memory scope,
        RH.OwnerProvenance memory p,
        G.Inventory memory inventory
    ) public pure {
        bytes32 provenance = Provenance.validateOwner(p, 3);
        if (rows.length != scope.collections.length || inventory.generations.length != rows.length) _invalid();
        bool[] memory aliases = new bool[](p.aliases.length);
        uint256 count;
        for (uint256 k; k < rows.length; ++k) {
            A.AcceptanceBundle memory b = rows[k];
            AH.Query memory q = scope.collections[k];
            if (
                b.provenance != provenance || b.artistId != q.artistId
                    || b.collectionId != q.collectionId || b.bindingHash != q.bindingHash
                    || b.rows.length == 0 || b.rows.length > 128
                    || b.rows[b.rows.length - 1].bindingHash != q.bindingHash
            ) _invalid();
            uint256 cursor;
            for (uint256 g; g < inventory.generations[k].length; ++g) {
                A.Generation memory generation = inventory.generations[k][g];
                if (!generation.accepted) continue;
                if (cursor >= b.rows.length) _invalid();
                A.Acceptance memory r = b.rows[cursor++];
                if (
                    r.bindingHash == 0 || r.recordHash == 0 || r.acceptedAt == 0
                        || r.generation != generation.generation
                        || r.bindingHash != generation.bindingHash
                ) _invalid();
                RH.JournalEntry memory native_ = Native.occurrence(p, q, 2, r.recordHash);
                if (native_.position.point.environmentHash != generation.proposal.environmentHash) {
                    _invalid();
                }
                bytes32 originalScope;
                for (uint256 i; i < p.aliases.length; ++i) {
                    RH.ReplayAlias memory a = p.aliases[i];
                    if (a.surface != KEY || a.cell.commitment != r.recordHash) continue;
                    if (a.scope == 0 || (originalScope != 0 && originalScope != a.scope)) {
                        _invalid();
                    }
                    originalScope = a.scope;
                }
                if (originalScope == 0) _invalid();
                Guards.mark(p, aliases, KEY, originalScope, r.recordHash, native_.position.point);
                ++count;
            }
            if (cursor != b.rows.length) _invalid();
        }
        if (count != p.journal.length) _invalid();
        Guards.complete(aliases);
        uint256 total;
        uint256 cursor;
        for (uint256 e; e < p.eras.length; ++e) {
            RH.OwnerEra memory era = p.eras[e];
            total += era.nativeCount;
            if (
                era.lowerRevision != (e == 0 ? 0 : 1)
                    || era.checkpoint.ownerState.revision != era.lowerRevision + era.nativeCount
                    || era.checkpoint.replayCount != total
                    || (total == 0 && era.checkpoint.replayRoot != 0)
                    || era.checkpoint.nonceIndexCount != 0 || era.checkpoint.nonceRoot != 0
            ) _invalid();
            for (uint256 j; j < era.nativeCount; ++j) {
                if (p.journal[cursor++].position.point.ownerRevision != era.lowerRevision + j + 1) {
                    _invalid();
                }
            }
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
