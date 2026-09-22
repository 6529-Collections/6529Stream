// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistCompleteHistoryTypes as CT } from "./StreamArtistCompleteHistoryTypes.sol";
import {
    StreamArtistPrimaryCollaboratorClocks as Clocks
} from "./StreamArtistPrimaryCollaboratorClocks.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistReadinessHydrationTypes as ReadinessH
} from "../../interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    StreamArtistPublicationHydrationTypes as PubH
} from "../../interfaces/stream/artist/IStreamArtistPublicationAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistC2PATypes as C2PA
} from "../../interfaces/stream/artist/IStreamArtistC2PA.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import { StreamArtistC2PACredentials as Credentials } from "./StreamArtistC2PACredentials.sol";
import {
    StreamArtistRecoveredAttestationHydration as Original
} from "./StreamArtistRecoveredAttestationHydration.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import { StreamArtistCompleteHistoryScope as Scope } from "./StreamArtistCompleteHistoryScope.sol";
import {
    StreamArtistRecoveredHistoryRecordRows as Semantic
} from "./StreamArtistRecoveredHistoryRecordRows.sol";
import {
    StreamArtistCompleteHistoryAttestationQueries as Queries
} from "./StreamArtistCompleteHistoryAttestationQueries.sol";
import {
    StreamArtistCompleteHistoryBindingTypes as Bindings
} from "./StreamArtistCompleteHistoryBindingTypes.sol";

/// @notice Original op24 rows joined to each genuine historical principal and binding clock.
/// @dev The separate dispute/sanction proof authenticates the final Attribution status. This
/// family does not infer current mint eligibility from historical attestations or accepted rows.

