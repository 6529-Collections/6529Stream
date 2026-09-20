// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamArtistRecoveredHydration
} from "../../interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    IStreamArtistRecoveredConsentHydration
} from "../../interfaces/stream/artist/IStreamArtistRecoveredConsentHydration.sol";
import "../../interfaces/stream/artist/IStreamArtistMultipleRecordsHydration.sol";
import "../../interfaces/stream/artist/IStreamArtistMultipleAuthorityHydration.sol";
import "../../interfaces/stream/artist/IStreamArtistDelegationAuthorityHydration.sol";
import "../../interfaces/stream/artist/IStreamArtistDelegatedConsent.sol";
import "../../interfaces/stream/artist/IStreamArtistDisputeWithdrawal.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";
import {
    StreamArtistRepudiationTypes as RP
} from "../../interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";

import "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    StreamArtistAttributionDisputeTypes as AD
} from "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";

import {
    StreamArtistEntropyUnavailabilityTypes as EU,
    IStreamArtistEntropyUnavailability,
    IStreamArtistEntropyUnavailabilityOwner,
    IStreamArtistEntropyUnavailabilityCoordinator
} from "../../interfaces/stream/artist/IStreamArtistEntropyUnavailability.sol";

import "../../interfaces/stream/artist/IStreamArtistPublicationAuthorityHydration.sol";
import "../../interfaces/stream/artist/IStreamArtistEntropyFindingHydration.sol";
import {
    IStreamArtistReadinessAuthorityHydration
} from "../../interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    IStreamArtistEconomicsAuthorityHydration
} from "../../interfaces/stream/artist/IStreamArtistEconomicsAuthorityHydration.sol";
import {
    IStreamArtistPayoutAuthorityHydration
} from "../../interfaces/stream/artist/IStreamArtistPayoutAuthorityHydration.sol";
import {
    IStreamArtistAuthorityHydration
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import { IStreamArtistHistory } from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistRecoveryApproval
} from "../../interfaces/stream/artist/IStreamArtistRecoveryApproval.sol";
import {
    IStreamArtistUnavailability
} from "../../interfaces/stream/artist/IStreamArtistUnavailability.sol";
import {
    IStreamArtistMintConsent
} from "../../interfaces/stream/artist/IStreamArtistMintConsent.sol";
import {
    IStreamArtistAttribution
} from "../../interfaces/stream/artist/IStreamArtistAttribution.sol";
import {
    IStreamArtistOnboarding
} from "../../interfaces/stream/artist/IStreamArtistOnboarding.sol";
import {
    IStreamArtistContentRatification
} from "../../interfaces/stream/artist/IStreamArtistContentRatification.sol";
import {
    IStreamArtistEconomicsAuthority
} from "../../interfaces/stream/artist/IStreamArtistEconomicsAuthority.sol";
import {
    IStreamArtistTemplateEconomicsAuthority
} from "../../interfaces/stream/artist/IStreamArtistTemplateEconomicsAuthority.sol";
import {
    IStreamArtistTemplateMutationAuthority
} from "../../interfaces/stream/artist/IStreamArtistTemplateMutationAuthority.sol";
import {
    IStreamArtistPlatformWorks
} from "../../interfaces/stream/artist/IStreamArtistPlatformWorks.sol";
import {
    IStreamArtistDisplayFacts
} from "../../interfaces/stream/artist/IStreamArtistDisplayFacts.sol";
import {
    IStreamArtistAttestationWriter
} from "../../interfaces/stream/artist/IStreamArtistAttestationWriter.sol";
import {
    IStreamArtistAttributionClaims
} from "../../interfaces/stream/artist/IStreamArtistAttributionClaims.sol";
import {
    IStreamArtistDelegation
} from "../../interfaces/stream/artist/IStreamArtistDelegation.sol";
import {
    IStreamArtistBindingLifecycle
} from "../../interfaces/stream/artist/IStreamArtistBindingLifecycle.sol";
import {
    IStreamArtistBeneficiaryFacts
} from "../../interfaces/stream/artist/IStreamArtistBeneficiaryFacts.sol";
import {
    IStreamArtistCollaboratorLifecycle
} from "../../interfaces/stream/artist/IStreamArtistCollaboratorLifecycle.sol";
import {
    IStreamArtistAuthorizationRevocation
} from "../../interfaces/stream/artist/IStreamArtistAuthorizationRevocation.sol";
import {
    IStreamArtistContentAuthority
} from "../../interfaces/stream/artist/IStreamArtistContentAuthority.sol";
import {
    IStreamArtistContentHostEvidence
} from "../../interfaces/stream/artist/IStreamArtistContentHostEvidence.sol";
import {
    IStreamArtistIdentityRevision
} from "../../interfaces/stream/artist/IStreamArtistIdentityRevision.sol";
import {
    IStreamArtistIdentityRevisionReads
} from "../../interfaces/stream/artist/IStreamArtistIdentityRevision.sol";
import { IStreamArtistRotation } from "../../interfaces/stream/artist/IStreamArtistRotation.sol";
import {
    IStreamArtistRotationReads
} from "../../interfaces/stream/artist/IStreamArtistRotation.sol";
import {
    IStreamArtistSaleAuthority
} from "../../interfaces/stream/artist/IStreamArtistSaleAuthority.sol";
import {
    IStreamArtistAttributionState
} from "../../interfaces/stream/artist/IStreamArtistAttributionState.sol";
import {
    IStreamArtistIdentityContest
} from "../../interfaces/stream/artist/IStreamArtistIdentityContest.sol";
import {
    IStreamArtistIdentityDismissal
} from "../../interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";
import {
    IStreamArtistEstateActivation
} from "../../interfaces/stream/artist/IStreamArtistEstateActivation.sol";
import {
    IStreamArtistEstateBinding
} from "../../interfaces/stream/artist/IStreamArtistEstateOwner.sol";
import {
    IStreamArtistCommercialAuthority
} from "../../interfaces/stream/artist/IStreamArtistCommercialAuthority.sol";
import {
    IStreamArtistRecordPublication
} from "../../interfaces/stream/artist/IStreamArtistRecordPublication.sol";
import {
    IStreamArtistFinalityBinding
} from "../../interfaces/stream/artist/IStreamArtistFinalityBinding.sol";
import { IStreamArtistSanction } from "../../interfaces/stream/artist/IStreamArtistSanction.sol";
import {
    IStreamArtistSanctionConfirmation
} from "../../interfaces/stream/artist/IStreamArtistSanctionConfirmation.sol";
import {
    IStreamFinalitySanctionReads
} from "../../interfaces/stream/finality/IStreamFinalitySanctionReads.sol";
import {
    IStreamArtistSanctionArchiveFacts
} from "../../interfaces/stream/finality/IStreamArtistSanctionArchiveFacts.sol";
import {
    IStreamArtworkFinalityComponent
} from "../../interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";
import {
    IStreamArtworkScopedFinalityComponent
} from "../../interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";
import {
    IStreamArtistSuccessionRecords
} from "../../interfaces/stream/artist/IStreamArtistSuccessionRecords.sol";
import {
    IStreamArtistSuccessionReads
} from "../../interfaces/stream/artist/IStreamArtistSuccessionRecords.sol";
import {
    IStreamArtistIdentityRecovery
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamArtistIdentityRecoveryV2
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecoveryV2.sol";
import {
    IStreamArtistWindows
} from "../../interfaces/stream/artist/IStreamArtistRotationOwner.sol";
import { IStreamArtistDormancy } from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    IStreamArtistDormancyEvidence
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    IStreamArtistStewardSanctionGrant as SG
} from "../../interfaces/stream/artist/IStreamArtistStewardSanctionGrant.sol";
import {
    IStreamArtistStewardCapabilities
} from "../../interfaces/stream/artist/IStreamArtistStewardCapabilities.sol";
import {
    IStreamArtistReconstruction
} from "../../interfaces/stream/artist/IStreamArtistReconstruction.sol";

