// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../finality/StreamArtworkFinalityTypes.sol";
import "../finality/StreamScopeMembershipTypes.sol";
import {
    StreamViewPreservationCheckpointTypesV1 as C
} from "../finality/StreamViewPreservationCheckpointTypesV1.sol";
import {
    StreamViewPreservationManifestTypesV1 as M
} from "../finality/StreamViewPreservationManifestTypesV1.sol";
import "../finality/StreamFinalityCoordinatorPolicyTypesV2.sol";
import "./IStreamMetadataServingFacts.sol";

/// @notice Root-free VIEW preservation snapshot; no CONTENT_ROOT, reference, sanction or finality assertion.
library StreamViewPreservationSnapshotTypesV1 {
    struct Dependencies {
        // Core, selected Metadata, Schema, Store, Router, ScopeMembership,
        // preservation checkpoint, covered manifest, ArtifactCoverage, original authority.
        address[10] targets;
        bytes32[10] codeHashes;
        uint256 chainId;
        uint256 readGas;
        uint256 sourceGas;
        uint256 inventoryGas;
    }

    struct Publication {
        StreamFinalityScope scope;
        bytes32 snapshotId;
        bytes32 expectedHead;
        uint64 expectedRevision;
        bytes32 outputManifestRecord;
        bytes32 expectedAdoptionRecord;
        bytes32 expectedSourceHash;
        string manifestURI;
        uint64 effectiveAt;
        bytes32 reasonHash;
    }

    struct Source {
        StreamFinalityScope scope;
        StreamScopeMembershipFacts membership;
        IStreamMetadataServingFacts.ArtistPresentation artist;
        C.Source adoption;
        C.Plan checkpoint;
        M.Plan outputs;
        StreamFinalityCoordinatorPolicyEvidenceV2 entropy;
    }

    struct Receipt {
        bytes32 recordHash;
        bytes32 scopeSubject;
        bytes32 predecessor;
        uint64 revision;
        bytes32 chainHash;
        bytes32 manifestHash;
        uint32 manifestBytes;
        bytes32 sourceHash;
        address publisher;
        uint8 authorizationClass;
        uint64 grantRevision;
        uint8 displayAuthorizationClass;
        uint64 displayGrantRevision;
        uint64 recordedAt;
        bytes32 schemaHash;
        bytes32 profileHash;
        bytes32 canonicalizationHash;
    }

    struct Lock {
        bytes32 recordHash;
        uint64 revision;
        bytes32 actionId;
        uint64 lockedAt;
    }

    error InvalidViewPreservationSnapshot();
    error ViewPreservationSnapshotDependency(address target);
    error ViewPreservationSnapshotAuthority(address actor);
    error ViewPreservationSnapshotLineage(bytes32 expected, bytes32 actual);
    error ViewPreservationSnapshotLocked(bytes32 subject);
    error ViewPreservationSnapshotUnknown(bytes32 recordHash);
}
