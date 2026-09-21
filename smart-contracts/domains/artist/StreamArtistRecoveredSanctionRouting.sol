// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveredHistoryContentTypes as HistoryContentTypes } from "./StreamArtistRecoveredHistoryContentTypes.sol";
import { StreamArtistRecoveredHistoryContentCodec as HistoryContentCodec } from "./StreamArtistRecoveredHistoryContentCodec.sol";

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import { StreamArtistRecoveredSanctionRows as Rows } from "./StreamArtistRecoveredSanctionRows.sol";
import {
    StreamArtistRecoveredSanctionCatalogue as Catalogue
} from "./StreamArtistRecoveredSanctionCatalogue.sol";
import {
    StreamArtistRecoveredSanctionAttributionCodec as Attribution
} from "./StreamArtistRecoveredSanctionAttributionCodec.sol";
import {
    StreamArtistRecoveredSanctionConsentHistory as Consent
} from "./StreamArtistRecoveredSanctionConsentHistory.sol";
import {
    StreamArtistRecoveredSanctionCompositionFacts as Facts
} from "./StreamArtistRecoveredSanctionCompositionFacts.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredDisputeBindingHydration as Binding
} from "./StreamArtistRecoveredDisputeBindingHydration.sol";
import {
    StreamArtistRecoveredDisputeAcceptanceHistory as Acceptance
} from "./StreamArtistRecoveredDisputeAcceptanceHistory.sol";
import {
    StreamArtistRecoveredDisputeHistoryCollection as Collection
} from "./StreamArtistRecoveredDisputeHistoryCollection.sol";
import {
    StreamArtistRecoveredDisputeStage as Original
} from "./StreamArtistRecoveredDisputeStage.sol";
import {
    StreamArtistRecoveredPreparationTuple as Tuple
} from "./StreamArtistRecoveredPreparationTuple.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";

/// @notice Fixed new-profile owner encoding and post-write source recheck.
library StreamArtistRecoveredSanctionRouting {
    function ownerState(
        T.SuiteConfiguration memory source,
        AH.Query memory q,
        RH.Provenance memory p,
        bytes memory raw,
        uint8 ownerIndex
    ) public view returns (bytes memory) {
        if (ownerIndex != 4) {
            return Original.ownerState(source, q, p, raw, ownerIndex);
        }
        CB.Bundle memory b = Binding.collect(source.owners[0], q, RH.ownerProvenance(p, 0));
        if (keccak256(raw) != keccak256(abi.encode(b.bindings))) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        return Attribution.encode(
            H.AttributionBundle(
                Collection.collectForSanctionHistory(source.owners[4], q, p, b),
                Rows.collect(source.owners[6], q, p, b.bindings)
            ),
            q,
            RH.ownerProvenance(p, 4)
        );
    }

    function requireCurrent(AH.Query memory q, RH.Provenance memory p, bytes memory consentOuter)
        public
        view
    {
        (RH.ExportHeader memory h, Payload.Payload memory payload) = Payload.decode(consentOuter, 6);
        if ((h.requiredFeatures & RH.SANCTION_HISTORY) == 0) return;
        if ((h.requiredFeatures & RH.HISTORY_CONTENT) != 0) {
            HistoryContentTypes.Bundle memory full = HistoryContentCodec.decode(q,payload.provenance,payload.semanticState);
            Catalogue.requireCurrent(p,full.sanctions.catalogues,full.sanctions.operations);
            return;
        }
        Consent.Bundle memory b = Consent.decode(q, payload.provenance, payload.semanticState);
        Catalogue.requireCurrent(p, b.history.catalogues, b.history.operations);
    }
}