/// @notice Fixed original ERC-165 inventory; the facade retains base module handling.
library StreamArtistRegistryInterfaces {
    function supportsArtistInterface(bytes4 id) public pure returns (bool) {
        return id == type(IStreamArtistAttributionRepudiation).interfaceId
            || id == type(IStreamArtistDisputeWithdrawal).interfaceId
            || id == type(IStreamArtistAttributionDisputes).interfaceId
            || id == type(IStreamArtistEntropyFindingHydration).interfaceId
            || id == type(IStreamArtistPublicationAuthorityHydration).interfaceId
            || id == type(IStreamArtistReadinessAuthorityHydration).interfaceId
            || id == type(IStreamArtistEconomicsAuthorityHydration).interfaceId
            || id == type(IStreamArtistPayoutAuthorityHydration).interfaceId
            || id == type(IStreamArtistMultipleAuthorityHydration).interfaceId
            || id == type(IStreamArtistMultipleRecordsHydration).interfaceId
            || id == type(IStreamArtistRecoveredHydration).interfaceId
            || id == type(IStreamArtistRecoveredConsentHydration).interfaceId
            || id == type(IStreamArtistDelegationAuthorityHydration).interfaceId
            || id == type(IStreamArtistAuthorityHydration).interfaceId
            || id == type(IStreamArtistHistory).interfaceId
            || id == type(IStreamArtistRecoveryApproval).interfaceId
            || id == type(IStreamArtistEntropyUnavailability).interfaceId
            || id == type(IStreamArtistUnavailability).interfaceId
            || id == type(IStreamArtistMintConsent).interfaceId
            || id == type(IStreamArtistAttribution).interfaceId
            || id == type(IStreamArtistOnboarding).interfaceId
            || id == type(IStreamArtistContentRatification).interfaceId
            || id == type(IStreamArtistEconomicsAuthority).interfaceId
            || id == type(IStreamArtistTemplateEconomicsAuthority).interfaceId
            || id == type(IStreamArtistTemplateMutationAuthority).interfaceId
            || id == type(IStreamArtistPlatformWorks).interfaceId
            || id == type(IStreamArtistDisplayFacts).interfaceId
            || id == type(IStreamArtistAttestationWriter).interfaceId
            || id == type(IStreamArtistAttributionClaims).interfaceId
            || id == type(IStreamArtistDelegation).interfaceId
            || id == type(IStreamArtistDelegatedConsent).interfaceId
            || id == type(IStreamArtistBindingLifecycle).interfaceId
            || id == type(IStreamArtistBeneficiaryFacts).interfaceId
            || id == type(IStreamArtistCollaboratorLifecycle).interfaceId
            || id == type(IStreamArtistAuthorizationRevocation).interfaceId
            || id == type(IStreamArtistContentAuthority).interfaceId
            || id == type(IStreamArtistContentHostEvidence).interfaceId
            || id == type(IStreamArtistIdentityRevision).interfaceId
            || id == type(IStreamArtistIdentityRevisionReads).interfaceId
            || id == type(IStreamArtistRotation).interfaceId
            || id == type(IStreamArtistRotationReads).interfaceId
            || id == type(IStreamArtistSaleAuthority).interfaceId
            || id == type(IStreamArtistAttributionState).interfaceId
            || id == type(IStreamArtistIdentityContest).interfaceId
            || id == type(IStreamArtistIdentityDismissal).interfaceId
            || id == type(IStreamArtistEstateActivation).interfaceId
            || id == type(IStreamArtistEstateBinding).interfaceId
            || id == type(IStreamArtistCommercialAuthority).interfaceId
            || id == type(IStreamArtistRecordPublication).interfaceId
            || id == type(IStreamArtistFinalityBinding).interfaceId
            || id == type(IStreamArtistSanction).interfaceId
            || id == type(IStreamArtistSanctionConfirmation).interfaceId
            || id == type(IStreamFinalitySanctionReads).interfaceId
            || id == type(IStreamArtistSanctionArchiveFacts).interfaceId
            || id == type(IStreamArtworkFinalityComponent).interfaceId
            || id == type(IStreamArtworkScopedFinalityComponent).interfaceId
            || id == type(IStreamArtistSuccessionRecords).interfaceId
            || id == type(IStreamArtistSuccessionReads).interfaceId
            || id == type(IStreamArtistIdentityRecovery).interfaceId
            || id == type(IStreamArtistIdentityRecoveryV2).interfaceId
            || id == type(IStreamArtistWindows).interfaceId
            || type(IStreamArtistDormancy).interfaceId == id
            || type(IStreamArtistDormancyEvidence).interfaceId == id || type(SG).interfaceId == id
            || id == type(IStreamArtistStewardCapabilities).interfaceId
            || id == type(IStreamArtistReconstruction).interfaceId;
    }
}
