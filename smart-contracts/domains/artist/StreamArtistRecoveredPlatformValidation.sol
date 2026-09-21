// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredPlatformOrdering as Ordering
} from "./StreamArtistRecoveredPlatformOrdering.sol";
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredPlatformParts as Parts
} from "./StreamArtistRecoveredPlatformParts.sol";
import {
    StreamArtistRecoveredPlatformNativeRows as Native
} from "./StreamArtistRecoveredPlatformNativeRows.sol";
import {
    StreamArtistRecoveredPlatformDisputeRows as Rows
} from "./StreamArtistRecoveredPlatformDisputeRows.sol";
import {
    StreamArtistRecoveredPlatformGuards as Guards
} from "./StreamArtistRecoveredPlatformGuards.sol";
import {
    StreamArtistRecoveredPlatformTimeline as PlatformTimeline
} from "./StreamArtistRecoveredPlatformTimeline.sol";
import {
    StreamArtistRecoveredPlatformBindingSource as BindingSource
} from "./StreamArtistRecoveredPlatformBindingSource.sol";
import {
    StreamArtistRecoveredDisputeHistoryChains as Chains
} from "./StreamArtistRecoveredDisputeHistoryChains.sol";
import {
    StreamArtistRecoveredSanctionTimeline as Timeline
} from "./StreamArtistRecoveredSanctionTimeline.sol";
import {
    StreamArtistRecoveredSanctionLocalProof as Local
} from "./StreamArtistRecoveredSanctionLocalProof.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

/// @notice Complete original owner4 Platform, dispute and confirmation history in one closed profile.
library StreamArtistRecoveredPlatformValidation {
    function validateEncoded(bytes memory raw, AH.Query memory q, RH.OwnerProvenance memory p)
        public
        view
    {
        P.Bundle memory b = Parts.decode(raw);
        _validate(b, q, p);
    }

    function _validate(P.Bundle memory b, AH.Query memory q, RH.OwnerProvenance memory p)
        private
        view
    {
        BindingSource.requireMatches(
            b.bindings, b.original.generations, b.platform.collectionId, q, p
        );
        if (b.sanctions.sanctions.length != 0) {
            Local.validate(p, 4, q, b.sanctions);
        } else if (
            b.sanctions.catalogues.length != 0 || b.sanctions.operations.length != 0
                || b.sanctions.confirmations.length != 0
        ) {
            _invalid();
        }
        Rows.validate(b.original, q, p, b.platform);
        D.Guard[] memory nativeGuards = Native.validate(b.platform, p);
        Chains.validateSanctioned(b.original, p);
        RH.Point[] memory confirmations = new RH.Point[](b.sanctions.confirmations.length);
        for (uint256 i; i < confirmations.length; ++i) {
            confirmations[i] = b.sanctions.confirmations[i].attributionPoint;
        }
        Guards.validate(b.original, p, confirmations, nativeGuards);
        Timeline.validate(H.AttributionBundle(b.original, b.sanctions), p);
        (RH.Point[] memory proposals, RH.Point[] memory completions) =
            PlatformTimeline.validate(b.platform, b.bindings, b.original.generations, p);
        Ordering.distinct(b.original, confirmations, nativeGuards, proposals, completions);
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
