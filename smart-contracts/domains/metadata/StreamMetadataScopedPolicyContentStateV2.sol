// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamScopedPolicyContentRootPublicationV2 as V
} from "../../interfaces/stream/metadata/IStreamScopedPolicyContentRootPublicationV2.sol";

/// @notice Append-only interpretation companion. No new head, aggregate, consent or sequential slot.
library StreamMetadataScopedPolicyContentStateV2 {
    struct State {
        mapping(bytes32 => V.Binding) bindings;
    }
    bytes32 private constant SLOT = keccak256("6529STREAM_STORAGE_SCOPED_POLICY_CONTENT_ROOT_V2");

    function state() internal pure returns (State storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }
}
