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

/// @notice Exact original fixed history-stage selection, with no state or caller-supplied target.
library StreamArtistRecoveredHistoryRecordPreparationRoutes {
    function collect(
        Owners.Context calldata context,
        T.RoyaltyFreeze[] calldata royaltyFreezes,
        bytes calldata attestationInputs,
        bool hasIdentityDelegations,
        uint256 witnessCount
    )
        public
        view
        returns (
            bytes memory generations,
            bytes memory consent,
            uint8 consentMode,
            bool hasGenerations,
            uint256 features
        )
    {
        features = context.features;
        (uint8 historyRoute, bool sanctioned, bool platformHistory) =
            PlatformStage.select(context.source, context.query, context.provenance);
        bool recordHistory = context.hasAttestations
            && (platformHistory || historyRoute != 0 || context.provenance.journals[3].length > 1);
        if (recordHistory || platformHistory) {
            uint256 historyFeatures;
            (generations, consent, consentMode, hasGenerations, historyFeatures) =
                RecordStage.collect(
                    context.source,
                    context.query,
                    context.provenance,
                    abi.encode(context.identity, attestationInputs),
                    context.economics,
                    royaltyFreezes,
                    sanctioned
                );
            features |= historyFeatures;
        } else if (historyRoute == 3) {
            if (context.hasAttestations) revert T.UnsupportedProfile();
            features |= RH.DISPUTE_HISTORY | RH.HISTORY_CONTENT;
            if (sanctioned) features |= RH.SANCTION_HISTORY;
            (generations, consent, consentMode, hasGenerations) = HistoryContentStage.collect(
                context.source,
                context.query,
                context.provenance,
                context.identity,
                context.economics,
                royaltyFreezes
            );
        } else if (historyRoute == 2) {
            if (context.hasAttestations) revert T.UnsupportedProfile();
            features |= RH.DISPUTE_HISTORY | RH.SANCTION_HISTORY;
            (generations, consent, consentMode, hasGenerations) = SanctionStage.collect(
                context.source,
                context.query,
                context.provenance,
                context.identity,
                context.economics,
                royaltyFreezes.length
            );
        } else if (historyRoute == 1) {
            if (context.hasAttestations) revert T.UnsupportedProfile();
            features |= RH.DISPUTE_HISTORY;
            (generations, consent, consentMode, hasGenerations) = DisputeStage.collect(
                context.source,
                context.query,
                context.provenance,
                context.identity,
                context.economics,
                royaltyFreezes.length
            );
        } else {
            (generations, consentMode, hasGenerations) = AcceptedStage.select(
                context.source,
                context.query,
                context.provenance,
                context.identity,
                hasIdentityDelegations,
                witnessCount,
                royaltyFreezes.length
            );
        }
    }
}
