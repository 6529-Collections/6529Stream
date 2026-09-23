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
    StreamArtistPublicationHydrationTypes as PH
} from "../../interfaces/stream/artist/IStreamArtistPublicationAuthorityHydration.sol";
import {
    StreamArtistRecoveredContentConsentHydration as Original
} from "./StreamArtistRecoveredContentConsentHydration.sol";
import {
    StreamArtistRecoveredContentConsentFactRows as ContentRows
} from "./StreamArtistRecoveredContentConsentFactRows.sol";
import {
    StreamArtistRecoveredAttestationFactRows as AttestationRows
} from "./StreamArtistRecoveredAttestationFactRows.sol";
import {
    StreamArtistRecoveredDelegationConsentFactRows as BaseRows
} from "./StreamArtistRecoveredDelegationConsentFactRows.sol";
import {
    StreamArtistRecoveredGenerationBaseConsents as Codec
} from "./StreamArtistRecoveredGenerationBaseConsents.sol";

/// @notice Full original direct consent/signature/grant inventory joined at the final generation.
/// @dev The original admission/export authenticates the complete Identity nonce and replay trees.
/// Missing original14/15/17/20/21 signer/time preimages are never fabricated or reauthorized.
library StreamArtistRecoveredGenerationBaseConsentFacts {
    function validate(
        IH.Bundle calldata identity,
        Original.Bundle calldata consent,
        AH.Query calldata q,
        RH.Provenance calldata p,
        uint8 generation,
        PH.Row[] calldata rows
    ) public pure {
        Codec.validate(consent, q, RH.ownerProvenance(p, 6), generation);
        if (identity.delegations.length != 0) revert RH.InvalidRecoveredHydrationProfile();
        uint256[] memory uses = ContentRows.validateGenerationRows(
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
            p,
            generation
        );
        AttestationRows.validateGenerationRows(
            AttestationRows.IdentityRows(
                identity.artistId, identity.signatures, identity.delegations
            ),
            rows,
            AttestationRows.Scope(q.artistId, q.collectionId, q.bindingHash),
            p,
            generation
        );
        BaseRows.validateRows(
            BaseRows.IdentityRows(identity.artistId, identity.delegations),
            BaseRows.ConsentRows(
                consent.original.artistId,
                consent.original.collectionId,
                consent.original.bindingHash,
                consent.original.policies,
                consent.original.economics,
                consent.original.sales
            ),
            BaseRows.Scope(q.artistId, q.collectionId, q.bindingHash),
            p,
            1,
            uses
        );
    }
}
