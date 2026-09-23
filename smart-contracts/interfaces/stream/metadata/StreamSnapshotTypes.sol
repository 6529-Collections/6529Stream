// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamMetadataServingFacts.sol";
import "./IStreamContentRootPublication.sol";
import "../finality/IStreamContentLeafManifest.sol";
import "../finality/IStreamOnchainContentCheckpoint.sol";

/// @notice Exact native snapshot source facts; publication and current selection are separate.
library StreamSnapshotTypes {
    struct Dependencies {
        // Core, Metadata, schemas, Store, Router, leaf manifest, checkpoint, membership,
        // original-coordinator inventory. All are fixed at host construction.
        address[9] targets;
        bytes32[9] codeHashes;
        uint256 chainId;
        uint256 readGas;
        uint256 sourceGas;
        uint256 evidenceGas;
        uint256 inventoryGas;
    }

    struct NativeFacts {
        uint256 collectionId;
        bytes32 subject;
        bytes32 presentationProfile;
        bytes32 rendererContext;
        bytes32 dependencyProfile;
        bytes32 routerVersion;
        bytes32 routerManifestHash;
        IStreamMetadataServingFacts.ServingSource source;
        // coreFrozen is canonical false here: Core configuration freeze is subsequent,
        // independent state and never part of this snapshot's artwork content commitment.
        IStreamMetadataServingFacts.ServingFacts serving;
        IStreamMetadataServingFacts.ArtistPresentation artist;
        bytes32 contentRootRecordHash;
        IStreamContentRootPublication.Record contentRoot;
        IStreamContentLeafManifest.Manifest leafManifest;
        IStreamOnchainContentCheckpoint.Plan checkpoint;
    }

    struct Publication {
        uint256 collectionId;
        bytes32 snapshotId;
        bytes32 expectedHead;
        uint64 expectedRevision;
        bytes32 expectedSourceHash;
        bytes32 inventoryPlan;
        string manifestURI;
        uint64 effectiveAt;
        bytes32 reasonHash;
    }

    struct Receipt {
        bytes32 recordHash;
        uint256 collectionId;
        bytes32 snapshotId;
        bytes32 predecessor;
        uint64 revision;
        bytes32 recordChainHash;
        bytes32 manifestHash;
        uint32 manifestBytes;
        bytes32 sourceHash;
        bytes32 inventoryPlan;
        address publisher;
        uint8 authorizationClass;
        uint64 grantRevision;
        uint8 displayAuthorizationClass;
        uint64 displayGrantRevision;
        uint64 effectiveAt;
        uint64 recordedAt;
        bytes32 reasonHash;
        bytes32 schemaDefinitionHash;
        bytes32 profileDefinitionHash;
        bytes32 canonicalizationDefinitionHash;
    }

    struct Lock {
        bytes32 recordHash;
        uint64 revision;
        bytes32 actionId;
        uint64 lockedAt;
    }

    error SnapshotConfiguration();
    error SnapshotDependency(address target);
    error SnapshotRead(address target, bytes4 selector);
    error SnapshotSource();
    error SnapshotAuthority(address actor);
    error SnapshotLineage(bytes32 expected, bytes32 actual);
    error SnapshotUnknown(bytes32 id);
    error SnapshotLocked(bytes32 lockId);
    error SnapshotDefinition(bytes32 id);
}
