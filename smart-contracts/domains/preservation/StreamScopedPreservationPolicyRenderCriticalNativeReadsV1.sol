// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalTypesV1 as Scoped
} from "../../interfaces/stream/preservation/StreamScopedPreservationPolicyRenderCriticalTypesV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalStateV1 as State
} from "./StreamScopedPreservationPolicyRenderCriticalStateV1.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Family
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    StreamScopedPreservationPolicyNativeAppendV1 as Append
} from "./StreamScopedPreservationPolicyNativeAppendV1.sol";
import {
    StreamScopedPreservationPolicyNativeSegmentV1 as Segment
} from "./StreamScopedPreservationPolicyNativeSegmentV1.sol";

/// @notice Complete original scoped source/receipt/runtime inventory in bounded ordered segments.
/// @dev Output manifest rows are hash inventory, explicitly separate from per-token full-byte rows.
/// Fixed workers separate current-context, stored-context and source/row codecs. No read,
/// hash, storage mutation or caller-selected dispatch is introduced by these boundaries.
library StreamScopedPreservationPolicyRenderCriticalNativeReadsV1 {
    // Preserve the original public error ABI after moving the last local checks.
    error InvalidInventoryItem();
    error InvalidInventorySegment();
    error InventoryIncomplete();
    error InventoryRead(address target);
    error InventorySourceChanged();

    function appendNative(State.State storage state, bytes32 id, uint64 maximum) public {
        Append.appendNative(state, id, maximum);
    }

    function items(S.Dependencies memory d, Scoped.Context memory c, uint64 start, uint64 maximum)
        public
        view
        returns (T.Item[] memory rows, uint64 total)
    {
        return items(d, c, start, maximum, Family.ORIGINAL_PROFILE);
    }

    function items(
        S.Dependencies memory d,
        Scoped.Context memory c,
        uint64 start,
        uint64 maximum,
        bytes32 family
    ) public view returns (T.Item[] memory rows, uint64 total) {
        return Segment.items(d, c, start, maximum, family);
    }
}
