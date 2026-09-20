// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamScopedPolicyPublicationFactoryV2
} from "./IStreamScopedPolicyPublicationFactoryV2.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../preservation/StreamCurrentAuthorityInventoryTypes.sol";

/// @notice Fixed original recipe plus bounded origin and current-authority capabilities.
interface IStreamCurrentAuthorityScopedPolicyPublicationFactoryV2 is
    IStreamScopedPolicyPublicationFactoryV2
{
    function originDependencies() external view returns (O.Dependencies memory);
    function authorityDependencies() external view returns (D.Dependencies memory);
}
