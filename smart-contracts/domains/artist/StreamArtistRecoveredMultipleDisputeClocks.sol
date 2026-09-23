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
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
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
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredMultipleDisputeCatalogue as Catalogue
} from "./StreamArtistRecoveredMultipleDisputeCatalogue.sol";
import {
    StreamArtistRecoveredPlatformProposalProofKernel as Proposal
} from "./StreamArtistRecoveredPlatformProposalProofKernel.sol";
import {
    StreamArtistRecoveredMultipleGenerationCompletionProof as Completion
} from "./StreamArtistRecoveredMultipleGenerationCompletionProof.sol";
import {
    StreamArtistRecoveredMultipleDisputeBindingLeaves as Leaves
} from "./StreamArtistRecoveredMultipleDisputeBindingLeaves.sol";
import {
    StreamArtistRecoveredMultipleCollectionRows as Native
} from "./StreamArtistRecoveredMultipleCollectionRows.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistRecoveredMultipleGenerationClocks as OriginalClocks
} from "./StreamArtistRecoveredMultipleGenerationClocks.sol";

/// @notice Complete original Archive proposal/completion history indexed by collection and generation.
/// @dev Retains the complete catalogue and all seven original cutoffs. No owner's revision is
/// compared with another owner's revision, and a collection's subsequence is never renumbered.

