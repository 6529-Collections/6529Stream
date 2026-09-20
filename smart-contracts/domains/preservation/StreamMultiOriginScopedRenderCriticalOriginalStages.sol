// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamMultiOriginScopedRenderCriticalState as State
} from "./StreamMultiOriginScopedRenderCriticalState.sol";
import {
    StreamScopedRenderCriticalTypes as Scoped
} from "../../interfaces/stream/preservation/StreamScopedRenderCriticalTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamScopedRenderCriticalNativeReads as Native
} from "./StreamScopedRenderCriticalNativeReads.sol";
import { StreamMultiOriginNativeRoles as Roles } from "./StreamMultiOriginNativeRoles.sol";
import {
    StreamScopedReferenceInventoryReads as Reference
} from "./StreamScopedReferenceInventoryReads.sol";

library StreamMultiOriginScopedRenderCriticalOriginalStages {
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

    function appendReference(State.State storage state, bytes32 id, uint64 maximum) public {
        State.stage(state, id, 1);
        if (maximum == 0 || maximum > 64) revert T.InvalidInventorySegment();
        Scoped.Plan storage plan_ = state.plans[id];
        (T.Item[] memory rows, uint64 total) =
            Reference.items(state.dependencies, state.contexts[id], plan_.referenceCursor, maximum);
        if (plan_.referenceCursor != 0 && plan_.referenceCount != total) {
            revert T.InventorySourceChanged();
        }
        plan_.referenceCount = total;
        State.append(
            state,
            id,
            rows,
            keccak256(
                abi.encode(
                    state.contexts[id].referenceRender.observation.payloadHash,
                    plan_.referenceCursor,
                    total
                )
            )
        );
        plan_.referenceCursor += uint64(rows.length);
        if (plan_.referenceCursor == total) plan_.progress.completedStages = 2;
    }
}
