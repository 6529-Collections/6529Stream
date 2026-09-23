// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

/// @notice Canonical Platform rows within one complete seven-owner inventory.
/// @dev The enclosing inventory carries the complete Archive catalogue once. The original
/// Platform record types and domains are unchanged; a row cannot carry a second catalogue.
library StreamArtistCompleteHistoryPlatformTypes {
    function requireRow(P.Platform memory p, RH.OwnerProvenance memory owner4) internal pure {
        if (
            p.collectionId == 0 || p.provenance != RH.ownerProvenanceHash(owner4, 4)
                || p.catalogues.length != 0 || p.operations.length != 0
                || p.continuations.length > P.MAX_ROWS
        ) revert RH.InvalidRecoveredHydrationProfile();
    }
}
