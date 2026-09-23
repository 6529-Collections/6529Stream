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

import {
    StreamArtistRecoveredSanctionAttributionValidation as Validation
} from "./StreamArtistRecoveredSanctionAttributionValidation.sol";

/// @notice Closed canonical original sanction-history tuple; complete validation precedes import.
library StreamArtistRecoveredSanctionAttributionCodec {
    function encode(H.AttributionBundle memory b, AH.Query memory q, RH.OwnerProvenance memory p)
        public
        view
        returns (bytes memory)
    {
        Validation.validate(b, q, p);
        return abi.encode(H.ATTRIBUTION, RH.VERSION, b);
    }

    function decode(AH.Query memory q, RH.OwnerProvenance memory p, bytes memory raw)
        public
        view
        returns (H.AttributionBundle memory b)
    {
        bytes32 tag;
        uint16 version;
        (tag, version, b) = abi.decode(raw, (bytes32, uint16, H.AttributionBundle));
        if (
            tag != H.ATTRIBUTION || version != RH.VERSION
                || keccak256(raw) != keccak256(abi.encode(tag, version, b))
        ) _invalid();
        Validation.validate(b, q, p);
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
