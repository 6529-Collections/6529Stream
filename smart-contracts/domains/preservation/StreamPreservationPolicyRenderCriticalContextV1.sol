// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyRenderCriticalStateV1 as State
} from "./StreamPreservationPolicyRenderCriticalStateV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";

library StreamPreservationPolicyRenderCriticalContextV1 {
    function encoded(State.State storage s, bytes32 id) public view returns (bytes memory) {
        if (s.records.plans[id].collectionId == 0) revert T.InventoryIncomplete();
        return abi.encode(s.contexts[id]);
    }
}
