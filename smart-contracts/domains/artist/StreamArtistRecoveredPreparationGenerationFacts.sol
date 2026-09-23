// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
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
    StreamArtistRecoveredBindingGenerations as Generations
} from "./StreamArtistRecoveredBindingGenerations.sol";
import {
    StreamArtistRecoveredBindingGenerationFactRows as Rows
} from "./StreamArtistRecoveredBindingGenerationFactRows.sol";

/// @notice The complete original generation join through its fixed typed row validator.
/// @dev Identity and generation bundles have already passed their original source collectors.
library StreamArtistRecoveredPreparationGenerationFacts {
    function validate(
        IH.Bundle calldata identity,
        Generations.Bundle calldata bindings,
        AH.Query calldata query,
        RH.Provenance calldata provenance
    ) public pure {
        Rows.validateRows(
            Rows.IdentityRows(identity.artistId, identity.documents, identity.signatures),
            bindings,
            Rows.Scope(query.artistId, query.collectionId, query.bindingHash),
            provenance
        );
    }
}
