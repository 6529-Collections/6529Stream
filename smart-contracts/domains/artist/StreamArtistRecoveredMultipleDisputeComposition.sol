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
    StreamArtistRecoveredMultipleDisputeFamilyComposition as Families
} from "./StreamArtistRecoveredMultipleDisputeFamilyComposition.sol";
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
    StreamArtistRecoveredMultipleDisputeBindingSource as Bindings
} from "./StreamArtistRecoveredMultipleDisputeBindingSource.sol";
import {
    StreamArtistRecoveredMultipleDisputeBindingProof as BindingProof
} from "./StreamArtistRecoveredMultipleDisputeBindingProof.sol";
import {
    StreamArtistRecoveredMultipleDisputeClocks as ClockProof
} from "./StreamArtistRecoveredMultipleDisputeClocks.sol";
import {
    StreamArtistRecoveredMultipleGenerationAcceptance as Acceptance
} from "./StreamArtistRecoveredMultipleGenerationAcceptance.sol";
import {
    StreamArtistRecoveredMultipleDisputeSource as Disputes
} from "./StreamArtistRecoveredMultipleDisputeSource.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationClocks as Clocks
} from "./StreamArtistRecoveredMultipleGenerationClocks.sol";
import {
    StreamArtistRecoveredMultipleDisputeAttributionProof as Proof
} from "./StreamArtistRecoveredMultipleDisputeAttributionProof.sol";

/// @notice Complete authenticated generation graph followed by original rows and global conservation.

library StreamArtistRecoveredMultipleDisputeComposition {
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
            ClockProof.collect(x.provenance, x.scope, binding.bindings, binding.generations);
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
        D.Bundle[] memory history = Disputes.collect(
            x.source.owners[4], x.scope, x.provenance, inventory, sanctions.sanctions.length != 0
        );
        Proof.validateHistory(
            history,
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
