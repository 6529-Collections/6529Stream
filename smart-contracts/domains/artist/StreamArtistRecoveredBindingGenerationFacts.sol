// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredBindingGenerations as Generations
} from "./StreamArtistRecoveredBindingGenerations.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredBindingGenerationFactRows as Rows
} from "./StreamArtistRecoveredBindingGenerationFactRows.sol";

/// @notice Joins complete pending-generation history to its original Identity evidence.
/// @dev Callers first authenticate the complete provenance, Identity bundle, Binding generation
/// codec and sole Acceptance map. Original2/3 retain signatures but no record-keyed Identity
/// admission or signer/nonce/deadline preimages. The fixed original producers authenticate those
/// missing fields; complete nonce/replay transport is checked separately. No historical signer,
/// operative document or signature is reauthorized against current recovered authority.
library StreamArtistRecoveredBindingGenerationFacts {
    /// @dev Keep the source call shape while a separate linked worker decodes only used fields.
    function validate(
        IH.Bundle memory identity,
        Generations.Bundle memory bindings,
        AH.Query memory q,
        RH.Provenance memory p
    ) internal pure {
        Rows.validateRows(
            Rows.IdentityRows(identity.artistId, identity.documents, identity.signatures),
            bindings,
            Rows.Scope(q.artistId, q.collectionId, q.bindingHash),
            p
        );
    }
}
