// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamScopedPreservationPolicyContentRootPublicationV1 as V
} from "../../interfaces/stream/metadata/IStreamScopedPreservationPolicyContentRootPublicationV1.sol";

/// @notice Append-only interpretation companion. No new head, aggregate, consent or sequential slot.
library StreamMetadataScopedPreservationPolicyContentStateV1 {
    struct State {
        mapping(bytes32 => V.Binding) bindings;
    }
    bytes32 private constant SLOT =
        keccak256("6529STREAM_STORAGE_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_V1");

    function state() internal pure returns (State storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }
}
