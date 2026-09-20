// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamRenderCriticalSourceTypes as Original } from "./StreamRenderCriticalSourceTypes.sol";
import {
    StreamPolicySnapshotTypesV2 as Snapshot
} from "../metadata/StreamPolicySnapshotTypesV2.sol";
import { StreamPolicyReferenceTypesV2 as Reference } from "./StreamPolicyReferenceTypesV2.sol";

/// @notice Complete COLLECTION V2 source identity. No receipt is cast to an original profile.
library StreamPolicyRenderCriticalTypesV2 {
    bytes32 internal constant PROFILE =
        keccak256("6529STREAM_POLICY_COLLECTION_RENDER_CRITICAL_V2");

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
