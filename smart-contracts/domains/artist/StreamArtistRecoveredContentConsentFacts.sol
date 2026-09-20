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
    StreamArtistRecoveredContentConsentHydration as ContentH
} from "./StreamArtistRecoveredContentConsentHydration.sol";
import {
    StreamArtistRecoveredContentConsentFactRows as Rows
} from "./StreamArtistRecoveredContentConsentFactRows.sol";

/// @notice Original17/20/21 Identity evidence and delegated20 use reconciliation.
/// @dev The caller authenticates the complete source certificate, Identity bundle and owner6
/// codec first. These original maps omit signer/nonce/deadline preimages; their exact fixed-source
/// associations, native occurrences and replay cells authenticate the retained hashes. We do not
/// manufacture an Identity admission point, rehash absent fields, or reauthorize old grants.
/// Operation21 is a content-freeze authorization. Intent remains op24 subject7.
library StreamArtistRecoveredContentConsentFacts {
    /// @dev Preserve the source call shape while the separate linked worker decodes only the
    /// original fields it consumes. The explicit call does not inline the validator into callers.
    function validate(
        IH.Bundle memory identity,
        ContentH.Bundle memory consent,
        AH.Query memory q,
        RH.Provenance memory p
    ) internal pure returns (uint256[] memory uses) {
        return Rows.validateRows(
            Rows.IdentityRows(identity.artistId, identity.signatures, identity.delegations),
            Rows.ConsentRows(
                consent.original.artistId,
                consent.original.collectionId,
                consent.original.bindingHash,
                consent.consents,
                consent.royalties,
                consent.freezes
            ),
            Rows.Scope(q.artistId, q.collectionId, q.bindingHash),
            p
        );
    }
}
