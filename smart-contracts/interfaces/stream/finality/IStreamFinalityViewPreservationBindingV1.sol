// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityViewPreservationBindingTypesV1 as V
} from "./StreamFinalityViewPreservationBindingTypesV1.sol";

import { StreamViewAdoptionTypes as D } from "../metadata/StreamViewAdoptionTypes.sol";

/// @notice Explicit pending/bound lifecycle; this does not advertise complete VIEW finality.
interface IStreamFinalityViewPreservationBindingV1 {
    event ViewPreservationBound(
        bytes32 indexed recordHash,
        bytes32 indexed actionId,
        address indexed snapshotHost,
        bytes32 proposalHash,
        bytes32 dependenciesHash
    );
    function viewPreservationBindingProfile() external pure returns (bytes32);
    function viewPreservationBindingStatus() external view returns (uint8);
    function viewPreservationBindingCapability() external view returns (V.Capability memory);
    function viewPreservationBindingReceipt() external view returns (V.Receipt memory);
    function viewPreservationBindingTransition(
        V.Configuration calldata configuration,
        D.Binding calldata declaration
    ) external view returns (V.Transition memory);
    function bindViewPreservation(
        V.Configuration calldata configuration,
        D.Binding calldata declaration
    ) external returns (bytes32 recordHash);
}
