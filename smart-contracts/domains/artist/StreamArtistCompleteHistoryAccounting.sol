// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import { StreamArtistCompleteHistoryTypes as C } from "./StreamArtistCompleteHistoryTypes.sol";
import {
    StreamArtistPrimaryCollaboratorClocks as PCClocks
} from "./StreamArtistPrimaryCollaboratorClocks.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistCompleteHistoryCatalogue as Catalogue
} from "./StreamArtistCompleteHistoryCatalogue.sol";
import {
    StreamArtistCompleteHistoryPlatformProof as Platform
} from "./StreamArtistCompleteHistoryPlatformProof.sol";
import {
    StreamArtistRecoveredDisputeHistoryGuards as Disputes
} from "./StreamArtistRecoveredDisputeHistoryGuards.sol";
import {
    StreamArtistRecoveredSanctionConfirmationProof as Confirmation
} from "./StreamArtistRecoveredSanctionConfirmationProof.sol";
import {
    StreamArtistRecoveredMultipleGenerationGuards as Aliases
} from "./StreamArtistRecoveredMultipleGenerationGuards.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";

/// @notice One whole-owner4 mutation and replay-cell bijection across the admitted families.
/// @dev Family row/hash/standing validation precedes this accounting. Every native, binding,
/// resolution, repudiation-terminal and original13 write has a distinct original local clock.
library StreamArtistCompleteHistoryAccounting {
    struct Work {
        bool[] aliases;
        uint256[] cells;
        RH.Point[] points;
        uint256 count;
    }

    function validate(
        C.Inventory memory inventory,
        PCClocks.Result memory clocks,
        D.Bundle[] memory histories
    ) public view {
        RH.OwnerProvenance memory p = RH.ownerProvenance(inventory.provenance, 4);
        Provenance.validateOwner(p, 4);
        uint256 n = inventory.bindings.bindings.length;
        if (
            histories.length != n || inventory.platforms.length != n
                || clocks.clocks.collections.length != n
                || clocks.clocks.counts.length != p.eras.length
        ) _invalid();
        uint256 bound = p.journal.length + inventory.archive.operations.length;
        for (uint256 k; k < n; ++k) {
            bound += 2 * inventory.bindings.generations[k].length + histories[k].resolutions.length
                + histories[k].repudiations.length;
        }
        Work memory w;
        w.aliases = new bool[](p.aliases.length);
        w.cells = new uint256[](p.eras.length);
        w.points = new RH.Point[](bound);
        for (uint256 i; i < p.journal.length; ++i) {
            uint16 op = p.journal[i].receipt.operation;
            if (op != 24 && op != 44 && op != 45 && op != 47 && op != 61 && !P.nativeOperation(op)) _invalid();
            _point(w, p, p.journal[i].position.point);
        }
        uint256[] memory bindingCounts = new uint256[](p.eras.length);
        for (uint256 k; k < n; ++k) {
            G.Timeline memory t = clocks.clocks.collections[k];
            uint256 generations = inventory.bindings.generations[k].length;
            if (
                t.attributionProposals.length != generations
                    || t.attributionCompletions.length != generations
            ) _invalid();
            for (uint256 g; g < generations; ++g) {
                _point(w, p, t.attributionProposals[g]);
                ++bindingCounts[A.era(p, t.attributionProposals[g].environmentHash)];
                RH.Point memory completion = t.attributionCompletions[g];
                if (completion.environmentHash != 0) {
                    _point(w, p, completion);
                    ++bindingCounts[A.era(p, completion.environmentHash)];
                } else {
                    RH.Point memory empty;
                    if (!D.samePoint(completion, empty)) _invalid();
                }
            }
            _guards(w, p, Platform.nativeRows(inventory.platforms[k], p));
            _guards(w, p, Disputes.guards(histories[k]));
            for (uint256 i; i < histories[k].resolutions.length; ++i) {
                _point(w, p, histories[k].resolutions[i].point);
            }
            for (uint256 i; i < histories[k].repudiations.length; ++i) {
                uint8 phase = histories[k].repudiations[i].terminal.phase;
                if (phase >= 2 && phase <= 4) {
                    _point(w, p, histories[k].repudiations[i].terminalPoint);
                }
            }
        }
        _confirmations(w, p, inventory);
        Aliases.complete(w.aliases);
        uint256 totalCells;
        for (uint256 e; e < p.eras.length; ++e) {
            RH.OwnerEra memory era = p.eras[e];
            uint256 mutations;
            for (uint256 i; i < w.count; ++i) {
                if (w.points[i].environmentHash == era.originHash) ++mutations;
            }
            totalCells += w.cells[e];
            if (
                bindingCounts[e] != clocks.clocks.counts[e] || era.lowerRevision != (e == 0 ? 0 : 1)
                    || uint256(era.checkpoint.ownerState.revision)
                        != uint256(era.lowerRevision) + mutations
                    || era.checkpoint.replayCount != totalCells
                    || (totalCells == 0 && era.checkpoint.replayRoot != 0)
                    || era.checkpoint.nonceIndexCount != 0 || era.checkpoint.nonceRoot != 0
            ) _invalid();
        }
    }

    function _confirmations(
        Work memory w,
        RH.OwnerProvenance memory p,
        C.Inventory memory inventory
    ) private view {
        for (uint256 i; i < inventory.archive.operations.length; ++i) {
            H.OperationEvidence memory item = inventory.archive.operations[i];
            if (item.operation != 13) continue;
            uint256 era = A.era(p, item.originHash);
            H.Envelope memory e =
                Catalogue.read(p.origins[era], inventory.archive.catalogues[era], item.evidence);
            (H.ConfirmationPayload memory confirmation, RH.Point memory attribution,) =
                Confirmation.validate(p.origins[era], inventory.provenance.eras[era], e);
            uint256 matched;
            for (uint256 k; k < inventory.bindings.bindings.length; ++k) {
                if (
                    inventory.bindings.bindings[k].bindings.collectionId
                        != confirmation.transition.collectionId
                ) continue;
                uint64 generation = confirmation.binding_.generation;
                if (
                    generation == 0
                        || generation > inventory.bindings.bindings[k].bindings.rows.length
                        || keccak256(abi.encode(confirmation.binding_))
                            != keccak256(
                                abi.encode(
                                    inventory.bindings.bindings[k].bindings
                                    .rows[generation - 1].item
                                )
                            )
                ) _invalid();
                ++matched;
            }
            if (matched != 1) _invalid();
            _point(w, p, attribution);
        }
    }

    function _guards(Work memory w, RH.OwnerProvenance memory p, D.Guard[] memory guards)
        private
        pure
    {
        for (uint256 i; i < guards.length; ++i) {
            D.Guard memory g = guards[i];
            Clock.validateOwnerPoint(p, 4, g.point);
            Aliases.mark(p, w.aliases, g.surface, g.scope, g.commitment, g.point);
            ++w.cells[A.era(p, g.point.environmentHash)];
        }
    }

    function _point(Work memory w, RH.OwnerProvenance memory p, RH.Point memory point)
        private
        pure
    {
        Clock.validateOwnerPoint(p, 4, point);
        for (uint256 i; i < w.count; ++i) {
            if (D.samePoint(w.points[i], point)) _invalid();
        }
        if (w.count == w.points.length) _invalid();
        w.points[w.count++] = point;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
