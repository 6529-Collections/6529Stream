// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredSanctionTimeline as Original
} from "./StreamArtistRecoveredSanctionTimeline.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationClocks as Clocks
} from "./StreamArtistRecoveredMultipleGenerationClocks.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleCollectionRows as Native
} from "./StreamArtistRecoveredMultipleCollectionRows.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

/// @notice Original confirmation intervals and confirmed-state restoration for aggregate owner4.
/// @dev Callers authenticate the full global Archive inventory. Per-collection arrays below are
/// semantic views for the original timeline predicates, never filtered provenance certificates.
library StreamArtistRecoveredAggregateSanctionAttributionFacts {
    function generations(
        A.AttributionBundle[] memory all,
        RH.OwnerProvenance memory p,
        Clocks.Result memory clocks,
        H.ConfirmationRow[] memory confirmations
    ) public pure {
        if (all.length != clocks.collections.length) _invalid();
        uint256 assigned;
        for (uint256 k; k < all.length; ++k) {
            A.AttributionBundle memory b = all[k];
            bool currentConfirmed;
            for (uint256 i; i < confirmations.length; ++i) {
                H.ConfirmationRow memory c = confirmations[i];
                if (c.transition.collectionId != b.collectionId) continue;
                ++assigned;
                _interval(c, b.artistId, b.generations, p, clocks, k);
                if (c.transition.bindingGeneration == b.current.generation) {
                    currentConfirmed = true;
                }
                for (uint256 r; r < b.revocations.length; ++r) {
                    if (
                        b.revocations[r].opening.terms.bindingGeneration
                            != c.transition.bindingGeneration
                    ) {
                        continue;
                    }
                    AH.Query memory q;
                    q.artistId = b.artistId;
                    q.collectionId = b.collectionId;
                    RH.Point memory opening =
                    Native.occurrence(p, q, 44, b.revocations[r].opening.recordHash).position.point;
                    // This narrow family has only a final revocation, with no later restoration.
                    if (!Clock.beforeOwner(p, 4, c.attributionPoint, opening)) _invalid();
                }
            }
            if (b.current.state != (currentConfirmed ? 3 : 2)) _invalid();
            for (uint256 r; r < b.revocations.length; ++r) {
                bool confirmed;
                for (uint256 i; i < confirmations.length; ++i) {
                    if (
                        confirmations[i].transition.collectionId == b.collectionId
                            && confirmations[i].transition.artistId == b.artistId
                            && confirmations[i].transition.bindingGeneration
                                == b.revocations[r].opening.terms.bindingGeneration
                    ) confirmed = true;
                }
                if (b.revocations[r].head.restoreState != (confirmed ? 3 : 2)) _invalid();
            }
        }
        if (assigned != confirmations.length) _invalid();
    }

    function disputes(
        D.Bundle[] memory all,
        RH.OwnerProvenance memory p,
        Clocks.Result memory clocks,
        H.ConfirmationRow[] memory confirmations
    ) public pure {
        if (all.length != clocks.collections.length) _invalid();
        uint256 assigned;
        for (uint256 k; k < all.length; ++k) {
            D.Bundle memory b = all[k];
            H.Inventory memory localRows;
            uint256 count;
            for (uint256 i; i < confirmations.length; ++i) {
                if (confirmations[i].transition.collectionId == b.collectionId) ++count;
            }
            localRows.confirmations = new H.ConfirmationRow[](count);
            count = 0;
            for (uint256 i; i < confirmations.length; ++i) {
                H.ConfirmationRow memory c = confirmations[i];
                if (c.transition.collectionId != b.collectionId) continue;
                ++assigned;
                _interval(c, b.artistId, b.generations, p, clocks, k);
                localRows.confirmations[count++] = c;
            }
            Original.validate(H.AttributionBundle(b, localRows), p);
        }
        if (assigned != confirmations.length) _invalid();
    }

    function _interval(
        H.ConfirmationRow memory c,
        bytes32 artist,
        A.Generation[] memory generations_,
        RH.OwnerProvenance memory p,
        Clocks.Result memory clocks,
        uint256 k
    ) private pure {
        uint64 g = c.transition.bindingGeneration;
        if (
            c.transition.artistId != artist || g == 0 || g > generations_.length
                || !generations_[g - 1].accepted
                || g > clocks.collections[k].attributionCompletions.length
                || !Clock.beforeOwner(
                    p, 4, clocks.collections[k].attributionCompletions[g - 1], c.attributionPoint
                )
                || (g < generations_.length
                    && !Clock.beforeOwner(
                        p, 4, c.attributionPoint, clocks.collections[k].attributionProposals[g]
                    ))
        ) {
            _invalid();
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
