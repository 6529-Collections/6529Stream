// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyRootFamiliesV2 as Roots
} from "../finality/StreamPreservationPolicyRootFamiliesV2.sol";
import {
    StreamPreservationPolicyReferenceDefinitionsV2 as ReferenceV2
} from "../records/StreamPreservationPolicyReferenceDefinitionsV2.sol";
import {
    StreamPreservationPolicySnapshotDefinitionsV2 as SnapshotV2
} from "../records/StreamPreservationPolicySnapshotDefinitionsV2.sol";
import {
    StreamPreservationPolicyInventoryFamilyV2 as FamilyRead
} from "./StreamPreservationPolicyInventoryFamilyV2.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Family
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
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

    function definition(uint64 i, bytes32 family) public pure returns (bytes32 id, bytes32 hash) {
        if (family == Family.ORIGINAL_PROFILE) return definition(i);
        if (family != Family.FAMILY_PROFILE) revert T.InvalidInventoryItem();
        if (i < 14) return (Documents.fixedId(i), Documents.fixedHash(i));
        if (i < 20) return (Documents.fixedId(i + 6), Documents.fixedHash(i + 6));
        if (i == 20) return (SnapshotV2.SCHEMA_ID, SnapshotV2.SCHEMA_HASH);
        if (i == 21) return (SnapshotV2.PROFILE_ID, SnapshotV2.PROFILE_HASH);
        if (i == 22) return (SnapshotV2.CANON_ID, SnapshotV2.CANON_HASH);
        if (i == 23) return (ReferenceV2.SCHEMA_ID, ReferenceV2.SCHEMA_HASH);
        if (i == 24) return (ReferenceV2.PROFILE_ID, ReferenceV2.PROFILE_HASH);
        if (i == 25) return (ReferenceV2.CANON_ID, ReferenceV2.CANON_HASH);
        if (i >= COUNT) revert T.InvalidInventoryItem();
        bytes32[5] memory ids = Roots.ids(family, false);
        id = ids[i - 26];
        hash = Roots.definitionHash(family, false, id);
    }

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
        appendDefinition(s, id, Family.ORIGINAL_PROFILE);
    }

    function appendDefinition(State.State storage s, bytes32 id, bytes32 family) public {
        State.stage(s, id, 7);
        uint64 i = s.records.definitionCursor[id];
        if (
            family == Family.FAMILY_PROFILE
                && (s.contexts[id].source.content.preservationProfile != family
                    || s.contexts[id].source.outputs.preservationProfile != family)
        ) revert T.InventorySourceChanged();
        (bytes32 document, bytes32 hash) = definition(i, family);
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
