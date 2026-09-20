// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationDocumentReads as Documents
} from "./StreamPreservationDocumentReads.sol";
import {
    StreamScopedPreservationPolicySnapshotDefinitionsV1 as Snapshot
} from "../records/StreamScopedPreservationPolicySnapshotDefinitionsV1.sol";
import {
    StreamScopedPreservationPolicyReferenceDefinitionsV1 as Reference
} from "../records/StreamScopedPreservationPolicyReferenceDefinitionsV1.sol";
import {
    StreamPreservationPolicyOutputSchemasV1 as Output
} from "../finality/StreamPreservationPolicyOutputSchemasV1.sol";
import {
    StreamScopedPreservationPolicyContentRootSchemasV1 as Root
} from "../finality/StreamScopedPreservationPolicyContentRootSchemasV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";

/// @notice Exact shared record definitions plus distinct scoped-policy snapshot/reference/output/root documents.
library StreamScopedPreservationPolicyRenderCriticalDefinitionsV1 {
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
}
