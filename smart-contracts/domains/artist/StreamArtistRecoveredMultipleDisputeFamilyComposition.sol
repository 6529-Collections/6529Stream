// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredAggregateRatificationFacts as RatificationFacts
} from "./StreamArtistRecoveredAggregateRatificationFacts.sol";

import {
    StreamArtistRecoveredMultipleGenerationConsentCollection as ConsentCollection
} from "./StreamArtistRecoveredMultipleGenerationConsentCollection.sol";
import {
    StreamArtistRecoveredMultipleDisputeEncoding as Encoding
} from "./StreamArtistRecoveredMultipleDisputeEncoding.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationClocks as Clocks
} from "./StreamArtistRecoveredMultipleGenerationClocks.sol";
import {
    StreamArtistRecoveredMultipleDisputeAttestationQueries as Queries
} from "./StreamArtistRecoveredMultipleDisputeAttestationQueries.sol";
import {
    StreamArtistRecoveredMultipleDisputeAttestationSource as Attestations
} from "./StreamArtistRecoveredMultipleDisputeAttestationSource.sol";
import {
    StreamArtistRecoveredMultipleDisputeIdentityFacts as IdentityFacts
} from "./StreamArtistRecoveredMultipleDisputeIdentityFacts.sol";
import {
    StreamArtistRecoveredMultipleDisputeConservation as Conservation
} from "./StreamArtistRecoveredMultipleDisputeConservation.sol";
import {
    StreamArtistRecoveredMultipleDisputeComposition as Composition
} from "./StreamArtistRecoveredMultipleDisputeComposition.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";

/// @notice Original consent/attestation families, identity and global conservation followed by encoding.
/// @dev Complete original graph and chronology are supplied after the unchanged source prelude.

library StreamArtistRecoveredMultipleDisputeFamilyComposition {
    struct Context {
        Composition.Context source;
        G.Inventory inventory;
        Clocks.Result clocks;
        A.AcceptanceBundle[] accepted;
        D.Bundle[] history;
    }

    function collect(Context memory c) public view returns (Composition.Result memory result) {
        (G.Consents[] memory consents, T.RatificationRecord[][] memory ratifications) = ConsentCollection.collectRatified(
            ConsentCollection.Context(
                c.source.source.owners[6],
                c.source.provenance,
                c.source.scope,
                c.source.economics,
                c.source.freezes
            ),
            c.inventory.bindings
        );
        bytes[] memory attestations = Attestations.collect(
            c.source.source.owners[4],
            Queries.project(c.source.scope, RH.ownerProvenance(c.source.provenance, 4)),
            RH.ownerProvenance(c.source.provenance, 4),
            c.source.attestations,
            c.inventory,
            c.clocks
        );
        IdentityFacts.validate(
            IdentityFacts.Context(
                c.source.identities, c.source.scope, c.inventory, c.accepted, c.source.provenance
            )
        );
        bool hasRatifications;
        for (uint256 i; i < ratifications.length; ++i) {
            if (ratifications[i].length != 0) hasRatifications = true;
        }
        if (hasRatifications) {
            RatificationFacts.validate(
                c.source.identities, c.source.scope, c.source.provenance, ratifications
            );
        }
        Conservation.Context memory conservation = Conservation.Context(
            c.source.identities,
            c.source.scope,
            consents,
            attestations,
            c.inventory,
            c.source.provenance,
            c.history
        );
        if (hasRatifications) {
            Conservation.validateRatified(conservation);
        } else {
            Conservation.validate(conservation);
        }
        return Encoding.encodeRatified(
            Encoding.Context(
                c.source.scope.collections.length,
                c.source.features,
                c.inventory,
                c.accepted,
                consents,
                attestations,
                c.history
            ),
            ratifications
        );
    }
}
