// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import { StreamArtistCompleteHistoryTypes as CT } from "./StreamArtistCompleteHistoryTypes.sol";
import { StreamArtistCompleteHistoryScope as Scope } from "./StreamArtistCompleteHistoryScope.sol";
import {
    StreamArtistCompleteHistoryBindingTypes as Bindings
} from "./StreamArtistCompleteHistoryBindingTypes.sol";
import {
    StreamArtistRecoveredAttestationHydration as Records
} from "./StreamArtistRecoveredAttestationHydration.sol";
import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";
import {
    StreamArtistCompleteHistoryConsentUses as Consents
} from "./StreamArtistCompleteHistoryConsentUses.sol";
import {
    StreamArtistCompleteHistoryAttestationUses as Attestations
} from "./StreamArtistCompleteHistoryAttestationUses.sol";
import {
    StreamArtistCompleteHistoryDisputeIdentityUses as Disputes
} from "./StreamArtistCompleteHistoryDisputeIdentityUses.sol";

/// @notice One equality per original retained grant across all collections and generations.
/// @dev The enclosing proof authenticates canonical Identity and complete family rows first.
/// All workers receive the same whole provenance. Original op2/3/6/7 authorizations consume
/// principal/account nonces, not grants; their signature and nonce proof remains separate.
/// An all-unbound graph still supplies and validates an explicit empty row for each family
/// and collection. An empty Identity array never bypasses those family workers.
library StreamArtistCompleteHistoryConservation {
    struct Context {
        bytes[] identities;
        M.State scope;
        G.Consents[] consents;
        bytes[] attestations;
        CT.Inventory inventory;
        D.Bundle[] histories;
    }

    function validate(Context calldata x) public pure {
        if (
            x.identities.length != x.scope.artists.length || x.scope.collections.length == 0
                || x.scope.collections.length > 128
                || x.consents.length != x.scope.collections.length
                || x.attestations.length != x.scope.collections.length
                || x.histories.length != x.scope.collections.length
        ) _invalid();
        if (x.identities.length == 0) _empty(x);
        uint256[][] memory consent = Consents.validate(
            Consents.Context(x.identities, x.scope, x.consents, x.inventory.provenance)
        );
        uint256[][] memory attested = Attestations.validate(
            Attestations.Context(x.identities, x.scope, x.attestations, x.inventory)
        );
        uint256[][] memory disputed =
            Disputes.validate(Disputes.Context(x.identities, x.scope, x.inventory, x.histories));
        if (
            consent.length != x.identities.length || attested.length != x.identities.length
                || disputed.length != x.identities.length
        ) _invalid();
        for (uint256 a; a < x.identities.length; ++a) {
            // Disputes validates every complete canonical frame, principal and source header.
            IH.Bundle calldata identity = Frame.bundle(x.identities[a]);
            if (
                consent[a].length != identity.delegations.length
                    || attested[a].length != identity.delegations.length
                    || disputed[a].length != identity.delegations.length
            ) _invalid();
            for (uint256 g; g < identity.delegations.length; ++g) {
                if (
                    consent[a][g] + attested[a][g] + disputed[a][g]
                        != identity.delegations[g].record.uses
                ) _invalid();
            }
        }
    }

    function _empty(Context calldata x) private pure {
        Bindings.validate(
            x.scope,
            x.inventory.bindings,
            RH.ownerProvenanceHash(RH.ownerProvenance(x.inventory.provenance, 0), 0)
        );
        bytes32 p4 = RH.ownerProvenanceHash(RH.ownerProvenance(x.inventory.provenance, 4), 4);
        bytes32 p6 = RH.ownerProvenanceHash(RH.ownerProvenance(x.inventory.provenance, 6), 6);
        for (uint256 k; k < x.scope.collections.length; ++k) {
            uint256 collection = x.scope.collections[k].collectionId;
            if (
                collection == 0 || x.scope.collections[k].artistId != 0
                    || x.scope.collections[k].bindingHash != 0
                    || x.scope.collections[k].policies.length != 0
                    || x.inventory.bindings.bindings[k].bindings.rows.length != 0
            ) _invalid();
            G.Consents memory consent;
            consent.rows.original.collectionId = collection;
            consent.rows.original.provenance = p6;
            Records.Bundle memory attested;
            attested.collectionId = collection;
            attested.provenance = p4;
            D.Bundle memory disputed;
            disputed.collectionId = collection;
            disputed.provenance = p4;
            if (
                keccak256(abi.encode(x.consents[k])) != keccak256(abi.encode(consent))
                    || keccak256(x.attestations[k]) != keccak256(abi.encode(attested))
                    || keccak256(abi.encode(x.histories[k])) != keccak256(abi.encode(disputed))
            ) _invalid();
        }
        for (uint8 owner; owner < 7; ++owner) {
            for (uint256 i; i < x.inventory.provenance.journals[owner].length; ++i) {
                if (!Scope.platformOnly(owner, x.inventory.provenance.journals[owner][i].receipt)) {
                    _invalid();
                }
                Scope.collection(
                    x.scope, x.inventory.provenance.journals[owner][i].receipt.collectionId
                );
            }
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
