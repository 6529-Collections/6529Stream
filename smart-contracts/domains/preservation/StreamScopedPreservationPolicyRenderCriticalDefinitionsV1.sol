// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyRootFamiliesV2 as Roots
} from "../finality/StreamPreservationPolicyRootFamiliesV2.sol";
import {
    StreamScopedPreservationPolicyReferenceDefinitionsV2 as ReferenceV2
} from "../records/StreamScopedPreservationPolicyReferenceDefinitionsV2.sol";
import {
    StreamScopedPreservationPolicySnapshotDefinitionsV2 as SnapshotV2
} from "../records/StreamScopedPreservationPolicySnapshotDefinitionsV2.sol";
import {
    StreamPreservationPolicyInventoryFamilyV2 as FamilyRead
} from "./StreamPreservationPolicyInventoryFamilyV2.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Family
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
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
        bytes32[5] memory ids = Roots.ids(family, true);
        id = ids[i - 26];
        hash = Roots.definitionHash(family, true, id);
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
}
