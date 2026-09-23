// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamScopedPolicyRenderCriticalTypesV2 as Scoped
} from "../../interfaces/stream/preservation/StreamScopedPolicyRenderCriticalTypesV2.sol";
import {
    StreamScopedPolicyReferenceTypesV2 as R
} from "../../interfaces/stream/preservation/StreamScopedPolicyReferenceTypesV2.sol";
import {
    StreamScopedPolicySnapshotTypesV2 as Snapshot
} from "../../interfaces/stream/metadata/StreamScopedPolicySnapshotTypesV2.sol";
import {
    IStreamScopedPolicySnapshotPublicationV2 as Snap
} from "../../interfaces/stream/metadata/IStreamScopedPolicySnapshotPublicationV2.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamScopedPolicyRenderCriticalStateV2 as State
} from "./StreamScopedPolicyRenderCriticalStateV2.sol";
import {
    StreamScopedPolicyRenderCriticalSourceReadsV2 as Sources
} from "./StreamScopedPolicyRenderCriticalSourceReadsV2.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import {
    StreamScopedPolicySnapshotDefinitionsV2 as Definitions
} from "../records/StreamScopedPolicySnapshotDefinitionsV2.sol";
import {
    IStreamFinalityScopedEntropyPolicySourceFactoryV2 as Factory
} from "../../interfaces/stream/finality/IStreamFinalityScopedEntropyPolicySourceFactoryV2.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as Policies
} from "../finality/StreamFinalityCoordinatorPolicyReadsV2.sol";
import {
    StreamScopedPolicyOutputSchemasV2 as OutputSchemas
} from "../finality/StreamScopedPolicyOutputSchemasV2.sol";

import { StreamScopedPolicyRenderCriticalNativeItemsV2 as NativeItems } from "./StreamScopedPolicyRenderCriticalNativeItemsV2.sol";

/// @notice Complete original scoped source/receipt/runtime inventory in bounded ordered segments.
/// @dev Output manifest rows are hash inventory, explicitly separate from per-token full-byte rows.
library StreamScopedPolicyRenderCriticalNativeReadsV2 {
    // Preserve errors previously inferred from the complete inlined read body.
    error InvalidInventoryItem();
    error InventoryRead(address target);

    function appendNative(State.State storage state, bytes32 id, uint64 maximum) public {
        State.stage(state, id, 0);
        Scoped.Plan storage p = state.plans[id];
        (T.Item[] memory rows, uint64 total) =
            items(state.dependencies, state.contexts[id], p.nativeCursor, maximum);
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

    function items(S.Dependencies memory d, Scoped.Context memory c, uint64 start, uint64 maximum)
        public
        view
        returns (T.Item[] memory rows, uint64 total)
    {
        return NativeItems.items(d, c, start, maximum);
    }
}
