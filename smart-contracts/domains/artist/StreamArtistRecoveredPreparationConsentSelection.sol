// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredPreparationOwners as Owners
} from "./StreamArtistRecoveredPreparationOwners.sol";
import {
    StreamArtistRecoveredPreparationGenerations as GenerationStage
} from "./StreamArtistRecoveredPreparationGenerations.sol";
import {
    StreamArtistRecoveredPreparationConsents as ConsentStage
} from "./StreamArtistRecoveredPreparationConsents.sol";
import {
    StreamArtistRecoveredPreparationJoins as Joins
} from "./StreamArtistRecoveredPreparationJoins.sol";
import {
    StreamArtistRecoveredRatificationStage as RatificationStage
} from "./StreamArtistRecoveredRatificationStage.sol";

/// @notice Fixed complete consent joins after original source, generation and Identity collection.
/// @dev Branches retain their original order; this worker never imports or mutates any owner.
library StreamArtistRecoveredPreparationConsentSelection {
    function complete(
        Owners.Context memory context,
        T.RoyaltyFreeze[] memory royaltyFreezes,
        uint8 consentMode,
        bool hasIdentityDelegations,
        bytes memory attestationRecords
    ) public view returns (bytes memory consent, uint256 features) {
        if ((context.features & RH.HISTORY_RECORDS) != 0) {
            // The new whole-history fact frame reconciled every original record/grant use.
            if (!context.hasAttestations || (context.features & RH.ATTESTATIONS) == 0) {
                revert T.UnsupportedProfile();
            }
            if (context.hasContent) context.features |= RH.CONTENT_CONSENTS;
            if (RatificationStage.selected(context.provenance.journals[6])) {
                context.features |= RH.RATIFICATIONS;
            }
            return (context.consent, context.features);
        }
        if ((context.features & RH.HISTORY_CONTENT) != 0) {
            // The complete history stage already reconciled every row/signature/grant use.
            if (context.hasAttestations) revert T.UnsupportedProfile();
            if (context.hasContent) context.features |= RH.CONTENT_CONSENTS;
            if (RatificationStage.selected(context.provenance.journals[6])) {
                context.features |= RH.RATIFICATIONS;
            }
            return (context.consent, context.features);
        }
        if ((context.features & RH.DISPUTE_HISTORY) != 0) {
            // Complete base/dispute grant reconciliation already ran in the fixed history stage.
            if (context.hasContent || royaltyFreezes.length != 0 || context.hasAttestations) {
                revert T.UnsupportedProfile();
            }
            return (context.consent, context.features);
        }
        if (RatificationStage.selected(context.provenance.journals[6])) {
            context.features |= RH.RATIFICATIONS;
            if (context.hasContent) context.features |= RH.CONTENT_CONSENTS;
            context.consent = RatificationStage.collect(
                context.source.owners[6],
                context.query,
                RH.ownerProvenance(context.provenance, 6),
                context.economics,
                royaltyFreezes,
                context.generations,
                consentMode
            );
            RatificationStage.facts(
                context.identity,
                context.consent,
                context.query,
                context.provenance,
                consentMode,
                attestationRecords
            );
        } else if (
            context.hasContent
                || (context.hasGenerations
                    && (context.hasDelegation || context.economics.length != 0))
        ) {
            if (context.hasContent) context.features |= RH.CONTENT_CONSENTS;
            if (context.hasGenerations) {
                context.consent = GenerationStage.contentWithAuthority(
                    context.source.owners[6],
                    context.query,
                    RH.ownerProvenance(context.provenance, 6),
                    context.economics,
                    royaltyFreezes,
                    context.generations,
                    hasIdentityDelegations
                );
                GenerationStage.contentFactsWithAuthority(
                    context.identity,
                    context.consent,
                    context.query,
                    context.provenance,
                    attestationRecords,
                    context.generations
                );
            } else {
                context.consent = ConsentStage.content(
                    context.source.owners[6],
                    context.query,
                    RH.ownerProvenance(context.provenance, 6),
                    context.economics,
                    royaltyFreezes
                );
                Joins.content(
                    context.identity,
                    context.consent,
                    context.query,
                    context.provenance,
                    consentMode,
                    attestationRecords
                );
            }
        } else if (royaltyFreezes.length != 0) {
            revert T.UnsupportedProfile();
        } else if (context.hasDelegation) {
            context.consent = ConsentStage.delegated(
                context.source.owners[6],
                context.query,
                RH.ownerProvenance(context.provenance, 6),
                context.economics
            );
            Joins.delegated(
                context.identity,
                context.consent,
                context.query,
                context.provenance,
                consentMode,
                attestationRecords,
                context.hasAttestations
            );
        } else if (context.hasAttestations) {
            if (context.hasGenerations) {
                GenerationStage.attestations(
                    context.identity, context.attestations, context.query, context.provenance
                );
            } else {
                Joins.attestations(
                    context.identity, attestationRecords, context.query, context.provenance
                );
            }
        }
        return (context.consent, context.features);
    }
}
