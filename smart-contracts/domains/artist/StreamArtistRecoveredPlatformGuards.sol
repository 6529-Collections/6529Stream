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

import {
    StreamArtistRecoveredDisputeHistoryGuards as Original
} from "./StreamArtistRecoveredDisputeHistoryGuards.sol";

/// @notice Original dispute and collection-only Platform replay cells in every owner era.
/// @dev This validates retained cells; it neither writes replay state nor creates authorization.
library StreamArtistRecoveredPlatformGuards {
    function validate(
        D.Bundle memory b,
        RH.OwnerProvenance memory p,
        RH.Point[] memory confirmations,
        D.Guard[] memory platform
    ) public pure {
        D.Guard[] memory base = Original.guards(b);
        D.Guard[] memory expected = new D.Guard[](base.length + platform.length);
        for (uint256 i; i < base.length; ++i) {
            expected[i] = base[i];
        }
        for (uint256 i; i < platform.length; ++i) {
            expected[base.length + i] = platform[i];
        }
        uint256[] memory mutations = new uint256[](p.eras.length);
        uint256[] memory nativeCounts = new uint256[](p.eras.length);
        uint256[] memory claims = new uint256[](p.eras.length);
        for (uint256 i; i < platform.length; ++i) {
            uint256 era_ = A.era(p, platform[i].point.environmentHash);
            ++mutations[era_];
            ++nativeCounts[era_];
        }
        for (uint256 i; i < b.generations.length; ++i) {
            uint256 era_ = A.era(p, b.generations[i].proposal.environmentHash);
            ++claims[era_];
            if (b.generations[i].accepted || b.heads[i].revocationReason != 4) ++claims[era_];
        }
        for (uint256 i; i < b.disputes.length; ++i) {
            ++mutations[A.era(p, b.disputes[i].point.environmentHash)];
            ++nativeCounts[A.era(p, b.disputes[i].point.environmentHash)];
        }
        for (uint256 i; i < b.resolutions.length; ++i) {
            ++mutations[A.era(p, b.resolutions[i].point.environmentHash)];
        }
        for (uint256 i; i < b.repudiations.length; ++i) {
            ++mutations[A.era(p, b.repudiations[i].point.environmentHash)];
            ++nativeCounts[A.era(p, b.repudiations[i].point.environmentHash)];
            uint8 phase = b.repudiations[i].terminal.phase;
            if (phase >= 2 && phase <= 4) {
                ++mutations[A.era(p, b.repudiations[i].terminalPoint.environmentHash)];
            }
        }
        for (uint256 i; i < confirmations.length; ++i) {
            Clock.validateOwnerPoint(p, 4, confirmations[i]);
            ++mutations[A.era(p, confirmations[i].environmentHash)];
        }
        // Opening/staging invalidations are part of that same original owner commit, never
        // invented native records or extra revisions. Claim + acceptance/termination is two; pending arbiter revocation has only the claim.
        for (uint256 e; e < p.eras.length; ++e) {
            uint256 count;
            for (uint256 i; i < expected.length; ++i) {
                if (A.era(p, expected[i].point.environmentHash) <= e) ++count;
            }
            RH.OwnerEra memory era_ = p.eras[e];
            if (
                era_.lowerRevision != (e == 0 ? 0 : 1)
                    || era_.checkpoint.ownerState.revision
                        != era_.lowerRevision + claims[e] + mutations[e]
                    || era_.nativeCount != nativeCounts[e] || era_.checkpoint.replayCount != count
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
