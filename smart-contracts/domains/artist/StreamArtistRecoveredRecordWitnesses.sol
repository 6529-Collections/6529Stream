// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistMultipleRecordsTypes as MR
} from "../../interfaces/stream/artist/IStreamArtistMultipleRecordsHydration.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Exact witness-family selection from the complete recovered source journals.
/// @dev A witness supplies missing original terms, never a projection or authority. The fixed
/// typed collectors independently join every term to its ordered native occurrence and maps.
library StreamArtistRecoveredRecordWitnesses {
    function collect(
        T.SuiteConfiguration memory source,
        RH.Provenance memory provenance,
        AH.Query memory query,
        MR.CollectionWitness[] memory witnesses
    ) public pure returns (MR.CollectionWitness memory selected) {
        uint256 economics;
        uint256 attestations;
        for (uint256 i; i < provenance.journals[6].length; ++i) {
            if (provenance.journals[6][i].receipt.operation == 15) ++economics;
        }
        for (uint256 i; i < provenance.journals[4].length; ++i) {
            if (provenance.journals[4][i].receipt.operation == 24) ++attestations;
        }
        if (economics == 0 && attestations == 0) {
            if (witnesses.length != 0) revert T.UnsupportedProfile();
            return selected;
        }
        if (
            economics > 128 || attestations > 128 || witnesses.length != 1
                || query.collectionId == 0 || witnesses[0].collectionId != query.collectionId
                || witnesses[0].economics.length != economics
                || witnesses[0].attestations.length != attestations
        ) revert T.UnsupportedProfile();
        selected = witnesses[0];
        for (uint256 i; i < selected.economics.length; ++i) {
            if (
                selected.economics[i].resolver != source.primaryResolver
                    && selected.economics[i].resolver != source.royaltyResolver
            ) revert T.UnsupportedProfile();
        }
    }
}
