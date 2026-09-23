// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyContentCheckpointBaseV1 as Base
} from "./StreamPreservationPolicyContentCheckpointBaseV1.sol";

/// @notice Complete COLLECTION preservation output with exact per-row governed producer admission.
/// @dev This wrapper fixes the original single-token profile; historical V1 meanings remain unchanged.
contract StreamPreservationPolicyContentCheckpointV1 is Base {
    bytes32 public constant PRESERVATION_PROFILE = keccak256("6529STREAM_PRESERVATION_RENDER_V1");

    constructor(
        address selection,
        address policySourceSet,
        address readiness,
        address executor,
        GasParameterConfig memory readGas,
        GasParameterConfig memory renderGas
    ) Base(selection, policySourceSet, readiness, false, false, executor, readGas, renderGas) { }

    function _preservationProfile() internal pure override returns (bytes32) {
        return PRESERVATION_PROFILE;
    }
}
