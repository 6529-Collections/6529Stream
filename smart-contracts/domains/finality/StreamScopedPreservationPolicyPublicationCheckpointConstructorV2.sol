// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamGasParameterHost as Gas
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamScopedPreservationPolicyContentCheckpointV2 as Child
} from "./StreamScopedPreservationPolicyContentCheckpointV2.sol";

/// @notice Fixed delegate-host CREATE from the original typed constructor arguments.
library StreamScopedPreservationPolicyPublicationCheckpointConstructorV2 {
    function deploy(
        address selection,
        address policySourceSet,
        address readiness,
        address executor,
        Gas.GasParameterConfig memory readGas,
        Gas.GasParameterConfig memory renderGas
    ) public returns (address) {
        return address(
            new Child(selection, policySourceSet, readiness, executor, readGas, renderGas)
        );
    }
}
