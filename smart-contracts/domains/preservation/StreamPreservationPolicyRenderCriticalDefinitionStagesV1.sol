// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyRenderCriticalStateV1 as State
} from "./StreamPreservationPolicyRenderCriticalStateV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamPreservationDocumentReads as Documents
} from "./StreamPreservationDocumentReads.sol";
import {
    StreamPreservationPolicySnapshotDefinitionsV1 as Snapshot
} from "../records/StreamPreservationPolicySnapshotDefinitionsV1.sol";
import {
    StreamPreservationPolicyReferenceDefinitionsV1 as Reference
} from "../records/StreamPreservationPolicyReferenceDefinitionsV1.sol";
import {
    StreamPreservationPolicyOutputSchemasV1 as Output
} from "../finality/StreamPreservationPolicyOutputSchemasV1.sol";
import {
    StreamPreservationPolicyContentRootSchemasV1 as Root
} from "../finality/StreamPreservationPolicyContentRootSchemasV1.sol";

library StreamPreservationPolicyRenderCriticalDefinitionStagesV1 {
    uint64 internal constant COUNT = 31;

    function definition(uint64 i) public pure returns (bytes32 id, bytes32 hash) {
        // Original common record and environment definitions, never V1 snapshot/reference/root.
        if (i < 14) return (Documents.fixedId(i), Documents.fixedHash(i));
        if (i < 20) return (Documents.fixedId(i + 6), Documents.fixedHash(i + 6));
        if (i == 20) return (Snapshot.SCHEMA_ID, Snapshot.SCHEMA_HASH);
        if (i == 21) return (Snapshot.PROFILE_ID, Snapshot.PROFILE_HASH);
        if (i == 22) return (Snapshot.CANON_ID, Snapshot.CANON_HASH);
        if (i == 23) return (Reference.SCHEMA_ID, Reference.SCHEMA_HASH);
        if (i == 24) return (Reference.PROFILE_ID, Reference.PROFILE_HASH);
        if (i == 25) return (Reference.CANON_ID, Reference.CANON_HASH);
        if (i == 26) id = Output.SCHEMA;
        else if (i == 27) id = Output.CANON;
        else if (i == 28) id = Output.LEAF_SCHEMA;
        else if (i == 29) id = Root.ROOT_SCHEMA;
        else if (i == 30) id = Root.ROOT_CANON;
        else revert T.InvalidInventoryItem();
        hash = Root.definitionHash(id);
    }

    function appendDefinition(State.State storage s, bytes32 id) public {
        State.stage(s, id, 7);
        uint64 i = s.records.definitionCursor[id];
        (bytes32 document, bytes32 hash) = definition(i);
        T.Item[] memory rows = new T.Item[](1);
        rows[0] = Documents.item(s.records.dependencies, document, hash);
        State.append(s, id, rows, keccak256(abi.encode(document, rows[0])));
        s.records.definitionCursor[id] = i + 1;
        if (i + 1 == COUNT) s.records.plans[id].completedStages = 8;
    }

    function requireDefinitions(State.State storage s, bytes32 id, bool full) public view {
        if (s.records.definitionCursor[id] != COUNT) revert T.InventoryIncomplete();
        State.requireDocuments(s, id, full);
    }
}
