// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamScopedRenderCriticalState as State } from "./StreamScopedRenderCriticalState.sol";
import {
    StreamScopedRenderCriticalDefinitions as Definitions
} from "./StreamScopedRenderCriticalDefinitions.sol";
import {
    StreamPreservationDocumentReads as Documents
} from "./StreamPreservationDocumentReads.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";

library StreamScopedRenderCriticalDefinitionStages {
    function appendDefinition(State.State storage state, bytes32 id) public {
        State.stage(state, id, 7);
        uint64 index = state.definitionCursor[id];
        (bytes32 documentId, bytes32 expectedHash) = Definitions.definition(index);
        T.Item[] memory rows = new T.Item[](1);
        rows[0] = Documents.item(state.dependencies, documentId, expectedHash);
        state.documents[id].push(State.DocumentPin(documentId, rows[0].provenanceHash));
        State.append(state, id, rows, keccak256(abi.encode(documentId, rows[0])));
        state.definitionCursor[id] = index + 1;
        if (index + 1 == Definitions.COUNT) state.plans[id].progress.completedStages = 8;
    }

    function requireDefinitions(State.State storage state, bytes32 id, bool full) public view {
        if (state.documents[id].length != Definitions.COUNT) revert T.InventoryIncomplete();
        for (uint64 i; i < Definitions.COUNT; ++i) {
            State.DocumentPin storage pin = state.documents[id][i];
            (bytes32 documentId, bytes32 expectedHash) = Definitions.definition(i);
            if (pin.id != documentId) revert T.InventorySourceChanged();
            bytes32 actual = full
                ? Documents.item(state.dependencies, documentId, expectedHash).provenanceHash
                : Documents.currentFactsHash(state.dependencies, documentId);
            if (actual != pin.factsHash) revert T.InventorySourceChanged();
        }
    }
}
