// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
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
        A.AttributionBundle[] memory history = Revocations.collect(
            x.source.owners[4], x.scope, RH.ownerProvenance(x.provenance, 4), inventory, clocks
        );
        G.Consents[] memory consents = _consents(x, inventory);
        bytes[] memory attestations = Attestations.collect(
            x.source.owners[4],
            Queries.project(x.scope, RH.ownerProvenance(x.provenance, 4)),
            RH.ownerProvenance(x.provenance, 4),
            x.attestations,
            inventory,
            clocks
        );
        IdentityFacts.validate(
            IdentityFacts.Context(x.identities, x.scope, inventory, accepted, x.provenance)
        );
        Conservation.validate(
            Conservation.Context(
                x.identities, x.scope, consents, attestations, inventory, x.provenance
            )
        );
        uint256 n = x.scope.collections.length;
        result.bindings = new bytes[](n);
        result.accepted = new bytes[](n);
        result.consents = new bytes[](n);
        result.attribution = new bytes[](n);
        result.features = x.features | G.FEATURE | RH.BINDING_GENERATIONS;
        for (uint256 k; k < n; ++k) {
            result.bindings[k] = abi.encode(inventory.bindings[k]);
            result.accepted[k] = abi.encode(accepted[k]);
            result.consents[k] = abi.encode(consents[k]);
            Records.Bundle memory records = abi.decode(attestations[k], (Records.Bundle));
            result.attribution[k] = abi.encode(G.Attribution(history[k], records));
            if (records.records.length != 0) {
                result.features |= RH.ATTESTATIONS | RH.HISTORY_RECORDS;
            }
            if (history[k].revocations.length != 0) {
                result.features |= RH.ACCEPTED_GENERATIONS | RH.DISPUTE_HISTORY;
            }
            if (consents[k].rows.original.economics.length != 0) {
                result.features |= RH.DIRECT_ECONOMICS;
            }
            if (consents[k].rows.original.sales.length != 0) {
                result.features |= RH.DELEGATED_CONSENT;
            }
            if (
                consents[k].rows.consents.length + consents[k].rows.royalties.length
                        + consents[k].rows.freezes.length != 0
            ) result.features |= RH.CONTENT_CONSENTS | RH.HISTORY_CONTENT;
            for (uint256 g; g < inventory.bindings[k].corrections.length; ++g) {
                if (inventory.bindings[k].corrections[g].recordHash != 0) {
                    result.features |= RH.BINDING_CORRECTIONS;
                }
                if (consents[k].bindings[g].consentMode == 2) {
                    result.features |= RH.DELEGATED_CONSENT;
                }
            }
        }
        result.inventory = abi.encode(inventory);
        result.generations = abi.encode(inventory.generations);
    }

    function _consents(Context memory x, G.Inventory memory inventory)
        private
        view
        returns (G.Consents[] memory rows)
    {
        uint256 n = x.scope.collections.length;
        rows = new G.Consents[](n);
        if (x.economics.length != n || x.freezes.length != n) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        for (uint256 k; k < n; ++k) {
            uint256 count = inventory.bindings[k].bindings.rows.length;
            rows[k].bindings = new T.Binding[](count);
            for (uint256 g; g < count; ++g) {
                rows[k].bindings[g] = inventory.bindings[k].bindings.rows[g].item;
            }
            rows[k].rows = Reads.collectRows(
                x.source.owners[6],
                x.scope.collections[k],
                RH.ownerProvenance(x.provenance, 6),
                x.economics[k],
                x.freezes[k],
                rows[k].bindings
            );
        }
        Validation.validate(rows, x.scope.collections, RH.ownerProvenance(x.provenance, 6));
        for (uint256 k; k < n; ++k) {
            Reads.requireHeads(x.source.owners[6], rows[k].rows);
        }
    }
}