library StreamArtistRecoveredMultipleDisputeClocks {
    struct Context {
        P.Cursor[] cursors;
        uint256 previousEra;
        uint64 previousRevision;
        uint256 total;
    }

    function collect(
        RH.Provenance memory p,
        M.State memory scope,
        CB.Bundle[] memory bindings,
        A.Generation[][] memory generations
    ) public view returns (G.Inventory memory inventory, OriginalClocks.Result memory result) {
        (inventory.catalogues, inventory.operations) = Catalogue.collect(p);
        inventory.bindings = bindings;
        inventory.generations = generations;
        RH.OwnerProvenance memory owner4 = RH.ownerProvenance(p, 4);
        result = validateLocal(scope, owner4, inventory);
        for (uint256 i; i < inventory.operations.length; ++i) {
            H.OperationEvidence memory row = inventory.operations[i];
            if (row.operation > 4) continue;
            uint256 era = A.era(owner4, row.originHash);
            H.Envelope memory e =
                Catalogue.read(p.origins[era], inventory.catalogues[era], row.evidence);
            (uint256 k,) = _scope(inventory, p.origins[era], e);
            if (e.operation == 4) continue; // Original withdrawal has no native occurrence.
            uint8 owner = e.operation == 2 ? 3 : 0;
            RH.JournalEntry memory native_ = Native.occurrence(
                RH.ownerProvenance(p, owner), scope.collections[k], e.operation, e.value
            );
            if (
                native_.position.point.environmentHash != row.originHash
                    || native_.position.point.ownerRevision != e.after_[owner].revision
            ) _invalid();
        }
    }

    function validateLocal(
        M.State memory scope,
        RH.OwnerProvenance memory p,
        G.Inventory memory inventory
    ) public view returns (OriginalClocks.Result memory r) {
        Catalogue.requireLocal(p, 4, inventory.catalogues, inventory.operations);
        if (
            inventory.bindings.length != scope.collections.length
                || inventory.generations.length != scope.collections.length
        ) _invalid();
        r.collections = new G.Timeline[](scope.collections.length);
        r.counts = new uint256[](p.eras.length);
        Context memory c;
        c.cursors = new P.Cursor[](scope.collections.length);
        for (uint256 k; k < scope.collections.length; ++k) {
            AH.Query memory q = scope.collections[k];
            CB.Bundle memory b = inventory.bindings[k];
            uint256 n = inventory.generations[k].length;
            if (
                n == 0 || n > 128 || b.bindings.rows.length != n || b.corrections.length != n
                    || b.bindings.artistId != q.artistId
                    || b.bindings.collectionId != q.collectionId
                    || b.bindings.bindingHash != q.bindingHash || !b.bindings.current.accepted
                    || b.bindings.current.bindingHash != q.bindingHash
                    || keccak256(abi.encode(b.bindings.current))
                        != keccak256(abi.encode(b.bindings.rows[n - 1].item))
            ) _invalid();
            r.collections[k].proposals = new RH.Point[](n);
            r.collections[k].completions = new RH.Point[](n);
            r.collections[k].attributionProposals = new RH.Point[](n);
            r.collections[k].attributionCompletions = new RH.Point[](n);
            c.total += n;
        }

        for (uint256 i; i < inventory.operations.length; ++i) {
            H.OperationEvidence memory row = inventory.operations[i];
            if (row.operation > 4) continue;
            uint256 era = A.era(p, row.originHash);
            H.Envelope memory e =
                Catalogue.read(p.origins[era], inventory.catalogues[era], row.evidence);
            if (
                row.operation != e.operation || e.operation < 1 || e.operation > 4
                    || era < c.previousEra
                    || (i != 0
                        && era == c.previousEra
                        && e.after_[4].revision <= c.previousRevision)
            ) _invalid();
            c.previousEra = era;
            c.previousRevision = e.after_[4].revision;
            _snapshots(inventory.catalogues[era], e);
            (uint256 k, uint256 g) = _scope(inventory, p.origins[era], e);
            P.Platform memory platform;
            platform.collectionId = scope.collections[k].collectionId;
            A.Generation memory generation = inventory.generations[k][g];
            RH.Point memory point = RH.Point(row.originHash, 4, e.after_[4].revision);
            if (e.operation == 1) {
                if (
                    g != c.cursors[k].generation || generation.generation != g + 1
                        || generation.bindingHash
                            != inventory.bindings[k].bindings.rows[g].item.bindingHash
                        || generation.accepted
                            != inventory.bindings[k].bindings.rows[g].item.accepted
                        || generation.proposal.ownerIndex != 0
                ) _invalid();
                Leaves.row(
                    inventory.bindings[k].bindings.rows[g],
                    scope.collections[k],
                    uint64(g + 1),
                    p.origins[era]
                );
                Leaves.correction(inventory.bindings[k], scope.collections[k], g, p.origins[era]);
                c.cursors[k] = Proposal.advance(
                    platform,
                    inventory.bindings[k],
                    inventory.generations[k],
                    c.cursors[k],
                    p,
                    era,
                    e,
                    true
                );
                r.collections[k].proposals[g] = RH.Point(row.originHash, 0, e.after_[0].revision);
                r.collections[k].attributionProposals[g] = point;
            } else {
                if (
                    g + 1 != c.cursors[k].generation
                        || !Clock.beforeOwner(p, 4, r.collections[k].attributionProposals[g], point)
                ) _invalid();
                c.cursors[k] = Completion.advance(
                    platform,
                    inventory.bindings[k],
                    inventory.generations[k],
                    c.cursors[k],
                    p,
                    era,
                    e,
                    true
                );
                r.collections[k].completions[g] = RH.Point(row.originHash, 0, e.after_[0].revision);
                r.collections[k].attributionCompletions[g] = point;
            }
            ++r.counts[era];
            for (uint256 j; j < p.journal.length; ++j) {
                RH.Point memory other = p.journal[j].position.point;
                if (
                    point.environmentHash == other.environmentHash
                        && point.ownerRevision == other.ownerRevision
                ) _invalid();
            }
        }
        for (uint256 k; k < scope.collections.length; ++k) {
            if (
                c.cursors[k].generation != inventory.generations[k].length
                    || !c.cursors[k].completed
            ) _invalid();
        }
    }

    function _scope(
        G.Inventory memory inventory,
        RH.OriginEnvironment memory o,
        H.Envelope memory e
    ) private view returns (uint256 collection, uint256 generation) {
        bool found;
        for (uint256 k; k < inventory.bindings.length; ++k) {
            CB.Bundle memory b = inventory.bindings[k];
            for (uint256 g; g < b.bindings.rows.length; ++g) {
                bytes32 hash = e.operation == 2
                    ? Acceptance(o.owners[3]).acceptanceRecord(b.bindings.rows[g].item.bindingHash)
                    : e.operation == 3
                        ? b.bindings.rows[g].terminal.recordHash
                        : b.bindings.rows[g].item.bindingHash;
                if (hash == 0 || hash != e.value) continue;
                if (found) _invalid();
                found = true;
                collection = k;
                generation = g;
            }
        }
        if (!found) _invalid();
    }

    function _snapshots(P.Catalogue memory c, H.Envelope memory e) private pure {
        uint256 mask = e.operation == 2 ? 0x1f : e.operation == 4 ? 0x11 : 0x15;
        T.Snapshot memory zero;
        for (uint8 i; i < 7; ++i) {
            T.Snapshot memory before_ = e.before_[i];
            T.Snapshot memory after_ = e.after_[i];
            if ((mask & (1 << i)) == 0) {
                if (
                    keccak256(abi.encode(before_)) != keccak256(abi.encode(zero))
                        || keccak256(abi.encode(after_)) != keccak256(abi.encode(zero))
                ) _invalid();
            } else {
                if (
                    before_.domainId != RH.ownerDomain(i) || after_.domainId != RH.ownerDomain(i)
                        || before_.stateRoot == 0 || before_.recordChainTip == 0
                        || after_.stateRoot == 0 || after_.recordChainTip == 0
                        || before_.revision < c.lower[i] || after_.revision > c.upper[i]
                        || after_.revision < before_.revision
                        || after_.revision > before_.revision + 1
                ) {
                    _invalid();
                }
                if (i == 1 || (i == 2 && e.operation == 1 && after_.revision == before_.revision)) {
                    if (keccak256(abi.encode(before_)) != keccak256(abi.encode(after_))) {
                        _invalid();
                    }
                } else if (after_.revision != before_.revision + 1) {
                    _invalid();
                }
            }
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
