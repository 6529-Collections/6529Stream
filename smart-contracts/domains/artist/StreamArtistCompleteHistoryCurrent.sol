// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistCompleteHistoryTypes as CT } from "./StreamArtistCompleteHistoryTypes.sol";
import { StreamArtistCompleteHistoryCodec as Codec } from "./StreamArtistCompleteHistoryCodec.sol";
import {
    StreamArtistCompleteHistoryPreparationPrincipals as Principals
} from "./StreamArtistCompleteHistoryPreparationPrincipals.sol";
import {
    StreamArtistCompleteHistoryComposition as Composition
} from "./StreamArtistCompleteHistoryComposition.sol";
import {
    StreamArtistCompleteHistoryWitnesses as Witnesses
} from "./StreamArtistCompleteHistoryWitnesses.sol";
import {
    StreamArtistRecoveredHydrationCommit as Commit
} from "./StreamArtistRecoveredHydrationCommit.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredHydrationGuards as Guards
} from "./StreamArtistRecoveredHydrationGuards.sol";
import {
    StreamArtistRecoveredExternalGuards as External
} from "./StreamArtistRecoveredExternalGuards.sol";
import {
    StreamArtistRecoveredAggregateRatificationRows as Supplements
} from "./StreamArtistRecoveredAggregateRatificationRows.sol";
import {
    StreamArtistAggregateConsentSupplementTypes as Supplement
} from "./StreamArtistAggregateConsentSupplementTypes.sol";
import {
    StreamArtistRecoveredMultipleDisputeTypes as MD
} from "./StreamArtistRecoveredMultipleDisputeTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistReadinessHydrationTypes as ReadinessH
} from "../../interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";

/// @notice Post-write re-observation of the complete original source and every admitted family.
/// @dev The enclosing commit retains its source provenance, suite, timing and publication checks.
/// Prepared row terms are missing-preimage witnesses only; the fixed source collectors authenticate
/// them again. This worker does not select a profile or authorize the destination writes itself.
library StreamArtistCompleteHistoryCurrent {
    struct Work {
        M.State[7] owners;
        bytes auxiliary;
        RH.NonceInventory[] nonces;
        uint256 features;
    }

    function recheck(Commit.Prepared memory prepared) public view returns (bool) {
        if (!Codec.selected(prepared.data[0].typedState, 0)) return false;
        Work memory w = _owners(prepared);
        Principals.Result memory principal = Principals.collect(prepared.admission);
        if (
            keccak256(abi.encode(principal.principals.identities))
                    != keccak256(abi.encode(w.owners[2].rows))
                || keccak256(abi.encode(principal.principals.payouts))
                    != keccak256(abi.encode(w.owners[5].rows))
                || keccak256(abi.encode(principal.timing)) != keccak256(abi.encode(prepared.timing))
                || keccak256(abi.encode(principal.externalGuards))
                    != keccak256(abi.encode(prepared.externalGuards))
        ) _invalid();
        RH.NonceInventory[] memory nonces = Guards.collectNonces(
            prepared.admission.source.owners[2],
            prepared.admission.provenance
                .eras[prepared.admission.provenance.eras.length - 1].checkpoints[2]
        );
        if (keccak256(abi.encode(nonces)) != keccak256(abi.encode(w.nonces))) _invalid();
        Composition.Result memory fresh = Composition.collect(
            Composition.Context(
                prepared.admission,
                principal.principals,
                _witnesses(w.owners[6].rows, w.owners[4].rows),
                principal.features
            )
        );
        if (
            fresh.features != w.features
                || keccak256(abi.encode(fresh.inventory)) != keccak256(w.auxiliary)
                || keccak256(abi.encode(fresh.bindings)) != keccak256(abi.encode(w.owners[0].rows))
                || keccak256(abi.encode(fresh.accepted)) != keccak256(abi.encode(w.owners[3].rows))
                || keccak256(abi.encode(fresh.attribution))
                    != keccak256(abi.encode(w.owners[4].rows))
                || keccak256(abi.encode(fresh.consents)) != keccak256(abi.encode(w.owners[6].rows))
        ) _invalid();
        // Principals.collect proves the exact tagged empty snapshot for an all-unbound graph.
        // External.requireCurrent requires a real principal and must not receive that empty form.
        if (prepared.admission.artists.length != 0) {
            External.requireCurrent(prepared.externalGuards);
        }
        return true;
    }

    function _owners(Commit.Prepared memory prepared) private pure returns (Work memory w) {
        bytes32 scope =
            keccak256(abi.encode(prepared.admission.artists, prepared.admission.collections));
        for (uint8 owner; owner < 7; ++owner) {
            (RH.ExportHeader memory header, Payload.Payload memory payload) =
                Payload.decode(prepared.data[owner].typedState, owner);
            if (
                (header.requiredFeatures & CT.FEATURE) == 0
                    || (header.requiredFeatures & ~CT.ALLOWED) != 0
                    || (owner != 0 && header.requiredFeatures != w.features)
                    || (owner != 2 && payload.nonces.length != 0)
                    || keccak256(abi.encode(payload.provenance))
                        != keccak256(
                            abi.encode(RH.ownerProvenance(prepared.admission.provenance, owner))
                        )
            ) _invalid();
            bytes memory auxiliary;
            (w.owners[owner], auxiliary) =
                Codec.decodeAuxiliary(owner, payload.semanticState, payload.provenance);
            if (
                keccak256(abi.encode(w.owners[owner].artists, w.owners[owner].collections)) != scope
                    || keccak256(abi.encode(Codec.anchorQuery(w.owners[owner])))
                        != keccak256(abi.encode(prepared.query))
            ) _invalid();
            if (owner == 0) {
                CT.Inventory memory inventory = abi.decode(auxiliary, (CT.Inventory));
                if (
                    keccak256(abi.encode(inventory.provenance))
                        != keccak256(abi.encode(prepared.admission.provenance))
                ) _invalid();
                w.auxiliary = auxiliary;
                w.features = header.requiredFeatures;
            } else if (keccak256(auxiliary) != keccak256(w.auxiliary)) {
                _invalid();
            }
            if (owner == 2) w.nonces = payload.nonces;
        }
    }

    function _witnesses(bytes[] memory consent, bytes[] memory attribution)
        private
        pure
        returns (Witnesses.Plan memory plan)
    {
        if (consent.length != attribution.length) _invalid();
        uint256 n = consent.length;
        plan.economics = new T.EconomicsConsent[][](n);
        plan.freezes = new T.RoyaltyFreeze[][](n);
        plan.attestations = new ReadinessH.AttestationInput[][](n);
        for (uint256 k; k < n; ++k) {
            Supplement.Bundle memory row = Supplements.decodeSupplement(consent[k]);
            plan.economics[k] =
                new T.EconomicsConsent[](row.original.rows.original.economics.length);
            for (uint256 i; i < plan.economics[k].length; ++i) {
                plan.economics[k][i] = row.original.rows.original.economics[i].item.terms;
            }
            plan.freezes[k] = new T.RoyaltyFreeze[](row.original.rows.royalties.length);
            for (uint256 i; i < plan.freezes[k].length; ++i) {
                plan.freezes[k][i] = row.original.rows.royalties[i].terms;
            }
            MD.Attribution memory records = abi.decode(attribution[k], (MD.Attribution));
            if (keccak256(attribution[k]) != keccak256(abi.encode(records))) _invalid();
            plan.attestations[k] = new ReadinessH.AttestationInput[](records.records.records.length);
            for (uint256 i; i < plan.attestations[k].length; ++i) {
                plan.attestations[k][i] = records.records.records[i].attestation.input;
            }
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
