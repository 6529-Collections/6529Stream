// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyContentCheckpointBaseV1 as Base
} from "./StreamPreservationPolicyContentCheckpointBaseV1.sol";

/// @notice Complete COLLECTION preservation output with each selected renderer's governed producer admission.
/// @dev Existing full-output checkpoints and their historical byte meanings are unchanged.
contract StreamPreservationPolicyContentCheckpointV1 is Base {
    constructor(
        address selection,
        address policySourceSet,
        address readiness,
        address executor,
        GasParameterConfig memory readGas,
        GasParameterConfig memory renderGas
    ) Base(selection, policySourceSet, readiness, false, executor, readGas, renderGas) { }
}
