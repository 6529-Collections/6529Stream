// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredAggregateRatificationFacts as RatificationFacts
} from "./StreamArtistRecoveredAggregateRatificationFacts.sol";
import {
    StreamArtistRecoveredAggregateSanctionIdentityFacts as SanctionIdentity
} from "./StreamArtistRecoveredAggregateSanctionIdentityFacts.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
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

/// @notice Original identity checks and global grant conservation in their original order.
library StreamArtistPrimaryCollaboratorFamilyValidation {
    struct Context {
        bytes[] identities;
        M.State scope;
        PC.BindingInventory bindings;
        PC.Inventory archive;
        PC.PrimaryReceipt[] primary;
        RH.Provenance provenance;
        G.Inventory generations;
        G.Consents[] consents;
        bytes[] attestations;
    }

    function validate(
        Context calldata c,
        H.Inventory calldata sanctions,
        T.RatificationRecord[][] calldata ratifications
    ) public view {
        IdentityFacts.validate(
            IdentityFacts.Context(
                c.identities, c.scope, c.bindings, c.archive, c.primary, c.provenance
            )
        );
        if (sanctions.sanctions.length != 0) {
            SanctionIdentity.validate(c.identities, c.scope, sanctions, c.provenance);
        }
        bool hasRatifications;
        for (uint256 i; i < ratifications.length; ++i) {
            if (ratifications[i].length != 0) hasRatifications = true;
        }
        if (hasRatifications) {
            RatificationFacts.validate(c.identities, c.scope, c.provenance, ratifications);
        }
        Conservation.Context memory conservation = Conservation.Context(
            c.identities, c.scope, c.consents, c.attestations, c.generations, c.provenance
        );
        if (sanctions.sanctions.length != 0) Conservation.validateSupplemented(conservation);
        else if (hasRatifications) Conservation.validateRatified(conservation);
        else Conservation.validate(conservation);
    }
}
