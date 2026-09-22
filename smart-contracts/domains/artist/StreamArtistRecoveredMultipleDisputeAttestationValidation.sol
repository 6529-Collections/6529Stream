// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationClocks as Clocks
} from "./StreamArtistRecoveredMultipleGenerationClocks.sol";
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
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import { StreamArtistC2PACredentials as Credentials } from "./StreamArtistC2PACredentials.sol";
import {
    StreamArtistRecoveredAttestationHydration as Original
} from "./StreamArtistRecoveredAttestationHydration.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredMultipleCodec as Scope
} from "./StreamArtistRecoveredMultipleCodec.sol";
import {
    StreamArtistRecoveredHistoryRecordRows as Semantic
} from "./StreamArtistRecoveredHistoryRecordRows.sol";
import {
    StreamArtistRecoveredMultipleDisputeTypes as MD
} from "./StreamArtistRecoveredMultipleDisputeTypes.sol";

/// @notice One complete original owner4 semantic inventory; source clocks are checked separately.

library StreamArtistRecoveredMultipleDisputeAttestationValidation {
    function validate(
        M.State memory scope,
        RH.OwnerProvenance memory p,
        G.Inventory memory inventory,
        Clocks.Result memory clocks
    ) public pure returns (Original.Bundle[] memory all) {
        Provenance.validateOwner(p, 4);
        Scope.validate(4, scope, p);
        if (
            p.journal.length > RH.MAX_JOURNAL_ENTRIES
                || inventory.bindings.length != scope.collections.length
                || clocks.collections.length != scope.collections.length
        ) _invalid();
        all = new Original.Bundle[](scope.collections.length);
        uint256 total;
        bytes32 whole = RH.ownerProvenanceHash(p, 4);
        for (uint256 k; k < all.length; ++k) {
            AH.Query memory q = scope.collections[k];
            Original.Bundle memory b = abi.decode(scope.rows[k], (Original.Bundle));
            if (
                keccak256(scope.rows[k]) != keccak256(abi.encode(b)) || b.provenance != whole
                    || b.artistId != q.artistId || b.collectionId != q.collectionId
                    || b.bindingHash != q.bindingHash
                    || (b.item.state != 2 && b.item.state != 4 && b.item.state != 5)
                    || b.item.generation != inventory.bindings[k].bindings.rows.length
                    || b.records.length > 128 || b.personhood.length > 128
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
            else if (!MD.nativeDispute(p.journal[i].receipt.operation)) _invalid();
        }
        if (total != nativeRecords) _invalid();
        uint256[] memory cursors = new uint256[](all.length);
        uint256[] memory summaries = new uint256[](all.length);
        C2PA.Head[] memory heads = new C2PA.Head[](scope.artists.length);
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory entry = p.journal[i];
            if (MD.nativeDispute(entry.receipt.operation)) continue;
            uint256 k = Scope.collection(scope, entry.receipt.collectionId);
            uint256 a = Scope.artist(scope, entry.receipt.artistId);
            if (
                entry.receipt.operation != 24
                    || scope.collections[k].artistId != entry.receipt.artistId
                    || cursors[k] >= all[k].records.length
            ) _invalid();
            PubH.Row memory row = all[k].records[cursors[k]++];
            if (entry.receipt.recordHash != row.attestation.record.recordHash) _invalid();
            for (uint256 j; j < i; ++j) {
                if (p.journal[j].receipt.recordHash == entry.receipt.recordHash) _invalid();
            }
            RH.OriginEnvironment memory o = _origin(p, entry.position.point.environmentHash);
            uint64 generation = row.attestation.record.generation;
            if (generation == 0 || generation > inventory.bindings[k].bindings.rows.length) {
                _invalid();
            }
            T.Binding memory binding_ = inventory.bindings[k].bindings.rows[generation - 1].item;
            if (
                !binding_.accepted || binding_.generation != generation
                    || binding_.artistId != entry.receipt.artistId
                    || !Clock.beforeOwner(
                        p,
                        4,
                        clocks.collections[k].attributionCompletions[generation - 1],
                        entry.position.point
                    )
                    || (generation < inventory.bindings[k].bindings.rows.length
                        && !Clock.beforeOwner(
                            p,
                            4,
                            entry.position.point,
                            clocks.collections[k].attributionProposals[generation]
                        ))
            ) _invalid();
            AH.Query memory historical = AH.Query(
                scope.collections[k].artistId,
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
                heads[a] =
                    _nextHead(heads[a], all[k], row.attestation, o.registry, binding_.bindingHash);
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
        Original.Bundle memory b,
        ReadinessH.AttestationRow memory r,
        address registry,
        bytes32 bindingHash
    ) private pure returns (C2PA.Head memory) {
        C2PA.Payload memory p = Credentials.decode(
            r.statement, b.artistId, r.input.terms.subjectStateHash
        );
        if (p.previousRecordHash != previous.recordHash) _invalid();
        return C2PA.Head(
            previous.revision + 1,
            r.record.recordHash,
            previous.recordHash,
            b.artistId,
            b.collectionId,
            bindingHash,
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

    function _key(T.Attestation memory p) private pure returns (bytes32) {
        return keccak256(abi.encode(p.collectionId, p.subjectKind, p.subjectId));
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
