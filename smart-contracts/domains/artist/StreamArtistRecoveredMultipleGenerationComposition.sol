// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredAggregateSanctionRows as SanctionRows
} from "./StreamArtistRecoveredAggregateSanctionRows.sol";
import {
    StreamArtistRecoveredSanctionStage as SanctionSelection
} from "./StreamArtistRecoveredSanctionStage.sol";
import {
    StreamArtistRecoveredMultipleGenerationFamilyComposition as Families
} from "./StreamArtistRecoveredMultipleGenerationFamilyComposition.sol";
import {
    StreamArtistRecoveredMultipleGenerationConsentCollection as ConsentCollection
} from "./StreamArtistRecoveredMultipleGenerationConsentCollection.sol";
import {
    StreamArtistRecoveredMultipleGenerationEncoding as Encoding
} from "./StreamArtistRecoveredMultipleGenerationEncoding.sol";
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
    StreamArtistRecoveredMultipleGenerationIdentityFacts as IdentityFacts
} from "./StreamArtistRecoveredMultipleGenerationIdentityFacts.sol";
import {
    StreamArtistRecoveredMultipleGenerationConservation as Conservation
} from "./StreamArtistRecoveredMultipleGenerationConservation.sol";

/// @notice Complete authenticated generation graph followed by original rows and global conservation.
library StreamArtistRecoveredMultipleGenerationComposition {
    struct Context {
        T.SuiteConfiguration source;
        RH.Provenance provenance;
        M.State scope;
        bytes[] identities;
        T.EconomicsConsent[][] economics;
        T.RoyaltyFreeze[][] freezes;
        uint256 features;
        ReadinessH.AttestationInput[][] attestations;
    }

    struct Result {
        bytes[] bindings;
        bytes[] accepted;
        bytes[] consents;
        bytes[] attribution;
        bytes inventory;
        bytes generations;
        uint256 features;
    }

    function collect(Context memory x) public view returns (Result memory result) {
        Bindings.Collected memory binding =
            Bindings.collect(x.source.owners[0], x.scope, RH.ownerProvenance(x.provenance, 0));
        (G.Inventory memory inventory, Clocks.Result memory clocks) =
            Clocks.collect(x.provenance, x.scope, binding.bindings, binding.generations);
        BindingProof.validate(x.scope, RH.ownerProvenance(x.provenance, 0), inventory);
        A.AcceptanceBundle[] memory accepted = Acceptance.collect(
            x.source.owners[3], x.scope, RH.ownerProvenance(x.provenance, 3), inventory
        );
        H.Inventory memory sanctions;
        if (SanctionSelection.selected(x.provenance)) {
            sanctions = SanctionRows.collect(
                x.source.owners[6], x.scope.collections, x.provenance, inventory.bindings
            );
        }
        A.AttributionBundle[] memory history = Revocations.collect(
            x.source.owners[4],
            x.scope,
            RH.ownerProvenance(x.provenance, 4),
            inventory,
            clocks,
            sanctions.confirmations
        );
        return
            Families.collect(Families.Context(x, inventory, clocks, accepted, history), sanctions);
    }
}
