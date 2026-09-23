// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationClocks as Clocks
} from "./StreamArtistRecoveredMultipleGenerationClocks.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistAttributionDisputeTypes as AD
} from "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";

/// @notice Every history occurrence belongs to its original binding interval and correction cause.
library StreamArtistRecoveredMultipleDisputeTimeline {
    function validate(
        D.Bundle[] memory all,
        RH.OwnerProvenance memory p,
        G.Inventory memory inventory,
        Clocks.Result memory clocks
    ) public pure {
        for (uint256 k; k < all.length; ++k) {
            D.Bundle memory b = all[k];
            G.Timeline memory t = clocks.collections[k];
            for (uint256 i; i < b.disputes.length; ++i) {
                _interval(
                    p, t, b.disputes[i].point, b.disputes[i].record.terms.bindingGeneration, false
                );
            }
            for (uint256 i; i < b.resolutions.length; ++i) {
                _interval(
                    p,
                    t,
                    b.resolutions[i].point,
                    b.resolutions[i].record.terms.bindingGeneration,
                    false
                );
            }
            for (uint256 i; i < b.repudiations.length; ++i) {
                D.RepudiationRow memory r = b.repudiations[i];
                _interval(p, t, r.point, r.record.terms.bindingGeneration, true);
                if (r.terminal.phase >= 2 && r.terminal.phase <= 4) {
                    _interval(p, t, r.terminalPoint, r.record.terms.bindingGeneration, true);
                }
            }
            for (uint256 g; g + 1 < b.generations.length; ++g) {
                if (!b.generations[g].accepted && b.heads[g].revocationReason != 4) continue;
                bytes memory expected;
                uint8 cause = inventory.bindings[k].corrections[g + 1].approval.cause;
                if (cause == 4) {
                    AD.Record memory opening;
                    AD.Resolution memory resolution;
                    for (uint256 i; i < b.disputes.length; ++i) {
                        if (b.disputes[i].record.recordHash == b.heads[g].disputeRecordHash) {
                            opening = b.disputes[i].record;
                        }
                    }
                    for (uint256 i; i < b.resolutions.length; ++i) {
                        if (b.resolutions[i].record.actionId == b.heads[g].resolutionActionId) {
                            resolution = b.resolutions[i].record;
                        }
                    }
                    if (opening.recordHash == 0 || resolution.actionId == 0) _invalid();
                    expected = abi.encode(
                        inventory.bindings[k].bindings.rows[g].terminal,
                        b.heads[g],
                        opening,
                        resolution
                    );
                } else if (cause == 3) {
                    uint256 count;
                    for (uint256 i; i < b.repudiations.length; ++i) {
                        D.RepudiationRow memory r = b.repudiations[i];
                        if (
                            r.record.recordHash
                                != inventory.bindings[k].corrections[g + 1].approval.causeRecord
                        ) continue;
                        if (r.terminal.phase != 4 || r.record.terms.bindingGeneration != g + 1) {
                            _invalid();
                        }
                        expected = abi.encode(
                            inventory.bindings[k].bindings.rows[g].terminal,
                            b.heads[g],
                            r.record,
                            r.terminal
                        );
                        ++count;
                    }
                    if (count != 1) _invalid();
                } else {
                    _invalid();
                }
                if (
                    keccak256(expected)
                        != keccak256(inventory.bindings[k].corrections[g + 1].approval.causeData)
                ) _invalid();
            }
        }
    }

    function _interval(
        RH.OwnerProvenance memory p,
        G.Timeline memory t,
        RH.Point memory point,
        uint64 generation,
        bool accepted
    ) private pure {
        if (generation == 0 || generation > t.attributionProposals.length) {
            _invalid();
        }
        RH.Point memory start = accepted
            ? t.attributionCompletions[generation - 1]
            : t.attributionProposals[generation - 1];
        if (
            !Clock.beforeOwner(p, 4, start, point)
                || (generation < t.attributionProposals.length
                    && !Clock.beforeOwner(p, 4, point, t.attributionProposals[generation]))
        ) _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
