// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
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
    StreamScopedPreservationPolicyNativeStageV1 as Stage
} from "./StreamScopedPreservationPolicyNativeStageV1.sol";
import {
    StreamScopedPreservationPolicyNativeSegmentV1 as Segment
} from "./StreamScopedPreservationPolicyNativeSegmentV1.sol";

/// @notice Fixed original native append orchestration on the caller's compiler-owned State.
/// @dev Stage/current validation remains first; source/count/append/cursor order is unchanged.
library StreamScopedPreservationPolicyNativeAppendV1 {
    function appendNative(State.State storage state, bytes32 id, uint64 maximum) public {
        Stage.requireStage(state, id);
        Scoped.Plan storage p = state.plans[id];
        (T.Item[] memory rows, uint64 total) = Segment.items(
            state.dependencies, state.contexts[id], p.nativeCursor, maximum, Family.ORIGINAL_PROFILE
        );
        if (p.nativeCursor != 0 && p.nativeCount != total) revert T.InventorySourceChanged();
        p.nativeCount = total;
        State.append(
            state,
            id,
            rows,
            keccak256(abi.encode(p.progress.sourceContextHash, p.nativeCursor, total))
        );
        p.nativeCursor += uint64(rows.length);
        if (p.nativeCursor == total) p.progress.completedStages = 1;
    }
}
