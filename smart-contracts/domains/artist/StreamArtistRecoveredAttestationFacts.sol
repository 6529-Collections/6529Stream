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
    StreamArtistPublicationHydrationTypes as PubH
} from "../../interfaces/stream/artist/IStreamArtistPublicationAuthorityHydration.sol";
import {
    StreamArtistRecoveredAttestationFactRows as Rows
} from "./StreamArtistRecoveredAttestationFactRows.sol";

/// @notice Joins original op24 records to their actual Identity admission and grant use.
/// @dev The caller first authenticates the complete source certificate and both owners' typed
/// maps. This leaf does not reauthorize historical signers, subject facts, grant liveness or estate
/// capabilities against today's state. Signed time is not the Identity admission clock.
library StreamArtistRecoveredAttestationFacts {
    /// @dev Keep the public nominal selector used by the fixed preparation staticcall join.
    /// Decode only the fields consumed by the separate linked worker.
    function validate(
        IH.Bundle calldata identity,
        PubH.Row[] calldata rows,
        AH.Query calldata q,
        RH.Provenance calldata p
    ) public pure returns (uint256[] memory uses) {
        return Rows.validateRows(
            Rows.IdentityRows(identity.artistId, identity.signatures, identity.delegations),
            rows,
            Rows.Scope(q.artistId, q.collectionId, q.bindingHash),
            p
        );
    }

    /// @notice Additive generation-bound join; the original validate selector stays generation one.
    function validateGeneration(
        IH.Bundle calldata identity,
        PubH.Row[] calldata rows,
        AH.Query calldata q,
        RH.Provenance calldata p,
        uint64 generation
    ) public pure returns (uint256[] memory uses) {
        return Rows.validateGenerationRows(
            Rows.IdentityRows(identity.artistId, identity.signatures, identity.delegations),
            rows,
            Rows.Scope(q.artistId, q.collectionId, q.bindingHash),
            p,
            generation
        );
    }
}
