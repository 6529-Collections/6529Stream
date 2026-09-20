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
    StreamArtistRecoveredDelegatedConsentHydration as Consent
} from "./StreamArtistRecoveredDelegatedConsentHydration.sol";
import {
    StreamArtistPublicationHydrationTypes as PubH
} from "../../interfaces/stream/artist/IStreamArtistPublicationAuthorityHydration.sol";
import {
    StreamArtistRecoveredAttestationFactRows as AttestationRows
} from "./StreamArtistRecoveredAttestationFactRows.sol";
import {
    StreamArtistRecoveredContentConsentHydration as ContentH
} from "./StreamArtistRecoveredContentConsentHydration.sol";
import {
    StreamArtistRecoveredContentConsentFactRows as ContentRows
} from "./StreamArtistRecoveredContentConsentFactRows.sol";

import {
    StreamArtistRecoveredDelegationConsentFactRows as Rows
} from "./StreamArtistRecoveredDelegationConsentFactRows.sol";

/// @notice Complete original grant-use reconciliation across the fixed semantic owners.
/// @dev The source certificate authenticates the original grant and consent maps. Policy and
/// economics rows do not retain signer/nonce/time preimages, so their original fixed association
/// is not reauthorized against current grant liveness. Sale rows retain the delegate nonce and
/// additionally join its original Identity admission clock. Different owner revisions are never
/// compared; import-era ordering is shared, while within-era authority comes from the producer.
library StreamArtistRecoveredDelegationConsentFacts {
    function validate(
        IH.Bundle calldata identity,
        Consent.Bundle calldata consent,
        AH.Query calldata q,
        RH.Provenance calldata p,
        uint8 mode
    ) public pure {
        _validate(identity, consent, q, p, mode, new uint256[](identity.delegations.length));
    }

    /// @notice Adds original op24 uses before the same complete grant-use equality.
    function validate(
        IH.Bundle calldata identity,
        Consent.Bundle calldata consent,
        AH.Query calldata q,
        RH.Provenance calldata p,
        uint8 mode,
        PubH.Row[] calldata rows
    ) public pure {
        _validate(
            identity,
            consent,
            q,
            p,
            mode,
            AttestationRows.validateRows(
                AttestationRows.IdentityRows(
                    identity.artistId, identity.signatures, identity.delegations
                ),
                rows,
                AttestationRows.Scope(q.artistId, q.collectionId, q.bindingHash),
                p
            )
        );
    }

    /// @notice Adds original delegated20 and24 uses to the unchanged14/15/16 reconciliation.
    /// The new fixed owner6 codec validates the complete mixed journal before this join.
    function validate(
        IH.Bundle calldata identity,
        ContentH.Bundle calldata consent,
        AH.Query calldata q,
        RH.Provenance calldata p,
        uint8 mode,
        PubH.Row[] calldata rows
    ) public pure {
        uint256[] memory uses = ContentRows.validateRows(
            ContentRows.IdentityRows(identity.artistId, identity.signatures, identity.delegations),
            ContentRows.ConsentRows(
                consent.original.artistId,
                consent.original.collectionId,
                consent.original.bindingHash,
                consent.consents,
                consent.royalties,
                consent.freezes
            ),
            ContentRows.Scope(q.artistId, q.collectionId, q.bindingHash),
            p
        );
        uint256[] memory attestations = AttestationRows.validateRows(
            AttestationRows.IdentityRows(
                identity.artistId, identity.signatures, identity.delegations
            ),
            rows,
            AttestationRows.Scope(q.artistId, q.collectionId, q.bindingHash),
            p
        );
        for (uint256 i; i < uses.length; ++i) {
            uses[i] += attestations[i];
        }
        _validate(identity, consent.original, q, p, mode, uses);
    }

    /// @dev Public nominal selectors remain available to the fixed preparation staticcall join.
    /// Calldata projection runs after the original Content/Attestation accumulation order.
    function _validate(
        IH.Bundle calldata identity,
        Consent.Bundle calldata consent,
        AH.Query calldata q,
        RH.Provenance calldata p,
        uint8 mode,
        uint256[] memory uses
    ) private pure {
        Rows.validateRows(
            Rows.IdentityRows(identity.artistId, identity.delegations),
            Rows.ConsentRows(
                consent.artistId,
                consent.collectionId,
                consent.bindingHash,
                consent.policies,
                consent.economics,
                consent.sales
            ),
            Rows.Scope(q.artistId, q.collectionId, q.bindingHash),
            p,
            mode,
            uses
        );
    }
}
