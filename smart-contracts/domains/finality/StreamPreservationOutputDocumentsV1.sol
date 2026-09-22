// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamPreservationPolicyOutputSchemasV1 as V1
} from "./StreamPreservationPolicyOutputSchemasV1.sol";
import {
    StreamPreservationPolicyOutputSchemasV2 as V2
} from "./StreamPreservationPolicyOutputSchemasV2.sol";

/// @notice Fixed canonical document bytes for the two original output-manifest families.
/// @dev The host retains all registry reads, framing checks and governed gas lookups.
library StreamPreservationOutputDocumentsV1 {
    function document(bool familyV2, bytes32 id) public pure returns (bytes memory) {
        return familyV2 ? V2.document(id) : V1.document(id);
    }
}
