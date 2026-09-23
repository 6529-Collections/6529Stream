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
    StreamArtistBindingLifecycleTypes as L
} from "../../interfaces/stream/artist/StreamArtistBindingLifecycleTypes.sol";
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
import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistPrimaryCollaboratorClocks as Clocks
} from "./StreamArtistPrimaryCollaboratorClocks.sol";
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistCompleteHistoryCatalogue as Catalogue
} from "./StreamArtistCompleteHistoryCatalogue.sol";
import {
    StreamArtistCompleteHistoryBindingLeaves as Leaves
} from "./StreamArtistCompleteHistoryBindingLeaves.sol";
import {
    StreamArtistRecoveredMultipleGenerationGuards as Guards
} from "./StreamArtistRecoveredMultipleGenerationGuards.sol";
import {
    StreamArtistRecoveredMultipleCollectionRows as Native
} from "./StreamArtistRecoveredMultipleCollectionRows.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";

import {
    StreamArtistCompleteHistoryBindingTypes as Types
} from "./StreamArtistCompleteHistoryBindingTypes.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistPrimaryCollaboratorClockBindingProof as Bounds
} from "./StreamArtistPrimaryCollaboratorClockBindingProof.sol";

/// @notice Complete owner0 chronology and replay proof for the combined complete-history inventory.
/// @dev The fixed enclosing profile recomputes CompleteHistoryClocks from all original
/// provenance and Archive. Other families may interleave, but every owner0 write is conserved.
library StreamArtistCompleteHistoryBindingProof {
    bytes32 private constant PROPOSAL = keccak256("binding_lifecycle.replay.proposal_key");
    bytes32 private constant REFUSAL = keccak256("binding_lifecycle.replay.refusal_uniqueness");
    bytes32 private constant WITHDRAWAL =
        keccak256("binding_lifecycle.replay.proposal_terminal_transition_key");

    struct Context {
        uint256[] cursors;
        bool[] completed;
        bool[] aliases;
        uint256[] counts;
        uint256[] nativeCounts;
        uint256[] guards;
        uint256 natives;
    }

    function validate(
        M.State memory scope,
        RH.OwnerProvenance memory p,
        PC.BindingInventory memory inventory,
        PC.Inventory memory archive,
        Clocks.Result memory clocks
    ) public view {
        bytes32 provenance = Provenance.validateOwner(p, 0);
        Catalogue.requireLocal(p, 0, archive.catalogues, archive.operations);
        Types.validate(scope, inventory, provenance);
        if (clocks.clocks.collections.length != scope.collections.length) _invalid();
        Context memory c;
        c.cursors = new uint256[](scope.collections.length);
        c.completed = new bool[](scope.collections.length);
        c.aliases = new bool[](p.aliases.length);
        c.counts = new uint256[](p.eras.length);
        c.nativeCounts = new uint256[](p.eras.length);
        c.guards = new uint256[](p.eras.length);
        for (uint256 k; k < scope.collections.length; ++k) {
            uint256 n = inventory.bindings[k].bindings.rows.length;
            if (
                clocks.clocks.collections[k].proposals.length != n
                    || clocks.clocks.collections[k].completions.length != n
            ) _invalid();
        }
        for (uint256 i; i < archive.operations.length; ++i) {
            H.OperationEvidence memory row = archive.operations[i];
            uint256 era = A.era(p, row.originHash);
            H.Envelope memory e =
                Catalogue.read(p.origins[era], archive.catalogues[era], row.evidence);
            if (e.operation != row.operation) _invalid();
            Bounds.bounds(archive.catalogues[era].lower, archive.catalogues[era].upper, e);
            if (e.operation < 1 || e.operation > 7) {
                // Outside op1..7 owner0 is either absent or an immutable read. A
                // family cannot hide an owner0 write by being skipped here.
                if (keccak256(abi.encode(e.before_[0])) != keccak256(abi.encode(e.after_[0]))) {
                    _invalid();
                }
                continue;
            }
            if (
                e.operation == 5 || e.operation == 6
                    || e.after_[0].revision == e.before_[0].revision
            ) {
                if (keccak256(abi.encode(e.before_[0])) != keccak256(abi.encode(e.after_[0]))) {
                    _invalid();
                }
                continue;
            }
            if (e.after_[0].revision != e.before_[0].revision + 1) _invalid();
            (uint256 k, uint256 g) = _scope(clocks, row.originHash, e);
            CB.Bundle memory b = inventory.bindings[k];
            AH.Query memory q = scope.collections[k];
            A.Generation memory generation = inventory.generations[k][g];
            RH.Point memory point = RH.Point(row.originHash, 0, e.after_[0].revision);
            if (e.after_[0].revision != p.eras[era].lowerRevision + ++c.counts[era]) _invalid();
            if (e.operation == 1) {
                if (
                    g != c.cursors[k]
                        || (g != 0
                            && c.completed[k]
                                != (b.bindings.rows[g - 1].item.accepted
                                        || b.bindings.rows[g - 1].terminal.kind != 0))
                        || generation.generation != g + 1
                        || generation.bindingHash != b.bindings.rows[g].item.bindingHash
                        || generation.accepted != b.bindings.rows[g].item.accepted
                        || keccak256(abi.encode(point))
                            != keccak256(abi.encode(generation.proposal))
                ) _invalid();
                if (
                    g != 0 && !c.completed[k]
                        && (b.corrections[g].recordHash == 0
                            || b.corrections[g].approval.cause != 4)
                ) _invalid();
                Leaves.row(
                    b.bindings.rows[g],
                    q,
                    uint64(g + 1),
                    p.origins[era],
                    inventory.collaborators[k][g]
                );
                Guards.mark(
                    p,
                    c.aliases,
                    PROPOSAL,
                    keccak256(abi.encode(q.collectionId, uint64(g + 1))),
                    generation.bindingHash,
                    point
                );
                ++c.guards[era];
                if (Leaves.correction(b, q, g, p.origins[era])) {
                    Guards.mark(
                        p,
                        c.aliases,
                        CB.ACTION,
                        b.corrections[g].approval.governance.actionId,
                        b.corrections[g].recordHash,
                        point
                    );
                    ++c.guards[era];
                }
                ++c.cursors[k];
                c.completed[k] = false;
            } else {
                if (
                    g + 1 != c.cursors[k] || c.completed[k]
                        || !Clock.beforeOwner(p, 0, generation.proposal, point)
                ) _invalid();
                if (e.operation == 2 || e.operation == 7) {
                    L.Terminal memory empty;
                    if (
                        !generation.accepted
                            || keccak256(abi.encode(b.bindings.rows[g].terminal))
                                != keccak256(abi.encode(empty))
                    ) _invalid();
                } else {
                    L.Terminal memory terminal = b.bindings.rows[g].terminal;
                    if (
                        generation.accepted || terminal.reasonHash == 0
                            || terminal.kind != (e.operation == 3 ? 1 : 2)
                            || (e.operation == 4 && terminal.recordHash != 0)
                            || e.value
                                != (e.operation == 3 ? terminal.recordHash : generation.bindingHash)
                    ) _invalid();
                    Guards.mark(
                        p,
                        c.aliases,
                        e.operation == 3 ? REFUSAL : WITHDRAWAL,
                        keccak256(abi.encode(q.collectionId, uint64(g + 1))),
                        e.value,
                        point
                    );
                    ++c.guards[era];
                }
                c.completed[k] = true;
            }
            if (e.operation == 1 || e.operation == 3) {
                RH.JournalEntry memory native_ = Native.occurrence(
                    p, Types.rowQuery(q, b.bindings.rows[g]), e.operation, e.value
                );
                if (keccak256(abi.encode(native_.position.point)) != keccak256(abi.encode(point))) {
                    _invalid();
                }
                ++c.nativeCounts[era];
                ++c.natives;
            }
        }
        for (uint256 k; k < scope.collections.length; ++k) {
            uint256 n = inventory.bindings[k].bindings.rows.length;
            if (c.cursors[k] != n) _invalid();
            if (n != 0) {
                T.Binding memory last = inventory.bindings[k].bindings.rows[n - 1].item;
                L.Terminal memory terminal = inventory.bindings[k].bindings.rows[n - 1].terminal;
                if (c.completed[k] != (last.accepted || terminal.kind != 0)) _invalid();
            }
        }
        if (c.natives != p.journal.length) _invalid();
        Guards.complete(c.aliases);
        uint256 total;
        for (uint256 e; e < p.eras.length; ++e) {
            total += c.guards[e];
            RH.OwnerEra memory era = p.eras[e];
            if (
                era.lowerRevision != (e == 0 ? 0 : 1) || era.nativeCount != c.nativeCounts[e]
                    || era.checkpoint.ownerState.revision != era.lowerRevision + c.counts[e]
                    || era.checkpoint.replayCount != total
                    || (total == 0 && era.checkpoint.replayRoot != 0)
                    || era.checkpoint.nonceIndexCount != 0 || era.checkpoint.nonceRoot != 0
            ) _invalid();
        }
    }

    // The enclosing fixed proof constructs these clocks from the complete original
    // Archive, not from a caller-selected completion or a latest primary map.
    function _scope(Clocks.Result memory clocks, bytes32 origin, H.Envelope memory e)
        private
        pure
        returns (uint256 collection, uint256 generation)
    {
        bool found;
        for (uint256 k; k < clocks.clocks.collections.length; ++k) {
            for (uint256 g; g < clocks.clocks.collections[k].proposals.length; ++g) {
                RH.Point memory point = e.operation == 1
                    ? clocks.clocks.collections[k].proposals[g]
                    : clocks.clocks.collections[k].completions[g];
                if (
                    point.environmentHash != origin || point.ownerIndex != 0
                        || point.ownerRevision != e.after_[0].revision
                ) continue;
                if (found) _invalid();
                found = true;
                collection = k;
                generation = g;
            }
        }
        if (!found) _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
