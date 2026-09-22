// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistPrimaryCollaboratorOwners as Owners
} from "./StreamArtistPrimaryCollaboratorOwners.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
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
    StreamArtistRecoveredTimingTypes as TM
} from "../../interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";
import {
    IStreamArtistRecoveredHydrationOwner as Owner
} from "../../interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    StreamArtistRecoveredHydrationCommit as Commit
} from "./StreamArtistRecoveredHydrationCommit.sol";
import {
    StreamArtistRecoveredHydrationAdmission as Admission
} from "./StreamArtistRecoveredHydrationAdmission.sol";
import {
    StreamArtistPrimaryCollaboratorIdentitySource as Identity
} from "./StreamArtistPrimaryCollaboratorIdentitySource.sol";
import {
    StreamArtistRecoveredMultipleConsentNonces as Nonces
} from "./StreamArtistRecoveredMultipleConsentNonces.sol";
import {
    StreamArtistPrimaryCollaboratorCodec as Codec
} from "./StreamArtistPrimaryCollaboratorCodec.sol";
import {
    StreamArtistRecoveredMultipleConsentCollectionSource as Collections
} from "./StreamArtistRecoveredMultipleConsentCollectionSource.sol";
import {
    StreamArtistRecoveredPreparationPayout as Payout
} from "./StreamArtistRecoveredPreparationPayout.sol";
import {
    StreamArtistRecoveredPreparationEvidence as Evidence
} from "./StreamArtistRecoveredPreparationEvidence.sol";
import {
    StreamArtistRecoveredExternalGuards as External
} from "./StreamArtistRecoveredExternalGuards.sol";
import {
    StreamArtistRecoveredPreparationTuple as Tuple
} from "./StreamArtistRecoveredPreparationTuple.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredPayloadHydration as Publications
} from "./StreamArtistRecoveredPayloadHydration.sol";
import {
    StreamArtistRecoveredHydrationGuards as Guards
} from "./StreamArtistRecoveredHydrationGuards.sol";
import {
    StreamArtistRecoveredHydrationCodec as OuterCodec
} from "./StreamArtistRecoveredHydrationCodec.sol";
import {
    StreamArtistRecoveredPreparationSeal as Seal
} from "./StreamArtistRecoveredPreparationSeal.sol";

import {
    StreamArtistRecoveredMultipleGenerationWitnesses as Witnesses
} from "./StreamArtistRecoveredMultipleGenerationWitnesses.sol";
import {
    StreamArtistRecoveredMultipleConsentReads as Reads
} from "./StreamArtistRecoveredMultipleConsentReads.sol";
import {
    StreamArtistRecoveredMultipleConsentValidation as Validation
} from "./StreamArtistRecoveredMultipleConsentValidation.sol";
import {
    StreamArtistRecoveredMultipleConsentFacts as Facts
} from "./StreamArtistRecoveredMultipleConsentFacts.sol";
import {
    StreamArtistRecoveredContentConsentHydration as ContentH
} from "./StreamArtistRecoveredContentConsentHydration.sol";
import {
    StreamArtistRecoveredSimpleHydrationTypes as S
} from "../../interfaces/stream/artist/StreamArtistRecoveredSimpleHydrationTypes.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";

import {
    StreamArtistPrimaryCollaboratorComposition as Composition
} from "./StreamArtistPrimaryCollaboratorComposition.sol";

import {
    StreamArtistRecoveredMultipleObservations as Observations
} from "./StreamArtistRecoveredMultipleObservations.sol";

import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";

import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistPrimaryCollaboratorAdmission as NewAdmission
} from "./StreamArtistPrimaryCollaboratorAdmission.sol";

import {
    StreamArtistPrimaryCollaboratorPreparation as Preparation
} from "./StreamArtistPrimaryCollaboratorPreparation.sol";
import {
    StreamArtistPrimaryCollaboratorPreparationPrincipals as Principals
} from "./StreamArtistPrimaryCollaboratorPreparationPrincipals.sol";

/// @notice Fixed complete admitted preparation phase, after original admission.
/// @dev Carries the unchanged nominal Context and returns original complete seal bytes.
library StreamArtistPrimaryCollaboratorPreparationAdmitted {
    struct Frame {
        Owners.Context context;
        Admission.Certificate c;
        M.State scope;
        Witnesses.Plan witnesses;
        Principals.Result principals;
        Composition.Context phase;
        Composition.Result result;
    }

    function encode(Preparation.Context memory input) public view returns (bytes memory) {
        Frame memory frame;
        frame.context.prepared.admission = input.admission;
        frame.c = frame.context.prepared.admission;

        frame.scope.artists = frame.c.artists;
        frame.scope.collections = frame.c.collections;
        Identity.preparationOwners(
            frame.c.source.owners[2], frame.scope, RH.ownerProvenance(frame.c.provenance, 2)
        );
        frame.context.prepared.query = Codec.anchorQuery(frame.scope);
        frame.witnesses = Witnesses.collect(
            frame.c.source,
            frame.c.provenance,
            frame.scope,
            input.request.records.witnesses,
            input.royalties
        );
        frame.principals = abi.decode(Principals.collectEncoded(frame.c), (Principals.Result));
        frame.context.identities = frame.principals.identities;
        frame.context.payouts = frame.principals.payouts;
        frame.context.prepared.timing = frame.principals.timing;
        frame.context.prepared.externalGuards = frame.principals.externalGuards;
        frame.context.features = frame.principals.features;

        frame.phase.source = frame.c.source;
        frame.phase.provenance = frame.c.provenance;
        frame.phase.scope = frame.scope;
        frame.phase.identities = frame.context.identities;
        frame.phase.economics = frame.witnesses.economics;
        frame.phase.freezes = frame.witnesses.freezes;
        frame.phase.attestations = frame.witnesses.attestations;
        frame.phase.features = frame.context.features;
        frame.result = Composition.collect(frame.phase);
        frame.context.bindings = frame.result.bindings;
        frame.context.consents = frame.result.consents;
        frame.context.features = frame.result.features;
        frame.context.attribution = frame.result.attribution;
        frame.context.accepted = frame.result.accepted;
        frame.context.inventory = frame.result.inventory;
        frame.context.generations = frame.result.generations;
        frame.context.accounts = frame.result.accounts;
        if ((frame.context.features & ~PC.ALLOWED) != 0) revert T.UnsupportedProfile();
        frame.context.destination = input.destination;
        frame.context.expected = input.request.expectedCapabilities;
        frame.context.replayOrigins = input.request.records.authority.replayOrigins;
        return Owners.encode(
            frame.context, input.requireInventory, input.request.expectedSemanticInventory
        );
    }
}
