// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamGasParameterHost as Gas
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamPreservationPolicyReferenceTypesV1 as T
} from "../../interfaces/stream/preservation/StreamPreservationPolicyReferenceTypesV1.sol";
import {
    StreamPreservationPolicyReferencePublicationV2 as Child
} from "../preservation/StreamPreservationPolicyReferencePublicationV2.sol";

/// @notice Fixed delegate-host CREATE from the original typed constructor arguments.
library StreamPreservationPolicyPublicationReferenceConstructorV2 {
    function deploy(
        T.Dependencies memory d,
        address executor,
        Gas.GasParameterConfig[4] memory configs
    ) public returns (address) {
        return address(new Child(d, executor, configs));
    }
}
