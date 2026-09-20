// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamPreservationDocumentReads as Original } from "./StreamPreservationDocumentReads.sol";
import {
    StreamScopedSnapshotDefinitions as Snapshot
} from "../records/StreamScopedSnapshotDefinitions.sol";
import {
    StreamScopedReferenceDefinitions as Reference
} from "../records/StreamScopedReferenceDefinitions.sol";
import { StreamStaticOutputSchemas as Output } from "../finality/StreamStaticOutputSchemas.sol";
import {
    StreamScopedContentRootSchemas as Root
} from "../finality/StreamScopedContentRootSchemas.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";

/// @notice Closed actual scoped definitions. Original COLLECTION profiles and renderer-class
/// declarations are not borrowed; selected renderer-specific documents are inventoried per token.
library StreamScopedRenderCriticalDefinitions {
    uint64 internal constant COUNT = 29;

    function definition(uint64 index) internal pure returns (bytes32 id, bytes32 hash) {
        if (index < 14) return (Original.fixedId(index), Original.fixedHash(index));
        if (index == 14) return (Snapshot.SCHEMA_ID, Snapshot.SCHEMA_HASH);
        if (index == 15) return (Snapshot.PROFILE_ID, Snapshot.PROFILE_HASH);
        if (index == 16) return (Reference.SCHEMA_ID, Reference.SCHEMA_HASH);
        if (index == 17) return (Reference.PROFILE_ID, Reference.PROFILE_HASH);
        if (index < 24) return (Original.fixedId(index + 2), Original.fixedHash(index + 2));
        if (index == 24) return (Snapshot.CANON_ID, Snapshot.CANON_HASH);
        if (index == 25) return (Output.SCHEMA, keccak256(Output.document(Output.SCHEMA)));
        if (index == 26) return (Output.CANON, keccak256(Output.document(Output.CANON)));
        if (index == 27) return (Root.SCHEMA, keccak256(Root.document(Root.SCHEMA)));
        if (index == 28) return (Root.CANON, keccak256(Root.document(Root.CANON)));
        revert T.InvalidInventoryItem();
    }
}
