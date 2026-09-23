// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamGasParameterHost as Gas
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamPolicySnapshotTypesV2 as S
} from "../../interfaces/stream/metadata/StreamPolicySnapshotTypesV2.sol";
import {
    StreamPolicySnapshotPublicationV2 as Child
} from "../metadata/StreamPolicySnapshotPublicationV2.sol";

/// @notice Fixed delegate-host CREATE from the original typed constructor arguments.
library StreamPolicyPublicationSnapshotConstructorV2 {
    function deploy(
        S.Dependencies memory d,
        address executor,
        Gas.GasParameterConfig[3] memory configs
    ) public returns (address) {
        return address(new Child(d, executor, configs));
    }
}
