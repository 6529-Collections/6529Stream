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

import {
    StreamArtistRecoveredHistoryRecordFactRows as RecordFacts
} from "./StreamArtistRecoveredHistoryRecordFactRows.sol";
import {
    StreamArtistPublicationHydrationTypes as PubH
} from "../../interfaces/stream/artist/IStreamArtistPublicationAuthorityHydration.sol";
import {
    StreamArtistRecoveredSanctionConsentHistory as SanctionCodec
} from "./StreamArtistRecoveredSanctionConsentHistory.sol";
/// @notice Complete original dispute, base, royalty and signature inventory in one authenticated source.
import {
    StreamArtistRecoveredHistoryRecordConsentCodec as ConsentCodec
} from "./StreamArtistRecoveredHistoryRecordConsentCodec.sol";
import {
    StreamArtistRecoveredHistoryRecordAuthorityFacts as AuthorityFacts
} from "./StreamArtistRecoveredHistoryRecordAuthorityFacts.sol";

library StreamArtistRecoveredHistoryRecordFacts {
    struct Context {
        G.Bundle bindings;
        D.Bundle attribution;
        bytes complete;
        bytes attestationRows;
        AH.Query query;
        RH.Provenance provenance;
    }

    function validate(IH.Bundle calldata identity, Context calldata x) public view {
        (HC.Bundle memory complete, bool content) =
            ConsentCodec.decode(x.complete, x.query, RH.ownerProvenance(x.provenance, 6));
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
        address authority = address(AuthorityFacts);
        if (authority.code.length == 0) assembly ("memory-safe") { revert(0, 0) }
        (bool ok, bytes memory result) =
            authority.staticcall(bytes.concat(AuthorityFacts.validate.selector, msg.data[4:]));
        if (!ok) assembly ("memory-safe") { revert(add(result, 0x20), mload(result)) }
        uint256[] memory uses = abi.decode(result, (uint256[]));
        if (keccak256(result) != keccak256(abi.encode(uses))) _invalid();
        if (content) {
            uint256[] memory contentUses = ContentFacts.validate(
                ContentFacts.IdentityRows(
                    identity.artistId, identity.signatures, identity.delegations
                ),
                complete,
                p
            );
            _add(uses, contentUses);
        }
        bytes32[] memory recordBindings = new bytes32[](bindings.rows.length);
        for (uint256 i; i < recordBindings.length; ++i) {
            if (bindings.rows[i].item.accepted) {
                recordBindings[i] = bindings.rows[i].item.bindingHash;
            }
        }
        _add(
            uses,
            RecordFacts.validateRowsEncoded(
                RecordFacts.IdentityRows(
                    identity.artistId, identity.signatures, identity.delegations
                ),
                x.attestationRows,
                RecordFacts.Scope(q.artistId, q.collectionId, q.bindingHash),
                p,
                recordBindings
            )
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

    function _add(uint256[] memory total, uint256[] memory more) private pure {
        if (total.length != more.length) _invalid();
        for (uint256 i; i < total.length; ++i) {
            total[i] += more[i];
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
