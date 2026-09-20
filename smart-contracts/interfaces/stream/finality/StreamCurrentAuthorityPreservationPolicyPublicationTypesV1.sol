// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamPreservationPolicyPublicationGraphTypesV1 as T
} from "./StreamPreservationPolicyPublicationGraphTypesV1.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../preservation/StreamCurrentAuthorityInventoryTypes.sol";

/// @notice Additive current-authority graph domains; original publication domains are unchanged.
library StreamCurrentAuthorityPreservationPolicyPublicationTypesV1 {
    bytes32 internal constant FACTORY_PROFILE =
        keccak256("6529STREAM_CURRENT_AUTHORITY_PRESERVATION_POLICY_PUBLICATION_FACTORY_V1");
    bytes32 internal constant GRAPH_DOMAIN =
        keccak256("6529STREAM_CURRENT_AUTHORITY_PRESERVATION_POLICY_PUBLICATION_GRAPH_V1");
    bytes32 internal constant PROVIDER_CONFIGURATION_DOMAIN =
        keccak256("6529STREAM_CURRENT_AUTHORITY_PRESERVATION_POLICY_PROVIDER_CONFIGURATION_V1");
    bytes32 internal constant SOURCE_CONFIGURATION_DOMAIN =
        keccak256("6529STREAM_CURRENT_AUTHORITY_PRESERVATION_POLICY_SOURCE_CONFIGURATION_V1");

    function recipeHash(
        uint256 chainId,
        T.Recipe memory r,
        O.Dependencies memory origin,
        D.Dependencies memory authority
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(FACTORY_PROFILE, chainId, r, origin, authority));
    }
}
