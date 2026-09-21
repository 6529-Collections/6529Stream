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

/// @notice Every original Attribution replay surface, including its copies in later owner eras.
/// @dev This validates retained cells; it neither writes replay state nor creates authorization.
library StreamArtistRecoveredDisputeHistoryGuards {
    function validate(D.Bundle memory b, RH.OwnerProvenance memory p) public pure {
        D.Guard[] memory expected = guards(b);
        uint256[] memory mutations = new uint256[](p.eras.length);
        uint256[] memory nativeCounts = new uint256[](p.eras.length);
        uint256[] memory claims = new uint256[](p.eras.length);
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

    function guards(D.Bundle memory b) public pure returns (D.Guard[] memory result) {
        result =
            new D.Guard[](2 * (b.disputes.length + b.resolutions.length + b.repudiations.length));
        uint256 n;
        for (uint256 i; i < b.disputes.length; ++i) {
            D.DisputeRow memory r = b.disputes[i];
            uint8 action = r.record.terms.disputeAction;
            bytes32 surface = action == 1 ? D.OPEN : action == 2 ? D.WITHDRAW : D.COUNTER;
            bytes32 scope = action == 2
                ? r.record.disputeRecordHash
                : keccak256(
                    abi.encode(
                        b.collectionId,
                        r.record.terms.bindingGeneration,
                        action == 1 ? bytes32(0) : r.record.disputeRecordHash,
                        r.record.signer,
                        r.record.terms.evidenceHash,
                        r.record.terms.reasonHash
                    )
                );
            result[n++] = D.Guard(surface, scope, r.record.recordHash, r.point);
            if (r.record.governanceActionId != 0) {
                result[n++] = D.Guard(
                    D.GOVERNANCE, r.record.governanceActionId, r.record.recordHash, r.point
                );
            }
        }
        for (uint256 i; i < b.resolutions.length; ++i) {
            D.ResolutionRow memory r = b.resolutions[i];
            result[n++] =
                D.Guard(D.RESOLVE, r.record.terms.disputeRecordHash, r.record.actionId, r.point);
            result[n++] =
                D.Guard(D.GOVERNANCE, r.record.actionId, r.record.terms.disputeRecordHash, r.point);
        }
        for (uint256 i; i < b.repudiations.length; ++i) {
            D.RepudiationRow memory r = b.repudiations[i];
            result[n++] = D.Guard(D.STAGE, r.record.recordHash, r.record.recordHash, r.point);
            uint8 phase = r.terminal.phase;
            if (phase >= 2 && phase <= 4) {
                result[n++] = D.Guard(
                    D.terminalSurface(phase),
                    r.record.recordHash,
                    keccak256(abi.encode(r.record.recordHash, phase, r.terminal.reasonHash)),
                    r.terminalPoint
                );
            }
        }
        assembly ("memory-safe") { mstore(result, n) }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
