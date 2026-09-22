// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredAggregateSanctionIdentityFacts as SanctionIdentity
} from "./StreamArtistRecoveredAggregateSanctionIdentityFacts.sol";
import {
    StreamArtistRecoveredAggregateSanctionConsentTransport as SanctionConsent
} from "./StreamArtistRecoveredAggregateSanctionConsentTransport.sol";
import {
    StreamArtistRecoveredAggregateSanctionAttributionTransport as SanctionAttribution
} from "./StreamArtistRecoveredAggregateSanctionAttributionTransport.sol";
import {
    StreamArtistRecoveredSanctionCatalogue as SanctionCatalogue
} from "./StreamArtistRecoveredSanctionCatalogue.sol";
import {
    StreamArtistRecoveredAggregateRatificationFacts as RatificationFacts
} from "./StreamArtistRecoveredAggregateRatificationFacts.sol";
import {
    StreamArtistRecoveredMultipleGenerationConsentCollection as ConsentCollection
} from "./StreamArtistRecoveredMultipleGenerationConsentCollection.sol";
import {
    StreamArtistPrimaryCollaboratorEncoding as Encoding
} from "./StreamArtistPrimaryCollaboratorEncoding.sol";
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
    StreamArtistPrimaryCollaboratorIdentityFacts as IdentityFacts
} from "./StreamArtistPrimaryCollaboratorIdentityFacts.sol";
import {
    StreamArtistRecoveredMultipleGenerationConservation as Conservation
} from "./StreamArtistRecoveredMultipleGenerationConservation.sol";

import {
    StreamArtistPrimaryCollaboratorComposition as Composition
} from "./StreamArtistPrimaryCollaboratorComposition.sol";

import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistPrimaryCollaboratorSourceProof as Source
} from "./StreamArtistPrimaryCollaboratorSourceProof.sol";

/// @notice Original consent/attestation families, identity and global conservation followed by encoding.
/// @dev Complete original graph and chronology are supplied after the unchanged source prelude.
library StreamArtistPrimaryCollaboratorFamilyComposition {
    struct Context {
        Composition.Context source;
        PC.Proof proof;
        Source.Result observed;
        A.AttributionBundle[] history;
    }

    function collect(Context memory c) public view returns (Composition.Result memory result) {
        H.Inventory memory empty;
        return collect(c, empty);
    }

    function collect(Context memory c, H.Inventory memory sanctions)
        public
        view
        returns (Composition.Result memory result)
    {
        (G.Consents[] memory consents, T.RatificationRecord[][] memory ratifications) = ConsentCollection.collectSupplemented(
            ConsentCollection.Context(
                c.source.source.owners[6],
                c.source.provenance,
                c.source.scope,
                c.source.economics,
                c.source.freezes
            ),
            c.observed.generations.bindings,
            sanctions
        );
        bytes[] memory attestations = Attestations.collect(
            c.source.source.owners[4],
            Queries.project(c.source.scope, RH.ownerProvenance(c.source.provenance, 4)),
            RH.ownerProvenance(c.source.provenance, 4),
            c.source.attestations,
            c.observed.generations,
            c.observed.clocks.clocks,
            sanctions.sanctions.length != 0
        );
        IdentityFacts.validate(
            IdentityFacts.Context(
                c.source.identities,
                c.source.scope,
                c.proof.bindings,
                c.proof.archive,
                c.observed.clocks.primary,
                c.source.provenance
            )
        );
        if (sanctions.sanctions.length != 0) {
            SanctionIdentity.validate(
                c.source.identities, c.source.scope, sanctions, c.source.provenance
            );
        }
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
            c.observed.generations,
            c.source.provenance
        );
        if (sanctions.sanctions.length != 0) {
            Conservation.validateSupplemented(conservation);
        } else if (hasRatifications) {
            Conservation.validateRatified(conservation);
        } else {
            Conservation.validate(conservation);
        }
        result = Encoding.encodeRatified(
            Encoding.Context(
                c.source.scope.collections.length,
                c.source.features,
                c.proof,
                c.proof.accepted,
                consents,
                attestations,
                c.history
            ),
            ratifications
        );
        if (sanctions.sanctions.length != 0) {
            SanctionCatalogue.requireCurrent(
                c.source.provenance, sanctions.catalogues, sanctions.operations
            );
            result.consents = SanctionConsent.encode(result.consents, sanctions);
            result.attribution = SanctionAttribution.encode(result.attribution, sanctions);
            result.features |= RH.SANCTION_HISTORY;
        }
        return result;
    }
}
