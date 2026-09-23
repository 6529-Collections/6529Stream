// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamRenderCriticalSourceTypes as Original } from "./StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationPolicySnapshotTypesV1 as Snapshot
} from "../metadata/StreamPreservationPolicySnapshotTypesV1.sol";
import {
    StreamPreservationPolicyReferenceTypesV1 as Reference
} from "./StreamPreservationPolicyReferenceTypesV1.sol";

/// @notice Complete COLLECTION preservation source identity. No receipt is cast to an original profile.
library StreamPreservationPolicyRenderCriticalTypesV1 {
    bytes32 internal constant PROFILE =
        keccak256("6529STREAM_PRESERVATION_POLICY_COLLECTION_RENDER_CRITICAL_V1");

    struct Context {
        // Only common description/conservation/subject fields are populated. Both original
        // receipt fields stay literal zero. This projection is private stage transport.
        Original.Context records;
        Snapshot.Receipt snapshot;
        Reference.Receipt referenceRender;
        Snapshot.Source source;
        bytes32 referenceSourceHash;
    }
}
