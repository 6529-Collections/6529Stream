// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistAggregateSanctionConsentTypes as F
} from "./StreamArtistAggregateSanctionConsentTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationGuards as Guards
} from "./StreamArtistRecoveredMultipleGenerationGuards.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistSanctionConfirmationTypes as Confirmation
} from "../../interfaces/stream/artist/StreamArtistSanctionConfirmationTypes.sol";

/// @notice Original12 bindings and one complete Consent clock/replay proof including zero-native13.
/// @dev Archive bytes and both original confirmation transitions are authenticated before these
/// facts are used. Every checkpoint retains the complete owner inventory across all collections.
library StreamArtistRecoveredAggregateSanctionConsentFacts {
    function validate(
        G.Consents[] memory all,
        AH.Query[] memory queries,
        RH.OwnerProvenance memory p,
        F.Facts memory facts
    ) public pure {
        if (
            all.length != queries.length || facts.sanctions.length == 0
                || facts.sanctions.length > RH.MAX_JOURNAL_ENTRIES
                || facts.confirmations.length > H.MAX_CONFIRMATIONS
        ) _invalid();
        for (uint256 i; i < facts.sanctions.length; ++i) {
            F.Record memory r = facts.sanctions[i];
            Clock.validateOwnerPoint(p, 6, r.point);
            if (
                r.record.recordHash == 0 || r.record.artistId == 0 || r.record.signer == address(0)
                    || r.record.signedAt == 0 || r.record.deadline < r.record.signedAt
                    || (r.record.authorityClass != 1
                        && r.record.authorityClass != 3
                        && r.record.authorityClass != 4)
            ) _invalid();
            uint256 matches;
            for (uint256 k; k < queries.length; ++k) {
                if (queries[k].collectionId != r.record.terms.collectionId) continue;
                uint64 g = r.record.bindingGeneration;
                if (g == 0 || g > all[k].bindings.length) _invalid();
                T.Binding memory binding_ = all[k].bindings[g - 1];
                if (
                    !binding_.accepted || binding_.generation != g
                        || binding_.artistId != r.record.artistId
                        || binding_.bindingHash != r.record.bindingHash
                ) _invalid();
                ++matches;
            }
            if (matches != 1) _invalid();
            for (uint256 j; j < i; ++j) {
                if (
                    facts.sanctions[j].record.recordHash == r.record.recordHash
                        || D.samePoint(facts.sanctions[j].point, r.point)
                ) _invalid();
            }
        }
        for (uint256 i; i < facts.confirmations.length; ++i) {
            H.ConfirmationRow memory c = facts.confirmations[i];
            Clock.validateOwnerPoint(p, 6, c.consentPoint);
            uint256 matches;
            for (uint256 j; j < facts.sanctions.length; ++j) {
                F.Record memory s = facts.sanctions[j];
                if (s.record.recordHash != c.transition.sanctionRecordHash) continue;
                if (
                    c.transition.artistId != s.record.artistId
                        || c.transition.collectionId != s.record.terms.collectionId
                        || c.transition.bindingGeneration != s.record.bindingGeneration
                        || c.transition.priorAttributionState != 2
                        || c.transition.finalityRecordHash == 0
                        || !Clock.beforeOwner(p, 6, s.point, c.consentPoint)
                ) _invalid();
                ++matches;
            }
            if (matches != 1) _invalid();
            for (uint256 j; j < i; ++j) {
                H.ConfirmationRow memory earlier = facts.confirmations[j];
                if (
                    D.samePoint(earlier.consentPoint, c.consentPoint)
                        || (earlier.transition.collectionId == c.transition.collectionId
                            && earlier.transition.artistId == c.transition.artistId
                            && earlier.transition.bindingGeneration
                                == c.transition.bindingGeneration)
                ) _invalid();
            }
        }
    }

    /// @notice Bijection between original12 records and the unchanged global native journal.
    function nativeRows(RH.OwnerProvenance memory p, F.Facts memory facts) public pure {
        uint256 cursor;
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory j = p.journal[i];
            if (j.receipt.operation != 12) continue;
            if (cursor >= facts.sanctions.length) _invalid();
            F.Record memory row = facts.sanctions[cursor++];
            if (
                j.receipt.artistId != row.record.artistId
                    || j.receipt.collectionId != row.record.terms.collectionId
                    || j.receipt.recordHash != row.record.recordHash
                    || !D.samePoint(j.position.point, row.point)
            ) _invalid();
        }
        if (cursor != facts.sanctions.length) _invalid();
    }

    function clocksAndAliases(
        RH.OwnerProvenance memory p,
        bytes32[] memory surfaces,
        bytes32[] memory scopes,
        F.Facts memory facts
    ) public pure {
        if (surfaces.length != p.journal.length || scopes.length != p.journal.length) _invalid();
        bool[] memory used = new bool[](p.aliases.length);
        for (uint256 i; i < p.journal.length; ++i) {
            Guards.mark(
                p,
                used,
                surfaces[i],
                scopes[i],
                p.journal[i].receipt.recordHash,
                p.journal[i].position.point
            );
        }
        uint256[] memory confirmations = new uint256[](p.eras.length);
        for (uint256 i; i < facts.confirmations.length; ++i) {
            H.ConfirmationRow memory c = facts.confirmations[i];
            Clock.validateOwnerPoint(p, 6, c.consentPoint);
            ++confirmations[A.era(p, c.consentPoint.environmentHash)];
            Guards.mark(
                p,
                used,
                H.CONFIRMATION,
                Confirmation.scope(c.transition),
                c.transition.sanctionRecordHash,
                c.consentPoint
            );
        }
        Guards.complete(used);
        uint256 replay;
        for (uint256 e; e < p.eras.length; ++e) {
            RH.OwnerEra memory era = p.eras[e];
            uint256 mutations = uint256(era.nativeCount) + confirmations[e];
            replay += mutations;
            if (
                era.lowerRevision != (e == 0 ? 0 : 1)
                    || uint256(era.checkpoint.ownerState.revision)
                        != uint256(era.lowerRevision) + mutations
                    || era.checkpoint.replayCount != replay
                    || (replay == 0 && era.checkpoint.replayRoot != 0)
                    || era.checkpoint.nonceIndexCount != 0 || era.checkpoint.nonceRoot != 0
            ) _invalid();
            for (
                uint256 r = uint256(era.lowerRevision) + 1;
                r <= era.checkpoint.ownerState.revision;
                ++r
            ) {
                uint256 occupied;
                for (uint256 i; i < p.journal.length; ++i) {
                    RH.Point memory point = p.journal[i].position.point;
                    if (point.environmentHash == era.originHash && point.ownerRevision == r) {
                        ++occupied;
                    }
                }
                for (uint256 i; i < facts.confirmations.length; ++i) {
                    RH.Point memory point = facts.confirmations[i].consentPoint;
                    if (point.environmentHash == era.originHash && point.ownerRevision == r) {
                        ++occupied;
                    }
                }
                if (occupied != 1) _invalid();
            }
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
