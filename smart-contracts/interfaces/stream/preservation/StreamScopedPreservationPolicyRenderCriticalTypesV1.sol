// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationInventoryTypes as Inventory
} from "./StreamPreservationInventoryTypes.sol";
import { StreamFinalityScope } from "../finality/StreamArtworkFinalityTypes.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as Snapshot
} from "../metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    StreamScopedPreservationPolicyReferenceTypesV1 as Reference
} from "./StreamScopedPreservationPolicyReferenceTypesV1.sol";
import { StreamFinalityDescriptionEvidence } from "../finality/StreamFinalityDescriptionTypes.sol";
import {
    IStreamConservationRecordSelection
} from "../metadata/IStreamConservationRecordSelection.sol";

/// @notice Separate full-scope context for the scoped native inventory profile.
/// @dev No COLLECTION receipt/root can fill a scoped receipt field. Samples are not membership.
library StreamScopedPreservationPolicyRenderCriticalTypesV1 {
    bytes32 internal constant PROFILE =
        keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_RENDER_CRITICAL_V1");

    struct Plan {
        StreamFinalityScope scope;
        Inventory.Plan progress;
        uint64 nativeCursor;
        uint64 nativeCount;
        uint64 referenceCursor;
        uint64 referenceCount;
    }

    /// @dev A token advances only after all six fixed source families finish.
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
        Snapshot.Source snapshotSource;
        Reference.Receipt referenceRender;
        StreamFinalityDescriptionEvidence descriptions;
        IStreamConservationRecordSelection.Selection conservation;
        bytes32 interviewEvidenceHash;
        bytes32 nativeHash;
        bytes32 rootRecordHash;
        bytes32 tokenInventoryHash;
        bytes32 checkpointHash;
        bytes32 outputManifestRecord;
        bytes32 selectionId;
        bytes32 selectionHash;
        uint64 tokenCount;
    }
}
