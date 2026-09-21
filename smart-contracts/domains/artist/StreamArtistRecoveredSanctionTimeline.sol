// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredSanctionLocalProof as Local
} from "./StreamArtistRecoveredSanctionLocalProof.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryRows as Rows
} from "./StreamArtistRecoveredDisputeHistoryRows.sol";
import {
    StreamArtistRecoveredDisputeHistoryChains as Chains
} from "./StreamArtistRecoveredDisputeHistoryChains.sol";
import {
    StreamArtistRecoveredDisputeHistoryGuards as Guards
} from "./StreamArtistRecoveredDisputeHistoryGuards.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";

/// @notice Exact original confirmation chronology, independent from tuple encoding.
library StreamArtistRecoveredSanctionTimeline {
    function validate(H.AttributionBundle memory b, RH.OwnerProvenance memory p) public pure {
        D.Bundle memory d = b.original;
        for (uint256 i; i < b.history.confirmations.length; ++i) {
            H.ConfirmationRow memory c = b.history.confirmations[i];
            uint64 g = c.transition.bindingGeneration;
            if (
                g == 0 || g > d.generations.length || !d.generations[g - 1].accepted
                    || c.transition.artistId != d.artistId
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
