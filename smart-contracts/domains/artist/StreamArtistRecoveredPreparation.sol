// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHistoryRecordStage as RecordStage
} from "./StreamArtistRecoveredHistoryRecordStage.sol";

import {
    StreamArtistRecoveredPlatformStage as PlatformStage
} from "./StreamArtistRecoveredPlatformStage.sol";
import {
    StreamArtistRecoveredPlatformCollection as PlatformCollection
} from "./StreamArtistRecoveredPlatformCollection.sol";
import {
    StreamArtistRecoveredHistoryContentSelection as HistoryContentSelection
} from "./StreamArtistRecoveredHistoryContentSelection.sol";
import {
    StreamArtistRecoveredHistoryContentStage as HistoryContentStage
} from "./StreamArtistRecoveredHistoryContentStage.sol";
import {
    StreamArtistRecoveredSanctionStage as SanctionStage
} from "./StreamArtistRecoveredSanctionStage.sol";
import {
    StreamArtistRecoveredDisputeStage as DisputeStage
} from "./StreamArtistRecoveredDisputeStage.sol";
import {
    StreamArtistRecoveredDisputeSelection as DisputeSelection
} from "./StreamArtistRecoveredDisputeSelection.sol";
import {
    StreamArtistRecoveredAcceptedGenerationStage as AcceptedStage
} from "./StreamArtistRecoveredAcceptedGenerationStage.sol";
import {
    StreamArtistRecoveredBindingCorrectionHydration as Corrections
} from "./StreamArtistRecoveredBindingCorrectionHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredHydrationAdmission as Admission
} from "./StreamArtistRecoveredHydrationAdmission.sol";
import {
    StreamArtistRecoveredHydrationCommit as Commit
} from "./StreamArtistRecoveredHydrationCommit.sol";
import {
    StreamArtistRecoveredIdentityHydrationSource as Identity
} from "./StreamArtistRecoveredIdentityHydrationSource.sol";
import {
    StreamArtistRecoveredPreparationWitnesses as Witnesses
} from "./StreamArtistRecoveredPreparationWitnesses.sol";
import {
    StreamArtistRecoveredPreparationIdentityRead as IdentityRead
} from "./StreamArtistRecoveredPreparationIdentityRead.sol";
import {
    StreamArtistRecoveredPreparationPayout as PayoutStage
} from "./StreamArtistRecoveredPreparationPayout.sol";
import {
    StreamArtistRecoveredPreparationEvidence as EvidenceStage
} from "./StreamArtistRecoveredPreparationEvidence.sol";
import {
    StreamArtistRecoveredPreparationAttestations as AttestationStage
} from "./StreamArtistRecoveredPreparationAttestations.sol";
import {
    StreamArtistRecoveredPreparationConsents as ConsentStage
} from "./StreamArtistRecoveredPreparationConsents.sol";
import {
    StreamArtistRecoveredPreparationJoins as Joins
} from "./StreamArtistRecoveredPreparationJoins.sol";

import {
    StreamArtistRecoveredPreparationSeal as Seal
} from "./StreamArtistRecoveredPreparationSeal.sol";

import {
    StreamArtistRecoveredPreparationOwners as Owners
} from "./StreamArtistRecoveredPreparationOwners.sol";

import {
    StreamArtistRecoveredPreparationSelection as Selection
} from "./StreamArtistRecoveredPreparationSelection.sol";
import {
    StreamArtistRecoveredPreparationGenerations as GenerationStage
} from "./StreamArtistRecoveredPreparationGenerations.sol";

import {
    StreamArtistRecoveredRatificationStage as RatificationStage
} from "./StreamArtistRecoveredRatificationStage.sol";

import {
    StreamArtistRecoveredPreparationConsentSelection as ConsentSelection
} from "./StreamArtistRecoveredPreparationConsentSelection.sol";

/// @notice Complete fixed typed recovered-authority preparation in original check order.
import {
    StreamArtistRecoveredHistoryRecordPreparationRoutes as HistoryRoutes
} from "./StreamArtistRecoveredHistoryRecordPreparationRoutes.sol";

library StreamArtistRecoveredPreparation {
    function encode(
        T.SuiteConfiguration memory destination,
        RH.Request memory request,
        T.RoyaltyFreeze[] memory royaltyFreezes,
        bool requireInventory
    ) public view returns (bytes memory) {
        Commit.Prepared memory prepared;
        if (
            request.records.authority.artistIds.length != 1
                || request.records.authority.collections.length != 1
        ) revert T.UnsupportedProfile();
        prepared.admission = Admission.collect(destination, request);
        Admission.Certificate memory c = prepared.admission;
        prepared.query = c.collections[0];
        if (prepared.query.artistId != c.artists[0].artistId) revert T.InvalidRecord();
        // Identity retains signatures for the entire original artist lane, including secondary
        // occurrences. Collection owners read their exact typed selectors from the same query.
        prepared.query.records = c.artists[0].records;
        Owners.Context memory context;
        context.source = c.source;
        context.destination = destination;
        context.provenance = c.provenance;
        context.query = prepared.query;
        context.expected = request.expectedCapabilities;
        context.replayOrigins = request.records.authority.replayOrigins;
        bytes memory attestationInputs;
        (context.economics, attestationInputs, context.hasAttestations) =
            Witnesses.collect(c.source, c.provenance, prepared.query, request.records.witnesses);
        context.identity = IdentityRead.collect(
            c.source.owners[2], prepared.query, RH.ownerProvenance(c.provenance, 2)
        );
        bool payoutContinuations;
        (context.payout, payoutContinuations) =
            PayoutStage.collect(c.source.owners[5], prepared.query.artistId, c.provenance);
        bool hasIdentityDelegations;
        (prepared.externalGuards, prepared.timing, context.features, hasIdentityDelegations) =
            EvidenceStage.collect(
                context.identity, c.provenance, c.source.owners[2], payoutContinuations
            );
        uint8 consentMode;
        (
            context.generations,
            context.consent,
            consentMode,
            context.hasGenerations,
            context.features
        ) =
            HistoryRoutes.collect(
                context,
                royaltyFreezes,
                attestationInputs,
                hasIdentityDelegations,
                request.records.witnesses.length
            );
        if (context.hasGenerations) context.features |= RH.BINDING_GENERATIONS;
        if (c.provenance.journals[3].length > 1) context.features |= RH.ACCEPTED_GENERATIONS;
        if (Corrections.selected(RH.ownerProvenance(c.provenance, 0))) {
            if (!context.hasGenerations) revert T.UnsupportedProfile();
            context.features |= RH.BINDING_CORRECTIONS;
        }
        if (context.economics.length != 0) context.features |= RH.DIRECT_ECONOMICS;
        bytes memory attestationRecords = AttestationStage.emptyRecords();
        if (context.hasAttestations && (context.features & RH.HISTORY_RECORDS) == 0) {
            context.features |= RH.ATTESTATIONS;
            (context.attestations, attestationRecords) = AttestationStage.collect(
                c.source.owners[4],
                prepared.query,
                RH.ownerProvenance(c.provenance, 4),
                attestationInputs
            );
        }
        (context.hasDelegation, context.hasContent) =
            Selection.flagsForMode(consentMode, hasIdentityDelegations, c.provenance.journals[6]);
        if (context.hasDelegation) context.features |= RH.DELEGATED_CONSENT;
        (context.consent, context.features) = ConsentSelection.complete(
            context, royaltyFreezes, consentMode, hasIdentityDelegations, attestationRecords
        );
        prepared.data = Owners.collect(context);
        return Seal.encode(prepared, requireInventory, request.expectedSemanticInventory);
    }
}
