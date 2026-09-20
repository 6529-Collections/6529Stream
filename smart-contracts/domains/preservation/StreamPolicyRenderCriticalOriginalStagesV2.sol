// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
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

library StreamPolicyRenderCriticalOriginalStagesV2 {
    function appendNative(State.State storage s, bytes32 id) public {
        State.stage(s, id, 0);
        State.append(
            s,
            id,
            Native.items(s.records.dependencies, s.contexts[id]),
            s.records.plans[id].sourceContextHash
        );
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

    function appendRoot(
        State.State storage s,
        bytes32 id,
        address actor,
        uint64 observedAt,
        Aggregate.Aggregate memory originalAggregate
    ) public {
        State.stage(s, id, 6);
        T.Item[] memory rows = new T.Item[](1);
        rows[0] = Root.contentItem(
            s.records.dependencies, s.contexts[id], actor, observedAt, originalAggregate
        );
        State.append(s, id, rows, s.contexts[id].records.rootRecordHash);
        s.records.plans[id].completedStages = 7;
    }
}
