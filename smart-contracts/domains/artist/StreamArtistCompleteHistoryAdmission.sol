// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistHistory as History
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    StreamArtistHydrationSourceGuards as Original
} from "./StreamArtistHydrationSourceGuards.sol";
import {
    StreamArtistRecoveredHydrationAdmission as Admission
} from "./StreamArtistRecoveredHydrationAdmission.sol";
import { StreamArtistCompleteHistoryScope as Scope } from "./StreamArtistCompleteHistoryScope.sol";

/// @notice Original sealed predecessor admission and exact global principal/collection lane union.
library StreamArtistCompleteHistoryAdmission {
    function collect(T.SuiteConfiguration memory destination, RH.Request memory request)
        public
        view
        returns (Admission.Certificate memory c)
    {
        Scope.selectors(request.records.authority);
        c = Admission.admit(destination, request);
        T.Binding[] memory heads = new T.Binding[](request.records.authority.collections.length);
        for (uint256 i; i < heads.length; ++i) {
            heads[i] = Binding(c.source.owners[0])
                .binding(request.records.authority.collections[i].collectionId);
        }
        M.State memory s = Scope.partition(request.records.authority, heads, c.provenance);
        c.artists = s.artists;
        c.collections = s.collections;
        History destinationHistory = History(destination.owners[2]);
        for (uint256 i; i < c.artists.length; ++i) {
            Original._lane(destinationHistory, c.prior, 1, c.artists[i].artistId);
            (, uint64 count) = History(c.prior).artistHistoryLane(1, c.artists[i].artistId);
            if (count != c.artists[i].records.length) revert T.InvalidRecord();
        }
        for (uint256 i; i < c.collections.length; ++i) {
            Original._lane(destinationHistory, c.prior, 2, bytes32(c.collections[i].collectionId));
            (, uint64 count) =
                History(c.prior).artistHistoryLane(2, bytes32(c.collections[i].collectionId));
            if (count != c.collections[i].records.length) revert T.InvalidRecord();
        }
    }
}
