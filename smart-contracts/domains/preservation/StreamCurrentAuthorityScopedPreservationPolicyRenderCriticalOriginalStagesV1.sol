// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationTokenProducerProfilesV1 as Family
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalStateV1 as State
} from "./StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalStateV1.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalTypesV1 as Scoped
} from "../../interfaces/stream/preservation/StreamScopedPreservationPolicyRenderCriticalTypesV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalNativeReadsV1 as Native
} from "./StreamScopedPreservationPolicyRenderCriticalNativeReadsV1.sol";
import { StreamMultiOriginNativeRoles as Roles } from "./StreamMultiOriginNativeRoles.sol";

library StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalOriginalStagesV1 {
    function appendNative(State.State storage state, bytes32 id, uint64 maximum) public {
        State.stage(state, id, 0);
        Scoped.Plan storage p = state.plans[id];
        (T.Item[] memory rows, uint64 total) = Native.items(
            state.dependencies, state.contexts[id], p.nativeCursor, maximum, Family.FAMILY_PROFILE
        );
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
