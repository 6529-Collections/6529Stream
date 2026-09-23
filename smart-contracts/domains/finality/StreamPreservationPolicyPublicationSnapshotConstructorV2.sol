// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamGasParameterHost as Gas
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamPreservationPolicySnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamPreservationPolicySnapshotTypesV1.sol";
import {
    StreamPreservationPolicySnapshotPublicationV2 as Child
} from "../metadata/StreamPreservationPolicySnapshotPublicationV2.sol";

/// @notice Fixed delegate-host CREATE from the original typed constructor arguments.
library StreamPreservationPolicyPublicationSnapshotConstructorV2 {
    function deploy(
        S.Dependencies memory d,
        address executor,
        Gas.GasParameterConfig[3] memory configs
    ) public returns (address) {
        return address(new Child(d, executor, configs));
    }
}
