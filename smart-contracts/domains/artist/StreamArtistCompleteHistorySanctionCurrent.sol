// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";

import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistPrimaryCollaboratorClocks as Clocks
} from "./StreamArtistPrimaryCollaboratorClocks.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";

/// @notice Exact original13 intervals and restored confirmed states across changing historical Artists.
/// @dev The caller authenticates the one full sanction inventory and complete dispute/binding
/// rows first. Local confirmation arrays below are semantic views, never provenance slices.
library StreamArtistCompleteHistorySanctionCurrent {
    function validate(
        H.Inventory memory inventory,
        D.Bundle[] memory histories,
        PC.BindingInventory memory bindings,
        Clocks.Result memory clocks,
        RH.OwnerProvenance memory p
    ) public pure {
        if (
            histories.length != bindings.bindings.length
                || clocks.clocks.collections.length != histories.length
        ) _invalid();
        uint256 assigned;
        for (uint256 k; k < histories.length; ++k) {
            D.Bundle memory d = histories[k];
            CB.Bundle memory binding = bindings.bindings[k];
            if (
                d.collectionId != binding.bindings.collectionId
                    || d.generations.length != binding.bindings.rows.length
                    || d.current.generation != d.generations.length
                    || clocks.clocks.collections[k].attributionCompletions.length
                        != d.generations.length
                    || clocks.clocks.collections[k].attributionProposals.length
                        != d.generations.length
            ) _invalid();
            uint256 count;
            for (uint256 i; i < inventory.confirmations.length; ++i) {
                if (inventory.confirmations[i].transition.collectionId == d.collectionId) ++count;
            }
            H.Inventory memory local;
            local.confirmations = new H.ConfirmationRow[](count);
            count = 0;
            for (uint256 i; i < inventory.confirmations.length; ++i) {
                H.ConfirmationRow memory row = inventory.confirmations[i];
                if (row.transition.collectionId != d.collectionId) continue;
                uint64 g = row.transition.bindingGeneration;
                if (
                    g == 0 || g > d.generations.length
                        || !binding.bindings.rows[g - 1].item.accepted
                        || row.transition.artistId != binding.bindings.rows[g - 1].item.artistId
                        || !Clock.beforeOwner(
                            p,
                            4,
                            clocks.clocks.collections[k].attributionCompletions[g - 1],
                            row.attributionPoint
                        )
                        || (g < d.generations.length
                            && !Clock.beforeOwner(
                                p,
                                4,
                                row.attributionPoint,
                                clocks.clocks.collections[k].attributionProposals[g]
                            ))
                ) _invalid();
                local.confirmations[count++] = row;
                ++assigned;
            }
            _collection(H.AttributionBundle(d, local), binding, p);
        }
        if (assigned != inventory.confirmations.length) _invalid();
    }

    function _collection(
        H.AttributionBundle memory b,
        CB.Bundle memory binding,
        RH.OwnerProvenance memory p
    ) private pure {
        D.Bundle memory d = b.original;
        for (uint256 i; i < b.history.confirmations.length; ++i) {
            H.ConfirmationRow memory c = b.history.confirmations[i];
            uint64 g = c.transition.bindingGeneration;
            if (
                g == 0 || g > d.generations.length || !d.generations[g - 1].accepted
                    || c.transition.artistId != binding.bindings.rows[g - 1].item.artistId
                    || c.transition.collectionId != d.collectionId
            ) _invalid();
            for (uint256 j; j < i; ++j) {
                if (b.history.confirmations[j].transition.bindingGeneration == g) _invalid();
            }
            // Confirmation can occur after an earlier dispute was upheld/withdrawn, but never
            // while an opening remains live, after executed repudiation, or on an occupied clock.
            for (uint256 j; j < d.disputes.length; ++j) {
                D.DisputeRow memory row = d.disputes[j];
                if (D.samePoint(row.point, c.attributionPoint)) _invalid();
                if (
                    row.record.terms.bindingGeneration != g || row.record.terms.disputeAction != 1
                        || !Clock.beforeOwner(p, 4, row.point, c.attributionPoint)
                ) continue;
                bool restored;
                for (uint256 k; k < d.resolutions.length; ++k) {
                    D.ResolutionRow memory r = d.resolutions[k];
                    if (
                        r.record.terms.disputeRecordHash == row.record.recordHash
                            && Clock.beforeOwner(p, 4, r.point, c.attributionPoint)
                            && r.record.terms.resolution == 1 && r.record.restoredState <= 2
                    ) restored = true;
                }
                for (uint256 k; k < d.disputes.length; ++k) {
                    if (
                        row.withdrawal.recordHash != 0
                            && d.disputes[k].record.recordHash == row.withdrawal.recordHash
                            && Clock.beforeOwner(p, 4, d.disputes[k].point, c.attributionPoint)
                            && row.withdrawal.restoredState == 2
                    ) restored = true;
                }
                // An earlier revoked opening may have been reopened and later upheld.
                // The exact Archive transition proves accepted prior state2. A prior pending
                // dispute can have restored state1 and then been independently accepted.
                if (!restored && !_laterRestoration(d, g, row.point, c.attributionPoint, p)) {
                    _invalid();
                }
            }
            for (uint256 j; j < d.resolutions.length; ++j) {
                if (D.samePoint(d.resolutions[j].point, c.attributionPoint)) _invalid();
            }
            for (uint256 j; j < d.repudiations.length; ++j) {
                D.RepudiationRow memory row = d.repudiations[j];
                if (
                    D.samePoint(row.point, c.attributionPoint)
                        || D.samePoint(row.terminalPoint, c.attributionPoint)
                ) _invalid();
                if (
                    row.record.terms.bindingGeneration == g && row.terminal.phase == 4
                        && Clock.beforeOwner(p, 4, row.terminalPoint, c.attributionPoint)
                ) _invalid();
            }
        }
        for (uint256 i; i < d.disputes.length; ++i) {
            D.DisputeRow memory row = d.disputes[i];
            if (row.record.terms.disputeAction != 1) continue;
            bool wasConfirmed =
                _confirmedBefore(b, row.record.terms.bindingGeneration, row.point, p);
            if (
                row.withdrawal.recordHash != 0
                    && (row.withdrawal.restoredState == 3) != wasConfirmed
            ) _invalid();
            for (uint256 j; j < d.resolutions.length; ++j) {
                D.ResolutionRow memory r = d.resolutions[j];
                if (
                    r.record.terms.disputeRecordHash == row.record.recordHash
                        && r.record.terms.resolution == 1
                        && (r.record.restoredState == 3) != wasConfirmed
                ) _invalid();
            }
            if (
                d.heads[row.record.terms.bindingGeneration - 1].disputeRecordHash
                        == row.record.recordHash
                    && (d.heads[row.record.terms.bindingGeneration - 1].restoreState == 3)
                        != wasConfirmed
            ) _invalid();
        }
        bool confirmed;
        for (uint256 i; i < b.history.confirmations.length; ++i) {
            if (b.history.confirmations[i].transition.bindingGeneration == d.current.generation) {
                confirmed = true;
            }
        }
        if ((d.current.state == 3 && !confirmed) || (d.current.state == 2 && confirmed)) {
            _invalid();
        }
    }

    function _laterRestoration(
        D.Bundle memory d,
        uint64 g,
        RH.Point memory after_,
        RH.Point memory before_,
        RH.OwnerProvenance memory p
    ) private pure returns (bool) {
        for (uint256 i; i < d.resolutions.length; ++i) {
            D.ResolutionRow memory r = d.resolutions[i];
            if (
                r.record.terms.bindingGeneration == g && r.record.terms.resolution == 1
                    && r.record.restoredState <= 2 && Clock.beforeOwner(p, 4, after_, r.point)
                    && Clock.beforeOwner(p, 4, r.point, before_)
            ) return true;
        }
        return false;
    }

    function _confirmedBefore(
        H.AttributionBundle memory b,
        uint64 generation,
        RH.Point memory point,
        RH.OwnerProvenance memory p
    ) private pure returns (bool) {
        for (uint256 i; i < b.history.confirmations.length; ++i) {
            H.ConfirmationRow memory c = b.history.confirmations[i];
            if (
                c.transition.bindingGeneration == generation
                    && Clock.beforeOwner(p, 4, c.attributionPoint, point)
            ) return true;
        }
        return false;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
