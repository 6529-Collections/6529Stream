// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredSanctionIdentityFacts as Sanctions
} from "./StreamArtistRecoveredSanctionIdentityFacts.sol";
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

import {
    StreamArtistRecoveredHistoryContentTypes as HC
} from "./StreamArtistRecoveredHistoryContentTypes.sol";
import {
    StreamArtistRecoveredHistoryContentFactRows as ContentFacts
} from "./StreamArtistRecoveredHistoryContentFactRows.sol";

import {
    StreamArtistRecoveredHistoryContentCodec as Codec
} from "./StreamArtistRecoveredHistoryContentCodec.sol";

/// @notice Complete original dispute, base, royalty and signature inventory in one authenticated source.
library StreamArtistRecoveredHistoryContentFacts {
    struct Context {
        G.Bundle bindings;
        D.Bundle attribution;
        bytes complete;
        AH.Query query;
        RH.Provenance provenance;
    }

    function validate(IH.Bundle calldata identity, Context calldata x) public view {
        HC.Bundle memory complete =
            Codec.decode(x.query, RH.ownerProvenance(x.provenance, 6), x.complete);
        if (complete.sanctions.sanctions.length != 0) {
            Sanctions.validate(
                identity.artistId,
                identity.signatures,
                identity.nonces,
                complete.sanctions,
                x.provenance
            );
        }
        G.Bundle calldata bindings = x.bindings;
        D.Bundle calldata attribution = x.attribution;
        Consent.Bundle memory consent = complete.base;
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
        uint256[] memory contentUses = ContentFacts.validate(
            ContentFacts.IdentityRows(identity.artistId, identity.signatures, identity.delegations),
            complete,
            p
        );
        if (contentUses.length != uses.length) _invalid();
        for (uint256 i; i < uses.length; ++i) {
            uses[i] += contentUses[i];
        }
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
