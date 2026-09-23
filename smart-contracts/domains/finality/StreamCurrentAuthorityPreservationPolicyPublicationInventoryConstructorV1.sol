// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../../interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamCurrentAuthorityPreservationPolicyRenderCriticalInventoryV1 as Child
} from "../preservation/StreamCurrentAuthorityPreservationPolicyRenderCriticalInventoryV1.sol";

/// @notice Fixed delegate-host CREATE from the original typed constructor arguments.
library StreamCurrentAuthorityPreservationPolicyPublicationInventoryConstructorV1 {
    function deploy(S.Dependencies memory d, O.Dependencies memory od, D.Dependencies memory ad)
        public
        returns (address)
    {
        return address(new Child(d, od, ad));
    }
}
