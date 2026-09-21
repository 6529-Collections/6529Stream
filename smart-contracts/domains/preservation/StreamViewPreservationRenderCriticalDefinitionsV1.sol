// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamPreservationDocumentReads as Original } from "./StreamPreservationDocumentReads.sol";
import {
    StreamViewPreservationSnapshotDefinitionsV1 as Snapshot
} from "../records/StreamViewPreservationSnapshotDefinitionsV1.sol";
import {
    StreamViewPreservationReferenceDefinitionsV1 as Reference
} from "../records/StreamViewPreservationReferenceDefinitionsV1.sol";
import {
    StreamViewPreservationContentDefinitionsV1 as Root
} from "../records/StreamViewPreservationContentDefinitionsV1.sol";
import {
    StreamViewPreservationOutputSchemasV1 as Output
} from "../finality/StreamViewPreservationOutputSchemasV1.sol";
import { StreamViewPayloadV2 as Payload } from "../metadata/StreamViewPayloadV2.sol";
import {
    StreamCollectionViewFormat as Declaration
} from "../metadata/StreamCollectionViewFormat.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";

/// @notice Complete fixed VIEW interpretation vocabulary; selected renderer/admission documents follow separately.
library StreamViewPreservationRenderCriticalDefinitionsV1 {
    uint64 internal constant COUNT = 36;

    function definition(uint64 index) internal pure returns (bytes32 id, bytes32 hash) {
        if (index < 14) return (Original.fixedId(index), Original.fixedHash(index));
        if (index < 21) {
            uint64[7] memory common = [uint64(16), 17, 20, 21, 22, 23, 25];
            uint64 oldIndex = common[index - 14];
            return (Original.fixedId(oldIndex), Original.fixedHash(oldIndex));
        }
        if (index == 21) return (Snapshot.SCHEMA_ID, Snapshot.SCHEMA_HASH);
        if (index == 22) return (Snapshot.PROFILE_ID, Snapshot.PROFILE_HASH);
        if (index == 23) return (Snapshot.CANON_ID, Snapshot.CANON_HASH);
        if (index == 24) return (Reference.SCHEMA_ID, Reference.SCHEMA_HASH);
        if (index == 25) return (Reference.PROFILE_ID, Reference.PROFILE_HASH);
        if (index == 26) return (Reference.CANON_ID, Reference.CANON_HASH);
        if (index == 27) return (Root.SCHEMA_ID, Root.SCHEMA_HASH);
        if (index == 28) return (Root.CANON_ID, Root.CANON_HASH);
        if (index < 34) {
            bytes32[5] memory ids =
                [Output.PART, Output.PART_CANON, Output.INDEX, Output.INDEX_CANON, Output.LEAF];
            id = ids[index - 29];
            return (id, keccak256(Output.document(id)));
        }
        if (index == 34) return (Payload.SCHEMA_ID, Payload.schemaHash());
        if (index == 35) return (Declaration.SCHEMA_ID, Declaration.hash());
        revert T.InvalidInventoryItem();
    }
}
