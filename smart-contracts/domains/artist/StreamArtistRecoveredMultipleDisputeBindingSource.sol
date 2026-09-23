// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistBindingLifecycleTypes as L
} from "../../interfaces/stream/artist/StreamArtistBindingLifecycleTypes.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistCollaboratorBindingOwner as Terms
} from "../../interfaces/stream/artist/IStreamArtistCollaboratorBindingOwner.sol";
import {
    IStreamArtistBindingLifecycle as Lifecycle
} from "../../interfaces/stream/artist/IStreamArtistBindingLifecycle.sol";
import {
    IStreamArtistBindingCorrectionOwner as Corrections
} from "../../interfaces/stream/artist/IStreamArtistBindingCorrection.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredBindingGenerations as G
} from "./StreamArtistRecoveredBindingGenerations.sol";
import { StreamArtistBindingCorrectionState as CS } from "./StreamArtistBindingCorrectionState.sol";
import {
    StreamArtistRecoveredHydrationProvenance as P
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistRecoveredMultipleDisputeBindingLeaves as Leaves
} from "./StreamArtistRecoveredMultipleDisputeBindingLeaves.sol";

/// @notice Every original selected binding row and native occurrence, without renumbering a collection slice.
/// @dev Complete counters, aliases and non-native completion clocks are joined by the aggregate
/// timeline before import. This collector never substitutes a filtered owner provenance.
library StreamArtistRecoveredMultipleDisputeBindingSource {
    struct Collected {
        CB.Bundle[] bindings;
        A.Generation[][] generations;
    }

    function collect(address source, M.State memory scope, RH.OwnerProvenance memory p)
        public
        view
        returns (Collected memory result)
    {
        P.validateOwnerSource(p, 0, source);
        result.bindings = new CB.Bundle[](scope.collections.length);
        result.generations = new A.Generation[][](scope.collections.length);
        bool[] memory covered = new bool[](p.journal.length);
        bytes32 provenance = RH.ownerProvenanceHash(p, 0);
        for (uint256 k; k < scope.collections.length; ++k) {
            AH.Query memory q = scope.collections[k];
            CB.Bundle memory b;
            b.bindings.artistId = q.artistId;
            b.bindings.collectionId = q.collectionId;
            b.bindings.bindingHash = q.bindingHash;
            b.bindings.provenanceCommitment = provenance;
            b.bindings.current = Binding(source).binding(q.collectionId);
            uint256 n = b.bindings.current.generation;
            if (
                n == 0 || n > 128 || !b.bindings.current.accepted
                    || b.bindings.current.artistId != q.artistId
                    || b.bindings.current.bindingHash != q.bindingHash
            ) _invalid();
            b.bindings.rows = new G.Row[](n);
            b.corrections = new CS.Correction[](n);
            A.Generation[] memory generations = new A.Generation[](n);
            for (uint256 i; i < n; ++i) {
                uint64 generation = uint64(i + 1);
                G.Row memory row = G.Row(
                    Binding(source).bindingAt(q.collectionId, generation),
                    Terms(source).bindingTerms(q.collectionId, generation),
                    Lifecycle(source).bindingTermination(q.collectionId, generation)
                );
                RH.Point memory proposal = _native(p, covered, q, 1, row.item.bindingHash);
                if (i != 0 && !Clock.beforeOwner(p, 0, generations[i - 1].proposal, proposal)) {
                    _invalid();
                }
                Leaves.row(row, q, generation, p.origins[A.era(p, proposal.environmentHash)]);
                b.bindings.rows[i] = row;
                (b.corrections[i].approval, b.corrections[i].recordHash) =
                    Corrections(source).bindingCorrection(row.item.bindingHash);
                generations[i] =
                    A.Generation(row.item.bindingHash, generation, row.item.accepted, proposal);
                if (row.item.accepted) {
                    L.Terminal memory empty;
                    if (keccak256(abi.encode(row.terminal)) != keccak256(abi.encode(empty))) {
                        _invalid();
                    }
                } else {
                    if (
                        i + 1 == n || row.terminal.kind > 2
                            || (row.terminal.kind != 0 && row.terminal.reasonHash == 0)
                    ) _invalid();
                    if (row.terminal.kind == 0) {
                        L.Terminal memory empty;
                        if (keccak256(abi.encode(row.terminal)) != keccak256(abi.encode(empty))) {
                            _invalid();
                        }
                    }
                    if (row.terminal.kind == 1) {
                        RH.Point memory refusal = _native(p, covered, q, 3, row.terminal.recordHash);
                        if (
                            refusal.environmentHash != proposal.environmentHash
                                || !Clock.beforeOwner(p, 0, proposal, refusal)
                        ) _invalid();
                    } else if (row.terminal.recordHash != 0) {
                        _invalid();
                    }
                }
            }
            if (
                keccak256(abi.encode(b.bindings.current))
                    != keccak256(abi.encode(b.bindings.rows[n - 1].item))
            ) _invalid();
            for (uint256 i; i < n; ++i) {
                Leaves.correction(
                    b, q, i, p.origins[A.era(p, generations[i].proposal.environmentHash)]
                );
                // A pending generation has no owner0 completion. Its original arbiter
                // revocation is proved in owner4 and must be the next correction's cause.
                if (
                    i + 1 < n && !generations[i].accepted && b.bindings.rows[i].terminal.kind == 0
                        && (b.corrections[i + 1].recordHash == 0
                            || b.corrections[i + 1].approval.cause != 4)
                ) _invalid();
                if (
                    i + 1 < n
                        && generations[i].proposal.environmentHash
                            != generations[i + 1].proposal.environmentHash
                        && !generations[i].accepted
                ) _invalid();
            }
            result.bindings[k] = b;
            result.generations[k] = generations;
        }
        for (uint256 i; i < covered.length; ++i) {
            if (!covered[i]) _invalid();
        }
    }

    function _native(
        RH.OwnerProvenance memory p,
        bool[] memory covered,
        AH.Query memory q,
        uint16 operation,
        bytes32 record
    ) private pure returns (RH.Point memory point) {
        if (record == 0) _invalid();
        bool found;
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory row = p.journal[i];
            if (row.receipt.recordHash != record) continue;
            if (
                found || covered[i] || row.receipt.operation != operation
                    || row.receipt.artistId != q.artistId
                    || row.receipt.collectionId != q.collectionId
            ) _invalid();
            Clock.validateOwnerPoint(p, 0, row.position.point);
            point = row.position.point;
            covered[i] = true;
            found = true;
        }
        if (!found) _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
