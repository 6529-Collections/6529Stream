// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredBindingGenerations as G
} from "./StreamArtistRecoveredBindingGenerations.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredDisputeBindingFacts as BindingFacts
} from "./StreamArtistRecoveredDisputeBindingFacts.sol";
import {
    StreamArtistRecoveredDisputeIdentityFacts as DisputeFacts
} from "./StreamArtistRecoveredDisputeIdentityFacts.sol";
import {
    StreamArtistRecoveredDisputeConsentHistory as Consent
} from "./StreamArtistRecoveredDisputeConsentHistory.sol";
import {
    StreamArtistRecoveredDelegationConsentFactRows as Base
} from "./StreamArtistRecoveredDelegationConsentFactRows.sol";

/// @notice One complete Identity use inventory across all original dispute and base-consent rows.
library StreamArtistRecoveredDisputeCompositionFacts {
    struct Context {
        G.Bundle bindings;
        D.Bundle attribution;
        Consent.Bundle consent;
        AH.Query query;
        RH.Provenance provenance;
    }

    function validate(IH.Bundle calldata identity, Context calldata x) public pure {
        G.Bundle calldata bindings = x.bindings;
        D.Bundle calldata attribution = x.attribution;
        Consent.Bundle calldata consent = x.consent;
        AH.Query calldata q = x.query;
        RH.Provenance calldata p = x.provenance;
        BindingFacts.validateRows(
            BindingFacts.IdentityRows(identity.artistId, identity.documents, identity.signatures),
            bindings,
            BindingFacts.Scope(q.artistId, q.collectionId, q.bindingHash),
            p
        );
        uint256[] memory uses = DisputeFacts.validate(
            DisputeFacts.IdentityRows(
                identity.artistId,
                identity.signatures,
                identity.nonces,
                identity.delegations,
                identity.contests,
                identity.causes,
                identity.guardians
            ),
            attribution,
            q,
            p
        );
        if (
            bindings.rows.length != consent.bindings.length
                || bindings.rows.length != attribution.generations.length
        ) _invalid();
        uint8 historicalMode = 1;
        for (uint256 i; i < bindings.rows.length; ++i) {
            if (
                keccak256(abi.encode(bindings.rows[i].item))
                        != keccak256(abi.encode(consent.bindings[i]))
                    || bindings.rows[i].item.bindingHash != attribution.generations[i].bindingHash
                    || bindings.rows[i].item.accepted != attribution.generations[i].accepted
            ) _invalid();
            if (bindings.rows[i].item.accepted && bindings.rows[i].item.consentMode == 2) {
                historicalMode = 2;
            }
        }
        // Original policy records have no generation/signer/time preimage. Their immutable
        // fixed-owner/grant association and complete journal are retained; never assign them
        // the current generation or reauthorize against the current grant. Sales have an exact
        // saved generation and their mode was individually checked by the consent codec.
        Base.validateRows(
            Base.IdentityRows(identity.artistId, identity.delegations),
            Base.ConsentRows(
                consent.original.artistId,
                consent.original.collectionId,
                consent.original.bindingHash,
                consent.original.policies,
                consent.original.economics,
                consent.original.sales
            ),
            Base.Scope(q.artistId, q.collectionId, q.bindingHash),
            p,
            historicalMode,
            uses
        );
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
