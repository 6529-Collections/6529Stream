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
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredPlatformCatalogue as Catalogue
} from "./StreamArtistRecoveredPlatformCatalogue.sol";
import {
    StreamArtistRecoveredMultipleGenerationBindingLeaves as Leaves
} from "./StreamArtistRecoveredMultipleGenerationBindingLeaves.sol";
import {
    StreamArtistRecoveredMultipleGenerationGuards as Guards
} from "./StreamArtistRecoveredMultipleGenerationGuards.sol";
import {
    StreamArtistRecoveredMultipleCollectionRows as Native
} from "./StreamArtistRecoveredMultipleCollectionRows.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";

/// @notice Complete global owner0 rows, exact Archive completion points and retained semantic guards.
/// @dev This fixed owner guard checks its own saved cutoff. Preparation and owner4 independently
/// validate the complete original typed envelopes and every other cutoff before one global apply.
library StreamArtistRecoveredMultipleGenerationBindingProof {
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
        bool multiple;
    }

    function validate(
        M.State memory scope,
        RH.OwnerProvenance memory p,
        G.Inventory memory inventory
    ) public view {
        bytes32 provenance = Provenance.validateOwner(p, 0);
        Catalogue.requireLocal(p, 0, inventory.catalogues, inventory.operations);
        if (
            inventory.bindings.length != scope.collections.length
                || inventory.generations.length != scope.collections.length
        ) _invalid();
        Context memory c;
        c.cursors = new uint256[](scope.collections.length);
        c.completed = new bool[](scope.collections.length);
        c.aliases = new bool[](p.aliases.length);
        c.counts = new uint256[](p.eras.length);
        c.nativeCounts = new uint256[](p.eras.length);
        c.guards = new uint256[](p.eras.length);
        for (uint256 k; k < scope.collections.length; ++k) {
            CB.Bundle memory b = inventory.bindings[k];
            AH.Query memory q = scope.collections[k];
            uint256 n = b.bindings.rows.length;
            if (n > 1) c.multiple = true;
            if (
                n == 0 || n > 128 || inventory.generations[k].length != n
                    || b.corrections.length != n || b.bindings.provenanceCommitment != provenance
                    || b.bindings.artistId != q.artistId
                    || b.bindings.collectionId != q.collectionId
                    || b.bindings.bindingHash != q.bindingHash || !b.bindings.current.accepted
                    || b.bindings.current.bindingHash != q.bindingHash
                    || keccak256(abi.encode(b.bindings.current))
                        != keccak256(abi.encode(b.bindings.rows[n - 1].item))
            ) _invalid();
        }
        for (uint256 i; i < inventory.operations.length; ++i) {
            H.OperationEvidence memory row = inventory.operations[i];
            uint256 era = A.era(p, row.originHash);
            H.Envelope memory e =
                Catalogue.read(p.origins[era], inventory.catalogues[era], row.evidence);
            if (e.operation != row.operation || e.operation < 1 || e.operation > 4) _invalid();
            _snapshots(inventory.catalogues[era], e);
            (uint256 k, uint256 g) = _scope(inventory, p.origins[era], e);
            CB.Bundle memory b = inventory.bindings[k];
            AH.Query memory q = scope.collections[k];
            A.Generation memory generation = inventory.generations[k][g];
            RH.Point memory point = RH.Point(row.originHash, 0, e.after_[0].revision);
            if (e.after_[0].revision != p.eras[era].lowerRevision + ++c.counts[era]) _invalid();
            if (e.operation == 1) {
                if (
                    g != c.cursors[k] || (g != 0 && !c.completed[k])
                        || generation.generation != g + 1
                        || generation.bindingHash != b.bindings.rows[g].item.bindingHash
                        || generation.accepted != b.bindings.rows[g].item.accepted
                        || keccak256(abi.encode(point))
                            != keccak256(abi.encode(generation.proposal))
                ) _invalid();
                Leaves.row(b.bindings.rows[g], q, uint64(g + 1), p.origins[era]);
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
                        || generation.proposal.environmentHash != row.originHash
                        || generation.proposal.ownerRevision >= point.ownerRevision
                ) _invalid();
                if (e.operation == 2) {
                    L.Terminal memory empty;
                    if (
                        !generation.accepted
                            || keccak256(abi.encode(b.bindings.rows[g].terminal))
                                != keccak256(abi.encode(empty))
                    ) _invalid();
                } else {
                    L.Terminal memory terminal = b.bindings.rows[g].terminal;
                    if (
                        generation.accepted || g + 1 == b.bindings.rows.length
                            || terminal.reasonHash == 0
                            || terminal.kind != (e.operation == 3 ? 1 : 2)
                            || (e.operation == 4 && terminal.recordHash != 0)
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
                RH.JournalEntry memory native_ = Native.occurrence(p, q, e.operation, e.value);
                if (keccak256(abi.encode(native_.position.point)) != keccak256(abi.encode(point))) {
                    _invalid();
                }
                ++c.nativeCounts[era];
                ++c.natives;
            }
        }
        for (uint256 k; k < scope.collections.length; ++k) {
            if (!c.completed[k] || c.cursors[k] != inventory.bindings[k].bindings.rows.length) {
                _invalid();
            }
        }
        if (!c.multiple || c.natives != p.journal.length) _invalid();
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
