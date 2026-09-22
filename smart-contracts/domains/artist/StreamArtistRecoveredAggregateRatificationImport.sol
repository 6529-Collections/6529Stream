// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredMultipleDisputeTypes as MD
} from "./StreamArtistRecoveredMultipleDisputeTypes.sol";
import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationCodec as Generations
} from "./StreamArtistRecoveredMultipleGenerationCodec.sol";
import {
    StreamArtistRecoveredMultipleDisputeCodec as Disputes
} from "./StreamArtistRecoveredMultipleDisputeCodec.sol";
import {
    StreamArtistPrimaryCollaboratorDecode as Collaborators
} from "./StreamArtistPrimaryCollaboratorDecode.sol";
import {
    StreamArtistRecoveredHydrationCodec as Envelope
} from "./StreamArtistRecoveredHydrationCodec.sol";
import {
    StreamArtistRecoveredAggregateRatificationRows as Rows
} from "./StreamArtistRecoveredAggregateRatificationRows.sol";
import {
    StreamArtistRecoveredHistoryContentWrites as Writes
} from "./StreamArtistRecoveredHistoryContentWrites.sol";

/// @notice Original52 map installation inside the existing guarded aggregate owner6 transaction.
/// @dev The owner MUST next run its existing aggregate Consent import, which validates the
/// complete combined journal, eras and aliases. A later failure rolls these writes back too.
/// Only two existing map roots cross this entry; the existing Consent map ABI is unchanged.
library StreamArtistRecoveredAggregateRatificationImport {
    function applyState(
        mapping(uint256 => T.RatificationRecord) storage current,
        mapping(bytes32 => T.RatificationRecord) storage records,
        AH.Query memory anchor,
        bytes memory outer
    ) public returns (bool) {
        RH.Envelope memory e = Envelope.decode(outer, 6);
        uint256 selected = e.header.requiredFeatures & (G.FEATURE | MD.FEATURE | PC.FEATURE);
        if (selected == 0 || (e.header.requiredFeatures & RH.RATIFICATIONS) == 0) return false;
        M.State memory scope;
        if (selected == MD.FEATURE) {
            (scope,) = Disputes.outer(6, anchor, outer);
        } else if (selected == PC.FEATURE) {
            (scope,,) = Collaborators.collect(6, anchor, outer);
        } else if (selected == G.FEATURE) {
            (scope,) = Generations.outer(6, anchor, outer);
        } else {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        (, T.RatificationRecord[][] memory ratifications) = Rows.decodeRows(scope.rows, true);
        for (uint256 i; i < scope.collections.length; ++i) {
            Writes.importRecords(
                current, records, scope.collections[i].collectionId, ratifications[i]
            );
        }
        return true;
    }
}
