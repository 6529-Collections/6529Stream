// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamScopedPreservationPolicyPublicationGraphTypesV1 as T
} from "../../interfaces/stream/finality/StreamScopedPreservationPolicyPublicationGraphTypesV1.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../../interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1 as Child
} from "../preservation/StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1.sol";
import {
    StreamScopedPreservationPolicyPublicationRecipeV1 as Recipe
} from "./StreamScopedPreservationPolicyPublicationRecipeV1.sol";

/// @notice Fixed delegate-host CREATE; no caller-selected implementation or authority.
library StreamCurrentAuthorityScopedPreservationPolicyPublicationInventoryDeploymentV1 {
    function deploy(
        T.Recipe memory r,
        T.Graph memory g,
        O.Dependencies memory origin,
        D.Dependencies memory authority
    ) public returns (address) {
        return address(new Child(Recipe.inventory(r, g), origin, authority));
    }
}
