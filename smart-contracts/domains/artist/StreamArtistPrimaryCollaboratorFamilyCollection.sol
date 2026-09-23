// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
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

import {
    StreamArtistPrimaryCollaboratorFamilyValidation as FamilyValidation
} from "./StreamArtistPrimaryCollaboratorFamilyValidation.sol";

import {
    StreamArtistPrimaryCollaboratorCallFrames as FrameArgs
} from "./StreamArtistPrimaryCollaboratorCallFrames.sol";
import {
    StreamArtistPrimaryCollaboratorFamilyComposition as Family
} from "./StreamArtistPrimaryCollaboratorFamilyComposition.sol";

/// @notice Original consent then attestation collection over the complete input context.
library StreamArtistPrimaryCollaboratorFamilyCollection {
    struct Result {
        G.Consents[] consents;
        bytes[] attestations;
        T.RatificationRecord[][] ratifications;
    }

    function collect(bytes calldata raw, bytes calldata history)
        public
        view
        returns (bytes memory)
    {
        Family.Context calldata c = FrameArgs.family(raw);
        H.Inventory memory sanctions = abi.decode(history, (H.Inventory));
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
        return abi.encode(Result(consents, attestations, ratifications));
    }
}
