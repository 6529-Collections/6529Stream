// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamPreservationPolicyContentRootPublicationV1 as V
} from "../../interfaces/stream/metadata/IStreamPreservationPolicyContentRootPublicationV1.sol";

/// @notice Closed append-only companion namespace; original Router sequential roots stay exact.
library StreamPreservationPolicyContentRootStateV1 {
    struct State {
        mapping(bytes32 => V.Binding) bindings;
    }
    bytes32 private constant SLOT =
        keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_STORAGE_V1");

    function state() internal pure returns (State storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }
}
