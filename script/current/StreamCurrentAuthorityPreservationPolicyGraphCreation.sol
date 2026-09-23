// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityPreservationPolicyPublicationFactoryV1
} from "../../smart-contracts/domains/finality/StreamCurrentAuthorityPreservationPolicyPublicationFactoryV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyPublicationFactoryV1
} from "../../smart-contracts/domains/finality/StreamCurrentAuthorityScopedPreservationPolicyPublicationFactoryV1.sol";
import {
    StreamCurrentAuthorityFullPreservationPolicyEvidenceProviderV1
} from "../../smart-contracts/domains/finality/StreamCurrentAuthorityFullPreservationPolicyEvidenceProviderV1.sol";
import {
    StreamCurrentAuthorityFullPreservationPolicyDiscoveryV1
} from "../../smart-contracts/domains/finality/StreamCurrentAuthorityFullPreservationPolicyDiscoveryV1.sol";
import {
    StreamCurrentAuthorityScopedPolicyGraphCreation as Prefix
} from "./StreamCurrentAuthorityScopedPolicyGraphCreation.sol";

/// @notice Literal linked creation templates for the full preservation genesis recipe.
/// @dev Simulation-only. Unchanged native source-prefix products retain their existing templates.
library StreamCurrentAuthorityPreservationPolicyGraphCreation {
    function code(string memory name) internal pure returns (bytes memory) {
        bytes32 key = keccak256(bytes(name));
        if (key == keccak256("StreamCurrentAuthorityPreservationPolicyPublicationFactoryV1")) {
            return type(StreamCurrentAuthorityPreservationPolicyPublicationFactoryV1).creationCode;
        }
        if (key == keccak256("StreamCurrentAuthorityScopedPreservationPolicyPublicationFactoryV1"))
        {
            return
                type(StreamCurrentAuthorityScopedPreservationPolicyPublicationFactoryV1)
                .creationCode;
        }
        if (key == keccak256("StreamCurrentAuthorityFullPreservationPolicyEvidenceProviderV1")) {
            return type(StreamCurrentAuthorityFullPreservationPolicyEvidenceProviderV1).creationCode;
        }
        if (key == keccak256("StreamCurrentAuthorityFullPreservationPolicyDiscoveryV1")) {
            return type(StreamCurrentAuthorityFullPreservationPolicyDiscoveryV1).creationCode;
        }
        return Prefix.code(name);
    }
}
