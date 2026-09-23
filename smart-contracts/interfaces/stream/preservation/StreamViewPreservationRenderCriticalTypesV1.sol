// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationInventoryTypes as Inventory
} from "./StreamPreservationInventoryTypes.sol";
import { StreamFinalityScope } from "../finality/StreamArtworkFinalityTypes.sol";
import {
    StreamViewPreservationSnapshotTypesV1 as Snapshot
} from "../metadata/StreamViewPreservationSnapshotTypesV1.sol";
import {
    StreamViewPreservationReferenceTypesV1 as Reference
} from "./StreamViewPreservationReferenceTypesV1.sol";
import { StreamFinalityDescriptionEvidence } from "../finality/StreamFinalityDescriptionTypes.sol";
import {
    IStreamConservationRecordSelection
} from "../metadata/IStreamConservationRecordSelection.sol";

/// @notice Complete adopted VIEW preservation inventory under an explicit separate profile.
/// @dev Actual VIEW receipts never inhabit the original COLLECTION or scoped-V1 receipt types.
library StreamViewPreservationRenderCriticalTypesV1 {
    bytes32 internal constant PROFILE =
        keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_RETRIEVAL_V1");

    struct Plan {
        StreamFinalityScope scope;
        Inventory.Plan progress;
        uint64 nativeCursor;
        uint64 nativeCount;
        uint64 referenceCursor;
        uint64 referenceCount;
    }

    struct TokenProgress {
        uint8 phase;
        uint64 row;
        uint64 count;
    }

    struct Evidence {
        StreamFinalityScope scope;
        Inventory.Evidence inventory;
    }

    struct BundleEvidence {
        StreamFinalityScope scope;
        Inventory.BundleEvidence coverage;
    }

    struct Context {
        StreamFinalityScope scope;
        bytes32 subject;
        bytes32 artistId;
        Snapshot.Receipt snapshot;
        Reference.Receipt referenceRender;
        StreamFinalityDescriptionEvidence descriptions;
        IStreamConservationRecordSelection.Selection conservation;
        bytes32 interviewEvidenceHash;
        bytes32 nativeHash;
        bytes32 rootRecordHash;
        bytes32 tokenInventoryHash;
        bytes32 checkpointHash;
        bytes32 outputManifestRecord;
        bytes32 adoptionRecord;
        bytes32 viewId;
        bytes32 payloadHash;
        bytes32 sourceContextHash;
        bytes32 policyChainHash;
        bytes32 outputRoot;
        bytes32 manifestIndexHash;
        uint64 tokenCount;
    }
}
