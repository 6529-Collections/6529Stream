// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryGuards as Original
} from "./StreamArtistRecoveredDisputeHistoryGuards.sol";
import {
    StreamArtistRecoveredMultipleGenerationGuards as Aliases
} from "./StreamArtistRecoveredMultipleGenerationGuards.sol";
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
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";

/// @notice Exact whole-owner aliases, mutation counts and disjoint original owner4 clocks.
library StreamArtistRecoveredMultipleDisputeGuards {
    function validate(
        D.Bundle[] memory rows,
        RH.OwnerProvenance memory p,
        Clocks.Result memory clocks
    ) public pure {
        if (rows.length != clocks.collections.length || clocks.counts.length != p.eras.length) _invalid();
        bool[] memory used = new bool[](p.aliases.length);
        uint256[] memory cells = new uint256[](p.eras.length);
        uint256[] memory mutations = new uint256[](p.eras.length);
        uint256 totalAuxiliary;
        for (uint256 k; k < rows.length; ++k) {
            totalAuxiliary += rows[k].resolutions.length + rows[k].repudiations.length;
        }
        RH.Point[] memory auxiliary = new RH.Point[](totalAuxiliary);
        uint256 cursor;
        for (uint256 k; k < rows.length; ++k) {
            D.Bundle memory b = rows[k];
            D.Guard[] memory guards = Original.guards(b);
            for (uint256 i; i < guards.length; ++i) {
                D.Guard memory g = guards[i];
                Clock.validateOwnerPoint(p, 4, g.point);
                Aliases.mark(p, used, g.surface, g.scope, g.commitment, g.point);
                ++cells[A.era(p, g.point.environmentHash)];
            }
            for (uint256 i; i < b.resolutions.length; ++i) {
                auxiliary[cursor++] = b.resolutions[i].point;
            }
            for (uint256 i; i < b.repudiations.length; ++i) {
                uint8 phase = b.repudiations[i].terminal.phase;
                if (phase >= 2 && phase <= 4) {
                    auxiliary[cursor++] = b.repudiations[i].terminalPoint;
                }
            }
        }
        Aliases.complete(used);
        for (uint256 i; i < cursor; ++i) {
            RH.Point memory point = auxiliary[i];
            Clock.validateOwnerPoint(p, 4, point);
            ++mutations[A.era(p, point.environmentHash)];
            for (uint256 j; j < i; ++j) {
                if (D.samePoint(point, auxiliary[j])) _invalid();
            }
            for (uint256 j; j < p.journal.length; ++j) {
                if (D.samePoint(point, p.journal[j].position.point)) _invalid();
            }
            for (uint256 k; k < clocks.collections.length; ++k) {
                G.Timeline memory t = clocks.collections[k];
                for (uint256 g; g < t.attributionProposals.length; ++g) {
                    if (
                        D.samePoint(point, t.attributionProposals[g])
                            || D.samePoint(point, t.attributionCompletions[g])
                    ) _invalid();
                }
            }
        }
        uint256 replayCount;
        for (uint256 e; e < p.eras.length; ++e) {
            replayCount += cells[e];
            RH.OwnerEra memory era = p.eras[e];
            if (
                era.lowerRevision != (e == 0 ? 0 : 1)
                    || era.checkpoint.ownerState.revision
                        != era.lowerRevision + clocks.counts[e] + era.nativeCount + mutations[e]
                    || era.checkpoint.replayCount != replayCount
                    || (replayCount == 0 && era.checkpoint.replayRoot != 0)
                    || era.checkpoint.nonceIndexCount != 0 || era.checkpoint.nonceRoot != 0
            ) _invalid();
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
