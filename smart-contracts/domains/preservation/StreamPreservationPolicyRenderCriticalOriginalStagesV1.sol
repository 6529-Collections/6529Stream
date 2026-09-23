// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyRenderCriticalStateV1 as State
} from "./StreamPreservationPolicyRenderCriticalStateV1.sol";
import {
    StreamPreservationPolicyRenderCriticalNativeReadsV1 as Native
} from "./StreamPreservationPolicyRenderCriticalNativeReadsV1.sol";
import {
    StreamPreservationPolicyReferenceInventoryReadsV1 as Reference
} from "./StreamPreservationPolicyReferenceInventoryReadsV1.sol";
import {
    StreamPreservationPolicyRenderCriticalRootAuthorizationV1 as Root
} from "./StreamPreservationPolicyRenderCriticalRootAuthorizationV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    IStreamScopedContentRootPublication as Aggregate
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";

library StreamPreservationPolicyRenderCriticalOriginalStagesV1 {
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
