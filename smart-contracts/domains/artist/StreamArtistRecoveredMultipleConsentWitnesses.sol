// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
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

/// @notice Complete missing-term witnesses matched to original per-collection and global occurrence order.
library StreamArtistRecoveredMultipleConsentWitnesses {
    function collect(
        T.SuiteConfiguration memory source,
        RH.Provenance memory p,
        M.State memory scope,
        MR.CollectionWitness[] memory witnesses,
        T.RoyaltyFreeze[] memory royalties
    )
        public
        pure
        returns (T.EconomicsConsent[][] memory economics, T.RoyaltyFreeze[][] memory freezes)
    {
        uint256 n = scope.collections.length;
        economics = new T.EconomicsConsent[][](n);
        freezes = new T.RoyaltyFreeze[][](n);
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
            ) {
                _invalid();
            }
        }
        if (witnesses.length > 128 || totalRoyalty != royalties.length || royalties.length > 128) {
            _invalid();
        }
        uint256 cursor;
        uint256 totalEconomics;
        for (uint256 c; c < n; ++c) {
            if (ec[c] != 0) {
                if (
                    cursor == witnesses.length
                        || witnesses[cursor].collectionId != scope.collections[c].collectionId
                        || witnesses[cursor].attestations.length != 0
                        || witnesses[cursor].economics.length != ec[c]
                ) _invalid();
                economics[c] = witnesses[cursor++].economics;
                for (uint256 j; j < economics[c].length; ++j) {
                    T.EconomicsConsent memory t = economics[c][j];
                    if (
                        t.collectionId != scope.collections[c].collectionId
                            || (t.resolver != source.primaryResolver
                                && t.resolver != source.royaltyResolver)
                    ) _invalid();
                }
            } else {
                economics[c] = new T.EconomicsConsent[](0);
            }
            totalEconomics += ec[c];
            freezes[c] = new T.RoyaltyFreeze[](rc[c]);
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
            freezes[c][rc[c]++] = t;
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
