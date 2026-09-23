// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryRowFacts as Original
} from "./StreamArtistRecoveredDisputeHistoryRowFacts.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistPlatformCorrectionState as Platform
} from "./StreamArtistPlatformCorrectionState.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistAttributionDisputeTypes as AD
} from "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";

/// @notice Original dispute eligibility joined to authentic historical bindings and PC acceptances.
/// @dev These family facts do not replace Identity signature/nonce/grant proofs, original
/// Archive admission evidence, sanctions, or the whole owner4 replay and mutation bijection.
library StreamArtistCompleteHistoryDisputeFacts {
    function dispute(
        D.Bundle memory b,
        D.DisputeRow memory r,
        RH.OwnerProvenance memory p,
        PC.BindingInventory memory bindings,
        PC.Inventory memory archive,
        G.Timeline memory timeline,
        uint256 collection,
        uint256 operationIndex
    ) public pure {
        uint64 g = r.record.terms.bindingGeneration;
        CB.Bundle memory binding = bindings.bindings[collection];
        if (g == 0 || g > binding.bindings.rows.length) _invalid();
        Original.disputeRecordForBinding(b, r, p, binding.bindings.rows[g - 1].item.artistId);
        interval(p, timeline, r.point, g, false);
        if (r.record.governanceActionId != 0) return;
        _standing(r, p, bindings, archive, timeline, collection, operationIndex);
    }

    function _standing(
        D.DisputeRow memory r,
        RH.OwnerProvenance memory p,
        PC.BindingInventory memory bindings,
        PC.Inventory memory archive,
        G.Timeline memory timeline,
        uint256 collection,
        uint256 operationIndex
    ) private pure {
        AD.Record memory a = r.record;
        AD.Standing memory s = a.standing;
        uint64 g = a.terms.bindingGeneration;
        CB.Bundle memory binding = bindings.bindings[collection];
        T.Binding memory current = binding.bindings.rows[g - 1].item;
        if (s.artistId == 0 || s.bindingGeneration == 0 || s.bindingGeneration > g) _invalid();
        if (s.delegation != 0 && (s.artistId != current.artistId || s.bindingGeneration != g)) {
            _invalid();
        }
        if (a.terms.disputeAction == 3) {
            // The original counter admission also supports a governed pending opening.
            if (
                s.artistId != current.artistId || s.bindingGeneration != g
                    || s.collaboratorIndex != 0 || binding.bindings.rows[g - 1].terms.mode != 0
                    || binding.bindings.rows[g - 1].terms.threshold != 0
                    || binding.bindings.rows[g - 1].terms.capabilityPolicySetHash
                        != Hashes.emptyCapabilities()
            ) _invalid();
            return;
        }
        if (a.terms.disputeAction != 1 && a.terms.disputeAction != 2) _invalid();
        if (!current.accepted) _invalid();
        interval(p, timeline, r.point, g, true);
        if (s.artistId == current.artistId && s.bindingGeneration == g) {
            if (s.collaboratorIndex != 0) _invalid();
        } else if (s.bindingGeneration < g) {
            T.Binding memory former = binding.bindings.rows[s.bindingGeneration - 1].item;
            if (
                former.artistId != s.artistId || !former.accepted || former.bindingHash == 0
                    || s.delegation != 0 || s.collaboratorIndex != 0
                    || !Clock.beforeOwner(
                        p, 4, timeline.attributionCompletions[s.bindingGeneration - 1], r.point
                    )
            ) _invalid();
        } else {
            if (
                s.delegation != 0
                    || s.collaboratorIndex >= bindings.collaborators[collection][g - 1].length
            ) {
                _invalid();
            }
            T.CollaboratorRecord memory term =
                bindings.collaborators[collection][g - 1][s.collaboratorIndex];
            uint256 matches;
            for (uint256 i; i < archive.accepted.length; ++i) {
                PC.AcceptedRow memory joined = archive.accepted[i];
                if (
                    joined.acceptance.bindingHash != current.bindingHash
                        || joined.acceptance.account != term.account
                        || joined.acceptance.role != term.role
                        || joined.acceptance.shareLabelId != term.shareLabelId
                ) continue;
                if (
                    joined.acceptance.collectionId != binding.bindings.collectionId
                        || joined.acceptance.generation != g || joined.join.artistId != s.artistId
                        || joined.join.acceptanceRecordHash == 0
                        || joined.operationIndex >= operationIndex
                ) _invalid();
                ++matches;
            }
            if (matches != 1) _invalid();
        }
    }

    function repudiation(
        D.Bundle memory b,
        D.RepudiationRow memory r,
        RH.OwnerProvenance memory p,
        CB.Bundle memory binding,
        G.Timeline memory timeline
    ) public pure {
        uint64 g = r.record.terms.bindingGeneration;
        if (g == 0 || g > binding.bindings.rows.length) _invalid();
        Original.repudiationForBinding(b, r, p, binding.bindings.rows[g - 1].item.artistId);
        interval(p, timeline, r.point, g, true);
        if (r.terminal.phase >= 2 && r.terminal.phase <= 4) {
            interval(p, timeline, r.terminalPoint, g, true);
        }
    }

    function interval(
        RH.OwnerProvenance memory p,
        G.Timeline memory t,
        RH.Point memory point,
        uint64 generation,
        bool accepted
    ) public pure {
        if (
            generation == 0 || generation > t.attributionProposals.length
                || t.attributionCompletions.length != t.attributionProposals.length
        ) _invalid();
        RH.Point memory start = accepted
            ? t.attributionCompletions[generation - 1]
            : t.attributionProposals[generation - 1];
        if (
            !Clock.beforeOwner(p, 4, start, point)
                || (generation < t.attributionProposals.length
                    && !Clock.beforeOwner(p, 4, point, t.attributionProposals[generation]))
        ) _invalid();
    }

    function current(D.Bundle memory b, CB.Bundle memory binding) public pure {
        uint256 n = b.generations.length;
        if (n == 0) {
            if (b.current.state != 0 || b.current.generation != 0 || b.pending != 0) _invalid();
            return;
        }
        AD.Head memory h = b.heads[n - 1];
        uint8 expected;
        if (h.open) expected = 4;
        else if (h.revocationReason == 3 || h.revocationReason == 4) expected = 5;
        else if (binding.bindings.rows[n - 1].terminal.kind != 0) expected = 5;
        else if (binding.bindings.rows[n - 1].item.accepted) expected = 2;
        else expected = 1;
        // A confirmed state is proved by the separate, complete original sanction timeline.
        if (b.current.state != expected && !(expected == 2 && b.current.state == 3)) _invalid();
    }

    function causes(D.Bundle memory b, CB.Bundle memory binding) public pure {
        for (uint256 g; g + 1 < b.generations.length; ++g) {
            if (binding.corrections[g + 1].recordHash == 0) {
                if (b.heads[g].open || b.heads[g].revocationReason != 0) _invalid();
                continue;
            }
            uint8 cause = binding.corrections[g + 1].approval.cause;
            bytes memory expected;
            if (cause == 1 || cause == 2) {
                expected = abi.encode(binding.bindings.rows[g].terminal, b.heads[g]);
            } else if (cause == 4) {
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
                expected =
                    abi.encode(binding.bindings.rows[g].terminal, b.heads[g], opening, resolution);
            } else if (cause == 3) {
                uint256 matches;
                for (uint256 i; i < b.repudiations.length; ++i) {
                    D.RepudiationRow memory r = b.repudiations[i];
                    if (r.record.recordHash != binding.corrections[g + 1].approval.causeRecord) {
                        continue;
                    }
                    if (r.terminal.phase != 4 || r.record.terms.bindingGeneration != g + 1) {
                        _invalid();
                    }
                    expected = abi.encode(
                        binding.bindings.rows[g].terminal, b.heads[g], r.record, r.terminal
                    );
                    ++matches;
                }
                if (matches != 1) _invalid();
            } else {
                _invalid();
            }
            bytes memory saved = binding.corrections[g + 1].approval.causeData;
            if (Platform.tagged(saved)) saved = Platform.decode(saved).originalCauseData;
            if (keccak256(expected) != keccak256(saved)) _invalid();
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
