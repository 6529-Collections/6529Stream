// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamViewPreservationRenderCriticalTypesV1 as View
} from "../../interfaces/stream/preservation/StreamViewPreservationRenderCriticalTypesV1.sol";
import {
    StreamViewPreservationReferenceTypesV1 as R
} from "../../interfaces/stream/preservation/StreamViewPreservationReferenceTypesV1.sol";
import {
    StreamViewPreservationSnapshotTypesV1 as Snapshot
} from "../../interfaces/stream/metadata/StreamViewPreservationSnapshotTypesV1.sol";
import {
    IStreamViewPreservationSnapshotPublicationV1 as Snap
} from "../../interfaces/stream/metadata/IStreamViewPreservationSnapshotPublicationV1.sol";
import {
    IStreamViewPreservationOutputManifestV1 as Manifest
} from "../../interfaces/stream/finality/IStreamViewPreservationOutputManifestV1.sol";
import {
    StreamViewPreservationManifestTypesV1 as M
} from "../../interfaces/stream/finality/StreamViewPreservationManifestTypesV1.sol";
import {
    StreamViewPreservationOutputSchemasV1 as OutputDefinitions
} from "../finality/StreamViewPreservationOutputSchemasV1.sol";
import {
    StreamViewPreservationSnapshotDefinitionsV1 as Definitions
} from "../records/StreamViewPreservationSnapshotDefinitionsV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamViewPreservationRenderCriticalStateV1 as State
} from "./StreamViewPreservationRenderCriticalStateV1.sol";
import {
    StreamViewPreservationRenderCriticalSourceReadsV1 as Sources
} from "./StreamViewPreservationRenderCriticalSourceReadsV1.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";

import {
    StreamViewPreservationRenderCriticalNativeReadsV1 as Native
} from "./StreamViewPreservationRenderCriticalNativeReadsV1.sol";

/// @notice Original ordered native stage over the caller-owned inventory storage.
library StreamViewPreservationRenderCriticalNativeStagesV1 {
    function appendNative(State.State storage s, bytes32 id, uint64 maximum) public {
        State.stage(s, id, 0);
        View.Plan storage p = s.plans[id];
        (T.Item[] memory rows, uint64 total) =
            Native.items(s.dependencies, s.contexts[id], p.nativeCursor, maximum);
        if (p.nativeCursor != 0 && p.nativeCount != total) revert T.InventorySourceChanged();
        p.nativeCount = total;
        State.append(
            s, id, rows, keccak256(abi.encode(p.progress.sourceContextHash, p.nativeCursor, total))
        );
        p.nativeCursor += uint64(rows.length);
        if (p.nativeCursor == total) p.progress.completedStages = 1;
    }
}
