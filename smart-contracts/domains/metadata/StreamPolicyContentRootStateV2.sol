// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamPolicyContentRootPublicationV2 as V
} from "../../interfaces/stream/metadata/IStreamPolicyContentRootPublicationV2.sol";

/// @notice Closed append-only companion namespace; original Router sequential roots stay exact.
library StreamPolicyContentRootStateV2 {
    struct State {
        mapping(bytes32 => V.Binding) bindings;
    }
    bytes32 private constant SLOT =
        0xb4dc8fd362c8aa4e0824104187bcdaa59560ff5a3a63a958d79d903643b1ff95;

    function state() internal pure returns (State storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }
}
