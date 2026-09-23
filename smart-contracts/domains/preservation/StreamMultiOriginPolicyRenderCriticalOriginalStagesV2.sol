// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamMultiOriginNativeRoles as Roles } from "./StreamMultiOriginNativeRoles.sol";
import {
    StreamPolicyRenderCriticalStateV2 as State
} from "./StreamPolicyRenderCriticalStateV2.sol";
import {
    StreamPolicyRenderCriticalNativeReadsV2 as Native
} from "./StreamPolicyRenderCriticalNativeReadsV2.sol";
import {
    StreamPolicyReferenceInventoryReadsV2 as Reference
} from "./StreamPolicyReferenceInventoryReadsV2.sol";
import {
    StreamPolicyRenderCriticalRootAuthorizationV2 as Root
} from "./StreamPolicyRenderCriticalRootAuthorizationV2.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    IStreamScopedContentRootPublication as Aggregate
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";

library StreamMultiOriginPolicyRenderCriticalOriginalStagesV2 {
    function appendNative(State.State storage s, bytes32 id) public {
        State.stage(s, id, 0);
        T.Item[] memory nativeRows = Native.items(s.records.dependencies, s.contexts[id]);
        Roles.relabel(nativeRows);
        State.append(s, id, nativeRows, s.records.plans[id].sourceContextHash);
        s.records.plans[id].completedStages = 1;
    }

    function appendReference(State.State storage s, bytes32 id) public {
        State.stage(s, id, 1);
        State.append(
            s,
            id,
            Reference.items(s.records.dependencies, s.contexts[id]),
            s.contexts[id].referenceRender.observation.recordHash
        );
        s.records.plans[id].completedStages = 2;
    }
}
