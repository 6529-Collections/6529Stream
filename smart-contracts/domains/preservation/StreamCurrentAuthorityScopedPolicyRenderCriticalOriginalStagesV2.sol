// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamCurrentAuthorityScopedPolicyRenderCriticalStateV2 as State
} from "./StreamCurrentAuthorityScopedPolicyRenderCriticalStateV2.sol";
import {
    StreamScopedPolicyRenderCriticalTypesV2 as Scoped
} from "../../interfaces/stream/preservation/StreamScopedPolicyRenderCriticalTypesV2.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamScopedPolicyRenderCriticalNativeReadsV2 as Native
} from "./StreamScopedPolicyRenderCriticalNativeReadsV2.sol";
import { StreamMultiOriginNativeRoles as Roles } from "./StreamMultiOriginNativeRoles.sol";

library StreamCurrentAuthorityScopedPolicyRenderCriticalOriginalStagesV2 {
    function appendNative(State.State storage state, bytes32 id, uint64 maximum) public {
        State.stage(state, id, 0);
        Scoped.Plan storage p = state.plans[id];
        (T.Item[] memory rows, uint64 total) =
            Native.items(state.dependencies, state.contexts[id], p.nativeCursor, maximum);
        Roles.relabel(rows);
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
