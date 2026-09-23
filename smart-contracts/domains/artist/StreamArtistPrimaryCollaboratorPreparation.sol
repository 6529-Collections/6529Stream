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

/// @notice Distinct complete aggregate composition for original Consent14/15/16/17/20/21 and grants.
import {
    StreamArtistPrimaryCollaboratorPreparationPrincipals as Principals
} from "./StreamArtistPrimaryCollaboratorPreparationPrincipals.sol";

import {
    StreamArtistPrimaryCollaboratorPreparationAdmitted as Admitted
} from "./StreamArtistPrimaryCollaboratorPreparationAdmitted.sol";

library StreamArtistPrimaryCollaboratorPreparation {
    struct Context {
        T.SuiteConfiguration destination;
        RH.Request request;
        T.RoyaltyFreeze[] royalties;
        bool requireInventory;
        Admission.Certificate admission;
    }

    /// @dev Compiler-owned memory frame; every former local retains its exact nominal type.

    function encode(
        T.SuiteConfiguration memory destination,
        RH.Request memory request,
        T.RoyaltyFreeze[] memory royalties,
        bool requireInventory
    ) public view returns (bytes memory) {
        Context memory context;
        context.destination = destination;
        context.request = request;
        context.royalties = royalties;
        context.requireInventory = requireInventory;
        context.admission = NewAdmission.collect(destination, request);
        return encodeAdmitted(context);
    }

    /// @dev The caller passes the one complete admission; this entry never recollects source history.
    function encodeAdmitted(Context memory input) public view returns (bytes memory) {
        return Admitted.encode(input);
    }
}
