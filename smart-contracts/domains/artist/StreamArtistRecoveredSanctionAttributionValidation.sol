// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredSanctionTimeline as Timeline
} from "./StreamArtistRecoveredSanctionTimeline.sol";

import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredSanctionLocalProof as Local
} from "./StreamArtistRecoveredSanctionLocalProof.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryRows as Rows
} from "./StreamArtistRecoveredDisputeHistoryRows.sol";
import {
    StreamArtistRecoveredDisputeHistoryChains as Chains
} from "./StreamArtistRecoveredDisputeHistoryChains.sol";
import {
    StreamArtistRecoveredDisputeHistoryGuards as Guards
} from "./StreamArtistRecoveredDisputeHistoryGuards.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";

/// @notice State3 is admitted only through its exact immutable original op13 transition.
library StreamArtistRecoveredSanctionAttributionValidation {
    function validate(H.AttributionBundle memory b, AH.Query memory q, RH.OwnerProvenance memory p)
        public
        view
    {
        Local.validate(p, 4, q, b.history);
        Rows.validateSanctioned(b.original, q, p);
        Chains.validateSanctioned(b.original, p);
        RH.Point[] memory points = new RH.Point[](b.history.confirmations.length);
        for (uint256 i; i < points.length; ++i) {
            points[i] = b.history.confirmations[i].attributionPoint;
        }
        Guards.validateSanctioned(b.original, p, points);
        Timeline.validate(b, p);
    }
}
