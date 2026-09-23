// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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
    StreamArtistRecoveredHistoryContentTypes as HC
} from "./StreamArtistRecoveredHistoryContentTypes.sol";
import {
    StreamArtistRecoveredHistoryContentCollection as Source
} from "./StreamArtistRecoveredHistoryContentCollection.sol";
import {
    StreamArtistRecoveredHistoryContentCodec as Codec
} from "./StreamArtistRecoveredHistoryContentCodec.sol";
import {
    StreamArtistRecoveredHistoryContentFacts as Facts
} from "./StreamArtistRecoveredHistoryContentFacts.sol";
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
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryCollection as Collection
} from "./StreamArtistRecoveredDisputeHistoryCollection.sol";
import {
    StreamArtistRecoveredDisputeSelection as DisputeSelection
} from "./StreamArtistRecoveredDisputeSelection.sol";
import {
    StreamArtistRecoveredSanctionStage as SanctionStage
} from "./StreamArtistRecoveredSanctionStage.sol";
import {
    StreamArtistRecoveredSanctionRows as Sanctions
} from "./StreamArtistRecoveredSanctionRows.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredSanctionAttributionValidation as Attribution
} from "./StreamArtistRecoveredSanctionAttributionValidation.sol";
import {
    StreamArtistRecoveredSanctionCatalogue as Catalogue
} from "./StreamArtistRecoveredSanctionCatalogue.sol";
import {
    StreamArtistRecoveredPreparationTuple as Tuple
} from "./StreamArtistRecoveredPreparationTuple.sol";

/// @notice Complete content/ratification composition outside the preceding supported profiles.
library StreamArtistRecoveredHistoryContentStage {
    function collect(
        T.SuiteConfiguration memory source,
        AH.Query memory q,
        RH.Provenance memory p,
        bytes memory identity,
        T.EconomicsConsent[] memory economics,
        T.RoyaltyFreeze[] memory royalties
    )
        public
        view
        returns (bytes memory generations, bytes memory consent, uint8 mode, bool multiple)
    {
        CB.Bundle memory b = Binding.collect(source.owners[0], q, RH.ownerProvenance(p, 0));
        Acceptance.collect(source.owners[3], q, RH.ownerProvenance(p, 3), b.bindings);
        H.Inventory memory history;
        D.Bundle memory attribution;
        bool sanctioned = SanctionStage.selected(p);
        if (sanctioned) {
            history = Sanctions.collect(source.owners[6], q, p, b.bindings);
            attribution = Collection.collectForSanctionHistory(source.owners[4], q, p, b);
            Attribution.validate(
                H.AttributionBundle(attribution, history), q, RH.ownerProvenance(p, 4)
            );
        } else {
            history.catalogues = new H.Catalogue[](0);
            history.operations = new H.OperationEvidence[](0);
            history.sanctions = new H.SanctionRow[](0);
            history.confirmations = new H.ConfirmationRow[](0);
            attribution = Collection.collect(source.owners[4], q, p, b);
        }
        bytes memory c = Source.collect(
            source.owners[6], q, RH.ownerProvenance(p, 6), economics, royalties, b.bindings, history
        );
        if (address(Facts).code.length == 0) assembly ("memory-safe") { revert(0, 0) }
        (bool ok, bytes memory out) = address(Facts)
            .staticcall(
                bytes.concat(
                    Facts.validate.selector,
                    Tuple.two(identity, abi.encode(Facts.Context(b.bindings, attribution, c, q, p)))
                )
            );
        Tuple.result(ok, out);
        if (sanctioned) Catalogue.requireCurrent(p, history.catalogues, history.operations);
        return
            (abi.encode(b.bindings), c, b.bindings.current.consentMode, b.bindings.rows.length > 1);
    }
}
