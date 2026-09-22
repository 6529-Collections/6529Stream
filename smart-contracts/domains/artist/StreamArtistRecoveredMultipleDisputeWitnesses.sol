// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistReadinessHydrationTypes as ReadinessH
} from "../../interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistMultipleRecordsTypes as MR
} from "../../interfaces/stream/artist/IStreamArtistMultipleRecordsHydration.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredMultipleCodec as Scope
} from "./StreamArtistRecoveredMultipleCodec.sol";
import {
    StreamArtistRecoveredMultipleDisputeTypes as MD
} from "./StreamArtistRecoveredMultipleDisputeTypes.sol";

/// @notice Complete missing-term witnesses matched to original per-collection and global occurrence order.

library StreamArtistRecoveredMultipleDisputeWitnesses {
    struct Plan {
        T.EconomicsConsent[][] economics;
        T.RoyaltyFreeze[][] freezes;
        ReadinessH.AttestationInput[][] attestations;
    }

    function collect(
        T.SuiteConfiguration memory source,
        RH.Provenance memory p,
        M.State memory scope,
        MR.CollectionWitness[] memory witnesses,
        T.RoyaltyFreeze[] memory royalties
    ) public pure returns (Plan memory plan) {
        return _collect(source, p, scope, witnesses, royalties, false, false);
    }

    /// @dev Original52 has no caller-supplied term witness. Its complete rows are proved separately.
    function collectRatified(
        T.SuiteConfiguration memory source,
        RH.Provenance memory p,
        M.State memory scope,
        MR.CollectionWitness[] memory witnesses,
        T.RoyaltyFreeze[] memory royalties
    ) public pure returns (Plan memory plan) {
        return _collect(source, p, scope, witnesses, royalties, true, false);
    }

    /// @dev Terms are requested only for their original families; sanction bytes come from Archive.
    function collectSupplemented(
        T.SuiteConfiguration memory source,
        RH.Provenance memory p,
        M.State memory scope,
        MR.CollectionWitness[] memory witnesses,
        T.RoyaltyFreeze[] memory royalties
    ) public pure returns (Plan memory plan) {
        return _collect(source, p, scope, witnesses, royalties, true, true);
    }

    function _collect(
        T.SuiteConfiguration memory source,
        RH.Provenance memory p,
        M.State memory scope,
        MR.CollectionWitness[] memory witnesses,
        T.RoyaltyFreeze[] memory royalties,
        bool allowRatifications,
        bool allowSanctions
    ) private pure returns (Plan memory plan) {
        uint256 n = scope.collections.length;
        plan.economics = new T.EconomicsConsent[][](n);
        plan.freezes = new T.RoyaltyFreeze[][](n);
        plan.attestations = new ReadinessH.AttestationInput[][](n);
        uint256[] memory ac = new uint256[](n);
        uint256[] memory ec = new uint256[](n);
        uint256[] memory rc = new uint256[](n);
        uint256 totalRoyalty;
        for (uint256 i; i < p.journals[6].length; ++i) {
            RH.JournalEntry memory j = p.journals[6][i];
            uint256 c = Scope.collection(scope, j.receipt.collectionId);
            if (j.receipt.artistId != scope.collections[c].artistId) _invalid();
            if (j.receipt.operation == 15) {
                ++ec[c];
            } else if (j.receipt.operation == 20) {
                ++rc[c];
                ++totalRoyalty;
            } else if (
                j.receipt.operation != 14 && j.receipt.operation != 16 && j.receipt.operation != 17
                    && j.receipt.operation != 21
                    && (!allowRatifications || j.receipt.operation != 52)
                    && (!allowSanctions || j.receipt.operation != 12)
            ) {
                _invalid();
            }
        }
        if (p.journals[4].length > RH.MAX_JOURNAL_ENTRIES) _invalid();
        for (uint256 i; i < p.journals[4].length; ++i) {
            RH.JournalEntry memory j = p.journals[4][i];
            uint256 c = Scope.collection(scope, j.receipt.collectionId);
            if (MD.nativeDispute(j.receipt.operation)) continue;
            if (j.receipt.operation != 24 || j.receipt.artistId != scope.collections[c].artistId) {
                _invalid();
            }
            ++ac[c];
        }
        if (witnesses.length > 128 || totalRoyalty != royalties.length || royalties.length > 128) {
            _invalid();
        }
        uint256 cursor;
        uint256 totalEconomics;
        for (uint256 c; c < n; ++c) {
            if (ec[c] != 0 || ac[c] != 0) {
                if (
                    cursor == witnesses.length
                        || witnesses[cursor].collectionId != scope.collections[c].collectionId
                        || witnesses[cursor].attestations.length != ac[c]
                        || witnesses[cursor].economics.length != ec[c]
                ) _invalid();
                plan.attestations[c] = witnesses[cursor].attestations;
                plan.economics[c] = witnesses[cursor++].economics;
                for (uint256 j; j < plan.economics[c].length; ++j) {
                    T.EconomicsConsent memory t = plan.economics[c][j];
                    if (
                        t.collectionId != scope.collections[c].collectionId
                            || (t.resolver != source.primaryResolver
                                && t.resolver != source.royaltyResolver)
                    ) _invalid();
                }
            } else {
                plan.economics[c] = new T.EconomicsConsent[](0);
                plan.attestations[c] = new ReadinessH.AttestationInput[](0);
            }
            totalEconomics += ec[c];
            plan.freezes[c] = new T.RoyaltyFreeze[](rc[c]);
            rc[c] = 0;
        }
        if (cursor != witnesses.length || totalEconomics > 128) _invalid();
        cursor = 0;
        for (uint256 i; i < p.journals[6].length; ++i) {
            RH.JournalEntry memory j = p.journals[6][i];
            if (j.receipt.operation != 20) continue;
            uint256 c = Scope.collection(scope, j.receipt.collectionId);
            T.RoyaltyFreeze memory t = royalties[cursor++];
            if (t.collectionId != j.receipt.collectionId) _invalid();
            plan.freezes[c][rc[c]++] = t;
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