library StreamArtistCompleteHistoryAttestationValidation {
    function validate(
        M.State memory scope,
        CT.Inventory memory inventory,
        Clocks.Result memory clocks,
        bytes[] memory rows
    ) public pure returns (Original.Bundle[] memory all) {
        RH.OwnerProvenance memory p = RH.ownerProvenance(inventory.provenance, 4);
        Provenance.validateOwner(p, 4);
        Bindings.validate(
            scope,
            inventory.bindings,
            RH.ownerProvenanceHash(RH.ownerProvenance(inventory.provenance, 0), 0)
        );
        M.State memory selected = Queries.project(scope, p);
        if (
            p.journal.length > RH.MAX_JOURNAL_ENTRIES || rows.length != scope.collections.length
                || clocks.clocks.collections.length != scope.collections.length
        ) _invalid();
        all = new Original.Bundle[](scope.collections.length);
        uint256 total;
        bytes32 whole = RH.ownerProvenanceHash(p, 4);
        for (uint256 k; k < all.length; ++k) {
            AH.Query memory q = selected.collections[k];
            Original.Bundle memory b = abi.decode(rows[k], (Original.Bundle));
            if (
                keccak256(rows[k]) != keccak256(abi.encode(b)) || b.provenance != whole
                    || b.artistId != q.artistId || b.collectionId != q.collectionId
                    || b.bindingHash != q.bindingHash || b.item.state > 5
                    || (q.artistId == 0 ? b.item.state != 0 : b.item.state == 0)
                    || b.item.generation != inventory.bindings.bindings[k].bindings.rows.length
                    || clocks.clocks.collections[k].attributionProposals.length != b.item.generation
                    || clocks.clocks.collections[k].attributionCompletions.length
                        != b.item.generation || b.records.length > 128 || b.personhood.length > 128
                    || b.records.length != q.records.length
            ) _invalid();
            for (uint256 i; i < b.records.length; ++i) {
                if (q.records[i] != b.records[i].attestation.record.recordHash) _invalid();
            }
            all[k] = b;
            total += b.records.length;
        }
        uint256 nativeRecords;
        for (uint256 i; i < p.journal.length; ++i) {
            if (p.journal[i].receipt.operation == 24) ++nativeRecords;
            else if (!Queries.other(p.journal[i].receipt)) _invalid();
        }
        if (total != nativeRecords) _invalid();
        uint256[] memory cursors = new uint256[](all.length);
        uint256[] memory summaries = new uint256[](all.length);
        C2PA.Head[] memory heads = new C2PA.Head[](scope.artists.length);
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory entry = p.journal[i];
            if (Queries.other(entry.receipt)) continue;
            uint256 k = Scope.collection(scope, entry.receipt.collectionId);
            uint256 a = Scope.artist(scope, entry.receipt.artistId);
            if (entry.receipt.operation != 24 || cursors[k] >= all[k].records.length) _invalid();
            PubH.Row memory row = all[k].records[cursors[k]++];
            if (entry.receipt.recordHash != row.attestation.record.recordHash) _invalid();
            for (uint256 j; j < i; ++j) {
                if (p.journal[j].receipt.recordHash == entry.receipt.recordHash) _invalid();
            }
            RH.OriginEnvironment memory o = _origin(p, entry.position.point.environmentHash);
            uint64 generation = row.attestation.record.generation;
            if (generation == 0 || generation > inventory.bindings.bindings[k].bindings.rows.length)
            {
                _invalid();
            }
            T.Binding memory binding_ =
            inventory.bindings.bindings[k].bindings.rows[generation - 1].item;
            if (
                !binding_.accepted || binding_.generation != generation
                    || binding_.artistId != entry.receipt.artistId
                    || !Clock.beforeOwner(
                        p,
                        4,
                        clocks.clocks.collections[k].attributionCompletions[generation - 1],
                        entry.position.point
                    )
                    || (generation < inventory.bindings.bindings[k].bindings.rows.length
                        && !Clock.beforeOwner(
                            p,
                            4,
                            entry.position.point,
                            clocks.clocks.collections[k].attributionProposals[generation]
                        ))
            ) _invalid();
            AH.Query memory historical = AH.Query(
                binding_.artistId,
                scope.collections[k].collectionId,
                binding_.bindingHash,
                scope.collections[k].policies,
                scope.collections[k].records
            );
            Semantic.validateRow(historical, o, row, generation);
            if (_personhood(row.attestation.input.terms)) {
                if (summaries[k] >= all[k].personhood.length) _invalid();
                Semantic.validateSummary(
                    historical, o, row.attestation, all[k].personhood[summaries[k]++], generation
                );
            }
            if (_credential(row.attestation.input.terms)) {
                heads[a] = _nextHead(heads[a], historical, row.attestation, o.registry);
            }
        }
        for (uint256 k; k < all.length; ++k) {
            if (cursors[k] != all[k].records.length || summaries[k] != all[k].personhood.length) {
                _invalid();
            }
        }
    }

    function _nextHead(
        C2PA.Head memory previous,
        AH.Query memory historical,
        ReadinessH.AttestationRow memory r,
        address registry
    ) private pure returns (C2PA.Head memory) {
        C2PA.Payload memory p = Credentials.decode(
            r.statement, historical.artistId, r.input.terms.subjectStateHash
        );
        if (p.previousRecordHash != previous.recordHash) _invalid();
        return C2PA.Head(
            previous.revision + 1,
            r.record.recordHash,
            previous.recordHash,
            historical.artistId,
            historical.collectionId,
            historical.bindingHash,
            r.record.generation,
            r.record.subjectStateHash,
            r.record.statementHash,
            registry
        );
    }

    function _origin(RH.OwnerProvenance memory p, bytes32 hash)
        private
        pure
        returns (RH.OriginEnvironment memory)
    {
        for (uint256 i; i < p.eras.length; ++i) {
            if (p.eras[i].originHash == hash) return p.origins[i];
        }
        _invalid();
    }

    function _personhood(T.Attestation memory p) private pure returns (bool) {
        return p.subjectKind == 10 && Credentials.isPersonhood(p.schemaId);
    }

    function _credential(T.Attestation memory p) private pure returns (bool) {
        return p.subjectKind == 10 && p.schemaId == Credentials.SCHEMA;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
