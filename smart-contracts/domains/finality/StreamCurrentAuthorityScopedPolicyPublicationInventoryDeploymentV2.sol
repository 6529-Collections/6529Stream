// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamScopedPolicyPublicationGraphTypesV2 as T
} from "../../interfaces/stream/finality/StreamScopedPolicyPublicationGraphTypesV2.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../../interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamCurrentAuthorityScopedPolicyRenderCriticalInventoryV2 as Child
} from "../preservation/StreamCurrentAuthorityScopedPolicyRenderCriticalInventoryV2.sol";
import {
    StreamScopedPolicyPublicationRecipeV2 as Recipe
} from "./StreamScopedPolicyPublicationRecipeV2.sol";

/// @notice Fixed delegate-host CREATE; no caller-selected implementation or authority.
library StreamCurrentAuthorityScopedPolicyPublicationInventoryDeploymentV2 {
    function deploy(
        T.Recipe memory r,
        T.Graph memory g,
        O.Dependencies memory origin,
        D.Dependencies memory authority
    ) public returns (address) {
        return address(new Child(Recipe.inventory(r, g), origin, authority));
    }
}
