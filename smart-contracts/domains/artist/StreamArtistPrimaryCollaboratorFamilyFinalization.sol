// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistPrimaryCollaboratorComposition as Composition
} from "./StreamArtistPrimaryCollaboratorComposition.sol";
import {
    StreamArtistPrimaryCollaboratorFamilyComposition as Family
} from "./StreamArtistPrimaryCollaboratorFamilyComposition.sol";
import {
    StreamArtistPrimaryCollaboratorCallFrames as Frames
} from "./StreamArtistPrimaryCollaboratorCallFrames.sol";
import {
    StreamArtistRecoveredSanctionCatalogue as SanctionCatalogue
} from "./StreamArtistRecoveredSanctionCatalogue.sol";
import {
    StreamArtistRecoveredAggregateSanctionConsentTransport as SanctionConsent
} from "./StreamArtistRecoveredAggregateSanctionConsentTransport.sol";
import {
    StreamArtistRecoveredAggregateSanctionAttributionTransport as SanctionAttribution
} from "./StreamArtistRecoveredAggregateSanctionAttributionTransport.sol";

/// @notice Original late catalogue and complete returned carrier updates after row encoding.
library StreamArtistPrimaryCollaboratorFamilyFinalization {
    function finish(bytes calldata context, bytes calldata encoded, bytes calldata history)
        public
        view
        returns (bytes memory)
    {
        Family.Context calldata c = Frames.family(context);
        H.Inventory memory sanctions = abi.decode(history, (H.Inventory));
        if (sanctions.sanctions.length == 0) return encoded;
        Composition.Result memory result = abi.decode(encoded, (Composition.Result));
        SanctionCatalogue.requireCurrent(
            c.source.provenance, sanctions.catalogues, sanctions.operations
        );
        result.consents = SanctionConsent.encode(result.consents, sanctions);
        result.attribution = SanctionAttribution.encode(result.attribution, sanctions);
        result.features |= RH.SANCTION_HISTORY;
        return abi.encode(result);
    }
}
