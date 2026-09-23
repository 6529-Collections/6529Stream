// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamGasParameterHost as Gas
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamPreservationPolicyOutputManifestV2 as Child
} from "./StreamPreservationPolicyOutputManifestV2.sol";

/// @notice Fixed delegate-host CREATE from the original typed constructor arguments.
library StreamPreservationPolicyPublicationOutputConstructorV2 {
    function deploy(
        address core_,
        address checkpoint_,
        address coverage_,
        address executor,
        Gas.GasParameterConfig memory readGas
    ) public returns (address) {
        return address(new Child(core_, checkpoint_, coverage_, executor, readGas));
    }
}
