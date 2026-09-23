// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

/// @notice Fixed original aggregate envelope dispatch shared by additive Consent workers.
library StreamArtistRecoveredAggregateConsentEnvelope {
    function decode(AH.Query memory anchor, bytes memory outer)
        public
        view
        returns (bool selected, M.State memory scope, Payload.Payload memory payload)
    {
        RH.Envelope memory e = Envelope.decode(outer, 6);
        uint256 family = e.header.requiredFeatures & (G.FEATURE | MD.FEATURE | PC.FEATURE);
        if (family == 0) return (false, scope, payload);
        if (family == MD.FEATURE) {
            (scope, payload) = Disputes.outer(6, anchor, outer);
        } else if (family == PC.FEATURE) {
            (scope, payload,) = Collaborators.collect(6, anchor, outer);
        } else if (family == G.FEATURE) {
            (scope, payload) = Generations.outer(6, anchor, outer);
        } else {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        return (true, scope, payload);
    }
}
