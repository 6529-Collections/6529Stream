// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamPreservationPolicyPublicationFactoryV1
} from "./IStreamPreservationPolicyPublicationFactoryV1.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../preservation/StreamCurrentAuthorityInventoryTypes.sol";

/// @notice Fixed original recipe plus bounded origin and current-authority capabilities.
interface IStreamCurrentAuthorityPreservationPolicyPublicationFactoryV1 is
    IStreamPreservationPolicyPublicationFactoryV1
{
    function originDependencies() external view returns (O.Dependencies memory);
    function authorityDependencies() external view returns (D.Dependencies memory);
}
