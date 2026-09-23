// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRenderCriticalSourceTypes as Dependencies
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../../interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1 as Child
} from "../preservation/StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1.sol";

/// @notice Fixed delegate-host CREATE from the original projected dependencies.
library StreamCurrentAuthorityScopedPreservationPolicyPublicationInventoryConstructorV1 {
    function deploy(
        Dependencies.Dependencies memory dependencies,
        O.Dependencies memory origin,
        D.Dependencies memory authority
    ) public returns (address) {
        return address(new Child(dependencies, origin, authority));
    }
}
