// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyRenderCriticalStateV1 as State
} from "./StreamPreservationPolicyRenderCriticalStateV1.sol";
import {
    StreamPreservationPolicyRenderCriticalSourceReadsV1 as Sources
} from "./StreamPreservationPolicyRenderCriticalSourceReadsV1.sol";
import {
    StreamPreservationPolicyRenderCriticalTypesV1 as C
} from "../../interfaces/stream/preservation/StreamPreservationPolicyRenderCriticalTypesV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";

library StreamPreservationPolicyRenderCriticalStartV1 {
    event InventoryStarted(
        bytes32 indexed planId, uint256 indexed collectionId, bytes32 sourceContextHash
    );

    function begin(State.State storage s, uint256 collectionId) public returns (bytes32 id) {
        C.Context memory c = Sources.current(s.records.dependencies, collectionId);
        id = State.planId(s, c);
        if (s.records.plans[id].collectionId != 0) return id;
        s.contexts[id] = c;
        s.records.contexts[id] = c.records;
        T.Plan storage p = s.records.plans[id];
        p.collectionId = collectionId;
        p.subject = c.records.subject;
        p.artistId = c.records.artistId;
        p.sourceContextHash = keccak256(abi.encode(c));
        p.tokenCount = c.records.tokenCount;
        emit InventoryStarted(id, collectionId, p.sourceContextHash);
    }
}
