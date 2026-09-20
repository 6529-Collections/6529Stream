// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationTokenProducerProfilesV1 as Family
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import { StreamMultiOriginNativeRoles as Roles } from "./StreamMultiOriginNativeRoles.sol";
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
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";

library StreamCurrentAuthorityPreservationPolicyRenderCriticalOriginalStagesV1 {
    function appendNative(State.State storage s, bytes32 id) public {
        State.stage(s, id, 0);
        T.Item[] memory nativeRows =
            Native.items(s.records.dependencies, s.contexts[id], Family.FAMILY_PROFILE);
        Roles.relabel(nativeRows);
        State.append(s, id, nativeRows, s.records.plans[id].sourceContextHash);
        s.records.plans[id].completedStages = 1;
    }

    function appendReference(State.State storage s, bytes32 id) public {
        State.stage(s, id, 1);
        State.append(
            s,
            id,
            Reference.items(s.records.dependencies, s.contexts[id], Family.FAMILY_PROFILE),
            s.contexts[id].referenceRender.observation.recordHash
        );
        s.records.plans[id].completedStages = 2;
    }
}
