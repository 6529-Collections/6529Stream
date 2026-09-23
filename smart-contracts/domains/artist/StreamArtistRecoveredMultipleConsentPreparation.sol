// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredMultipleConsentOwners as Owners
} from "./StreamArtistRecoveredMultipleConsentOwners.sol";
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
    StreamArtistRecoveredMultipleConsentIdentitySource as Identity
} from "./StreamArtistRecoveredMultipleConsentIdentitySource.sol";
import {
    StreamArtistRecoveredMultipleConsentNonces as Nonces
} from "./StreamArtistRecoveredMultipleConsentNonces.sol";
import {
    StreamArtistRecoveredMultipleConsentCodec as Codec
} from "./StreamArtistRecoveredMultipleConsentCodec.sol";
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
    StreamArtistRecoveredMultipleConsentWitnesses as Witnesses
} from "./StreamArtistRecoveredMultipleConsentWitnesses.sol";
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
    StreamArtistRecoveredMultipleConsentComposition as Composition
} from "./StreamArtistRecoveredMultipleConsentComposition.sol";

import {
    StreamArtistRecoveredMultipleObservations as Observations
} from "./StreamArtistRecoveredMultipleObservations.sol";

/// @notice Distinct complete aggregate composition for original Consent14/15/16/17/20/21 and grants.
library StreamArtistRecoveredMultipleConsentPreparation {
    struct Context {
        T.SuiteConfiguration destination;
        RH.Request request;
        T.RoyaltyFreeze[] royalties;
        bool requireInventory;
        Admission.Certificate admission;
    }

    /// @dev The caller passes the one complete admission; this entry never recollects source history.
    function encodeAdmitted(Context memory input) public view returns (bytes memory) {
        Owners.Context memory context;
        context.prepared.admission = input.admission;
        Admission.Certificate memory c = context.prepared.admission;
        M.State memory scope;
        scope.artists = c.artists;
        scope.collections = c.collections;
        Identity.preparationOwners(c.source.owners[2], scope, RH.ownerProvenance(c.provenance, 2));
        context.prepared.query = Codec.anchorQuery(scope);
        (T.EconomicsConsent[][] memory economics, T.RoyaltyFreeze[][] memory freezes) = Witnesses.collect(
            c.source, c.provenance, scope, input.request.records.witnesses, input.royalties
        );
        context.identities = new bytes[](c.artists.length);
        context.payouts = new bytes[](c.artists.length);
        External.Snapshot[] memory observations = new External.Snapshot[](c.artists.length);
        context.features = RH.MULTIPLE_CONSENTS;
        for (uint256 i; i < c.artists.length; ++i) {
            (bool ok, bytes memory raw) = address(Identity)
                .staticcall(
                    abi.encodeWithSelector(
                        Identity.collect.selector,
                        c.source.owners[2],
                        c.artists[i],
                        RH.ownerProvenance(c.provenance, 2)
                    )
                );
            context.identities[i] = Tuple.result(ok, raw);
            Tuple.requireSingle(context.identities[i]);
            bool continuations;
            (raw, continuations) =
                Payout.collect(c.source.owners[5], c.artists[i].artistId, c.provenance);
            context.payouts[i] = Payout.encode(raw, c.provenance);
            TM.Checkpoint memory timing;
            uint256 selected;
            bool delegated;
            (observations[i], timing, selected, delegated) = Evidence.collect(
                context.identities[i], c.provenance, c.source.owners[2], continuations
            );
            if (
                i != 0
                    && keccak256(abi.encode(timing))
                        != keccak256(abi.encode(context.prepared.timing))
            ) revert T.UnsupportedProfile();
            context.prepared.timing = timing;
            context.features |= selected;
            if (delegated) context.features |= RH.DELEGATED_CONSENT;
        }
        context.prepared.externalGuards = Observations.collect(observations);
        Composition.Context memory phase;
        phase.source = c.source;
        phase.provenance = c.provenance;
        phase.scope = scope;
        phase.identities = context.identities;
        phase.economics = economics;
        phase.freezes = freezes;
        phase.features = context.features;
        (context.bindings, context.consents, context.features) = Composition.collect(phase);
        if (
            (context.features
                            & ~(RH.FIRST_GRAPH_FEATURES
                                | RH.DIRECT_ECONOMICS
                                | RH.DELEGATED_CONSENT
                                | RH.CONTENT_CONSENTS
                                | RH.MULTIPLE_CONSENTS)) != 0
                || (context.features
                            & (RH.DIRECT_ECONOMICS | RH.DELEGATED_CONSENT | RH.CONTENT_CONSENTS))
                    == 0
        ) revert T.UnsupportedProfile();
        context.destination = input.destination;
        context.expected = input.request.expectedCapabilities;
        context.replayOrigins = input.request.records.authority.replayOrigins;
        return
            Owners.encode(context, input.requireInventory, input.request.expectedSemanticInventory);
    }
}
