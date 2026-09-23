// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredSanctionConsentCollection as ConsentCollection
} from "./StreamArtistRecoveredSanctionConsentCollection.sol";

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
    StreamArtistRecoveredSanctionAttributionValidation as Attribution
} from "./StreamArtistRecoveredSanctionAttributionValidation.sol";
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

/// @notice Complete original sanctions and executed confirmations, before any op60 owner write.
library StreamArtistRecoveredSanctionStage {
    function selected(RH.Provenance memory p) public pure returns (bool) {
        for (uint256 i; i < p.journals[6].length; ++i) {
            if (p.journals[6][i].receipt.operation == 12) return true;
        }
        for (uint256 i; i < p.aliases[6].length; ++i) {
            if (p.aliases[6][i].surface == H.CONFIRMATION) return true;
        }
        return false;
    }

    function collect(
        T.SuiteConfiguration memory source,
        AH.Query memory q,
        RH.Provenance memory p,
        bytes memory identity,
        T.EconomicsConsent[] memory economics,
        uint256 royalties
    )
        public
        view
        returns (bytes memory generations, bytes memory consent, uint8 mode, bool multiple)
    {
        if (royalties != 0) revert T.UnsupportedProfile();
        CB.Bundle memory b = Binding.collect(source.owners[0], q, RH.ownerProvenance(p, 0));
        Acceptance.collect(source.owners[3], q, RH.ownerProvenance(p, 3), b.bindings);
        H.Inventory memory history = Rows.collect(source.owners[6], q, p, b.bindings);
        H.AttributionBundle memory attribution = H.AttributionBundle(
            Collection.collectForSanctionHistory(source.owners[4], q, p, b), history
        );
        Attribution.validate(attribution, q, RH.ownerProvenance(p, 4));
        Consent.Bundle memory c = ConsentCollection.collect(
            source.owners[6], q, RH.ownerProvenance(p, 6), economics, b.bindings, history
        );
        if (address(Facts).code.length == 0) assembly ("memory-safe") { revert(0, 0) }
        (bool ok, bytes memory out) = address(Facts)
            .staticcall(
                bytes.concat(
                    Facts.validate.selector,
                    Tuple.two(
                        identity,
                        abi.encode(
                            Facts.Context(b.bindings, attribution.original, c.base, q, p, history)
                        )
                    )
                )
            );
        Tuple.result(ok, out);
        Catalogue.requireCurrent(p, history.catalogues, history.operations);
        return (
            abi.encode(b.bindings),
            Consent.encode(c, q, RH.ownerProvenance(p, 6)),
            b.bindings.current.consentMode,
            b.bindings.rows.length > 1
        );
    }
}
