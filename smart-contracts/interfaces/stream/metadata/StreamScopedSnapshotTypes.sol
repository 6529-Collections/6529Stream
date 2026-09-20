// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../finality/StreamArtworkFinalityTypes.sol";
import "../finality/StreamScopeMembershipTypes.sol";
import "../finality/IStreamStaticSelectionCheckpoint.sol";
import "../finality/IStreamStaticContentCheckpoint.sol";
import "../finality/IStreamStaticOutputManifest.sol";
import "../finality/StreamFinalityCoordinatorPolicyTypes.sol";
import "./IStreamMetadataServingFacts.sol";

/// @notice Additive scoped STATIC snapshot vocabulary. Original COLLECTION snapshot bytes are unchanged.
library StreamScopedSnapshotTypes {
    struct Dependencies {
        // Core, Metadata, schemas, Store, Router, authoritative scope membership, STATIC selection,
        // STATIC content checkpoint, covered output manifest, artifact coverage, coordinator inventory.
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
        IStreamStaticContentCheckpoint.Plan content;
        IStreamStaticOutputManifest.Manifest outputs;
        StreamFinalityCoordinatorPolicyEvidence entropy;
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

    error InvalidScopedSnapshot();
    error ScopedSnapshotDependency(address target);
    error ScopedSnapshotAuthority(address actor);
    error ScopedSnapshotLineage(bytes32 expected, bytes32 actual);
    error ScopedSnapshotLocked(bytes32 subject);
    error ScopedSnapshotUnknown(bytes32 recordHash);
}
