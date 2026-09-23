// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamGasParameterHost as Gas
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    StreamScopedPreservationPolicySnapshotPublicationV2 as Child
} from "../metadata/StreamScopedPreservationPolicySnapshotPublicationV2.sol";

/// @notice Fixed delegate-host CREATE from the original typed constructor arguments.
library StreamScopedPreservationPolicyPublicationSnapshotConstructorV2 {
    function deploy(
        S.Dependencies memory d,
        address executor,
        Gas.GasParameterConfig[3] memory configs
    ) public returns (address) {
        return address(new Child(d, executor, configs));
    }
}
