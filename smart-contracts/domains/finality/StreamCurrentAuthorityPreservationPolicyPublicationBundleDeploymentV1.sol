// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyPublicationGraphTypesV1 as T
} from "../../interfaces/stream/finality/StreamPreservationPolicyPublicationGraphTypesV1.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../../interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamCurrentAuthorityPreservationPolicyBundleArchiveCoverageV1 as Child
} from "../preservation/StreamCurrentAuthorityPreservationPolicyBundleArchiveCoverageV1.sol";
import {
    StreamPreservationPolicyPublicationRecipeV1 as Recipe
} from "./StreamPreservationPolicyPublicationRecipeV1.sol";

/// @notice Fixed delegate-host CREATE with the preservation inventory profile explicitly bound.
library StreamCurrentAuthorityPreservationPolicyPublicationBundleDeploymentV1 {
    function deploy(
        T.Recipe memory r,
        T.Graph memory g,
        O.Dependencies memory origin,
        D.Dependencies memory authority
    ) public returns (address) {
        return address(new Child(Recipe.bundle(r, g), origin, authority));
    }
}
