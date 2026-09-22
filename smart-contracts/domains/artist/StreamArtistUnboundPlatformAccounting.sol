// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";

/// @notice Complete global owner4 arithmetic and exact Platform replay-cell bijection.
/// @dev This validates retained cells; it neither writes replay state nor creates authorization.
library StreamArtistUnboundPlatformAccounting {
    function validate(
        RH.OwnerProvenance memory p,
        uint256[] memory accepted,
        D.Guard[] memory expected
    ) public pure {
        if (accepted.length != p.eras.length || expected.length != p.journal.length) _invalid();
        uint256[] memory mutations = new uint256[](p.eras.length);
        for (uint256 i; i < expected.length; ++i) {
            ++mutations[A.era(p, expected[i].point.environmentHash)];
        }
        for (uint256 e; e < p.eras.length; ++e) {
            uint256 count;
            for (uint256 i; i < expected.length; ++i) {
                if (A.era(p, expected[i].point.environmentHash) <= e) ++count;
            }
            RH.OwnerEra memory era_ = p.eras[e];
            if (
                era_.lowerRevision != (e == 0 ? 0 : 1)
                    || era_.checkpoint.ownerState.revision
                        != era_.lowerRevision + 2 * accepted[e] + mutations[e]
                    || era_.nativeCount != mutations[e] || era_.checkpoint.replayCount != count
                    || era_.checkpoint.nonceIndexCount != 0 || era_.checkpoint.nonceRoot != 0
            ) _invalid();
        }
        for (uint256 i; i < expected.length; ++i) {
            D.Guard memory g = expected[i];
            Clock.validateOwnerPoint(p, 4, g.point);
            for (uint256 j; j < i; ++j) {
                if (expected[j].surface == g.surface && expected[j].scope == g.scope) _invalid();
            }
            uint256 first = A.era(p, g.point.environmentHash);
            for (uint256 e = first; e < p.eras.length; ++e) {
                uint256 matched;
                for (uint256 k; k < p.aliases.length; ++k) {
                    RH.ReplayAlias memory a = p.aliases[k];
                    if (
                        a.originHash != p.eras[e].originHash || a.surface != g.surface
                            || a.scope != g.scope
                    ) continue;
                    if (
                        a.ownerIndex != 4 || a.cell.kind != 1 || a.cell.status != 2
                            || a.cell.commitment != g.commitment
                            || !D.samePoint(a.admittedAt, g.point)
                    ) _invalid();
                    ++matched;
                }
                if (matched != 1) _invalid();
            }
        }
        // The reverse check excludes every unsupported or orphaned cell; checkpoint counts
        // alone do not identify a substituted arbitrary surface/scope.
        for (uint256 i; i < p.aliases.length; ++i) {
            RH.ReplayAlias memory a = p.aliases[i];
            bool matched;
            for (uint256 j; j < expected.length; ++j) {
                D.Guard memory g = expected[j];
                if (
                    a.surface == g.surface && a.scope == g.scope
                        && a.cell.commitment == g.commitment && D.samePoint(a.admittedAt, g.point)
                ) matched = true;
            }
            if (!matched) _invalid();
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
