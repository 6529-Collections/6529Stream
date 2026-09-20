// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../finality/StreamArtworkFinalityTypes.sol";
import "../finality/StreamScopeMembershipTypes.sol";
import "../finality/IStreamStaticSelectionCheckpoint.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1
} from "../finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    IStreamPreservationPolicyOutputManifestV1
} from "../finality/IStreamPreservationPolicyOutputManifestV1.sol";
import "../finality/StreamFinalityCoordinatorPolicyTypesV2.sol";
import "./IStreamMetadataServingFacts.sol";

/// @notice Distinct admitted preservation-policy TOKEN/RELEASE/SEASON snapshot vocabulary. Original profiles are unchanged.
library StreamScopedPreservationPolicySnapshotTypesV1 {
    struct Dependencies {
        // Core, Metadata, schemas, Store, Router, authoritative scope membership, STATIC selection,
        // scoped-policy content checkpoint, covered scoped-policy output manifest, artifact coverage, policy source set.
        address[11] targets;
        bytes32[11] codeHashes;
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
        bytes32 coordinatorInventoryPlan;
        bytes32 expectedSourceHash;
        string manifestURI;
        uint64 effectiveAt;
        bytes32 reasonHash;
    }

    struct Source {
        StreamFinalityScope scope;
        StreamScopeMembershipFacts membership;
        IStreamMetadataServingFacts.ArtistPresentation artist;
        IStreamStaticSelectionCheckpoint.Plan selection;
        IStreamPreservationPolicyContentCheckpointV1.Plan content;
        IStreamPreservationPolicyOutputManifestV1.Manifest outputs;
        address sourceFactory;
        bytes32 sourceFactoryCodeHash;
        bytes32 factoryDependenciesHash;
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

    error InvalidScopedPolicySnapshot();
    error ScopedPolicySnapshotDependency(address target);
    error ScopedPolicySnapshotAuthority(address actor);
    error ScopedPolicySnapshotLineage(bytes32 expected, bytes32 actual);
    error ScopedPolicySnapshotLocked(bytes32 subject);
    error ScopedPolicySnapshotUnknown(bytes32 recordHash);
}
