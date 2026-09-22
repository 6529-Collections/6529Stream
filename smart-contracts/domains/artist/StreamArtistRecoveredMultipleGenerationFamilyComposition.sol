// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredMultipleGenerationConsentCollection as ConsentCollection
} from "./StreamArtistRecoveredMultipleGenerationConsentCollection.sol";
import {
    StreamArtistRecoveredMultipleGenerationEncoding as Encoding
} from "./StreamArtistRecoveredMultipleGenerationEncoding.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistReadinessHydrationTypes as ReadinessH
} from "../../interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredAttestationHydration as Records
} from "./StreamArtistRecoveredAttestationHydration.sol";
import {
    StreamArtistRecoveredMultipleGenerationBindingSource as Bindings
} from "./StreamArtistRecoveredMultipleGenerationBindingSource.sol";
import {
    StreamArtistRecoveredMultipleGenerationBindingProof as BindingProof
} from "./StreamArtistRecoveredMultipleGenerationBindingProof.sol";
import {
    StreamArtistRecoveredMultipleGenerationClocks as Clocks
} from "./StreamArtistRecoveredMultipleGenerationClocks.sol";
import {
    StreamArtistRecoveredMultipleGenerationAcceptance as Acceptance
} from "./StreamArtistRecoveredMultipleGenerationAcceptance.sol";
import {
    StreamArtistRecoveredMultipleGenerationRevocations as Revocations
} from "./StreamArtistRecoveredMultipleGenerationRevocations.sol";
import {
    StreamArtistRecoveredMultipleGenerationConsentSource as Reads
} from "./StreamArtistRecoveredMultipleGenerationConsentSource.sol";
import {
    StreamArtistRecoveredMultipleGenerationConsentValidation as Validation
} from "./StreamArtistRecoveredMultipleGenerationConsentValidation.sol";
import {
    StreamArtistRecoveredMultipleGenerationAttestationQueries as Queries
} from "./StreamArtistRecoveredMultipleGenerationAttestationQueries.sol";
import {
    StreamArtistRecoveredMultipleGenerationAttestationSource as Attestations
} from "./StreamArtistRecoveredMultipleGenerationAttestationSource.sol";
import {
    StreamArtistRecoveredMultipleGenerationIdentityFacts as IdentityFacts
} from "./StreamArtistRecoveredMultipleGenerationIdentityFacts.sol";
import {
    StreamArtistRecoveredMultipleGenerationConservation as Conservation
} from "./StreamArtistRecoveredMultipleGenerationConservation.sol";

import {
    StreamArtistRecoveredMultipleGenerationComposition as Composition
} from "./StreamArtistRecoveredMultipleGenerationComposition.sol";

/// @notice Original consent/attestation families, identity and global conservation followed by encoding.
/// @dev Complete original graph and chronology are supplied after the unchanged source prelude.
library StreamArtistRecoveredMultipleGenerationFamilyComposition {
    struct Context {
        Composition.Context source;
        G.Inventory inventory;
        Clocks.Result clocks;
        A.AcceptanceBundle[] accepted;
        A.AttributionBundle[] history;
    }

    function collect(Context memory c) public view returns (Composition.Result memory result) {
        G.Consents[] memory consents = ConsentCollection.collect(
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
        Conservation.validate(
            Conservation.Context(
                c.source.identities,
                c.source.scope,
                consents,
                attestations,
                c.inventory,
                c.source.provenance
            )
        );
        return Encoding.encode(
            Encoding.Context(
                c.source.scope.collections.length,
                c.source.features,
                c.inventory,
                c.accepted,
                consents,
                attestations,
                c.history
            )
        );
    }
}
