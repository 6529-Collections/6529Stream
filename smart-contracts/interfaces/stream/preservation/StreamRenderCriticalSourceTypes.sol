// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../metadata/StreamSnapshotTypes.sol";
import "./StreamReferenceRenderTypes.sol";
import "../finality/StreamFinalityDescriptionTypes.sol";
import "../finality/StreamFinalityConservationTypes.sol";

library StreamRenderCriticalSourceTypes {
    struct Dependencies {
        // Core, Metadata, Schema, Store, Router, Snapshots, Reference, WORK, RIGHTS,
        // conservation selector, onchain ArtifactCoverage, external ArtifactCoverage.
        address[12] targets;
        bytes32[12] codeHashes;
        // Constructor-fixed original facade, Coordinator, Identity, Attribution and Archive.
        // These are not first adopted from current self-reported code during bundle admission.
        address[5] artistTargets;
        bytes32[5] artistCodeHashes;
        address artistContentOwner;
        bytes32 artistContentOwnerCodeHash;
        uint256 chainId;
        uint256 readGas;
        uint256 sourceGas;
        uint256 selectionGas;
        uint256 snapshotGas;
        uint256 referenceGas;
    }

    /// @dev Original receipt/selection facts only. Later lock state is deliberately absent.
    /// The actual current consumers still validate any observed lock's canonical shape.
    struct Context {
        uint256 collectionId;
        bytes32 subject;
        bytes32 artistId;
        StreamSnapshotTypes.Receipt snapshot;
        StreamReferenceRenderTypes.Receipt referenceRender;
        StreamFinalityDescriptionEvidence descriptions;
        IStreamConservationRecordSelection.Selection conservation;
        bytes32 interviewEvidenceHash;
        bytes32 nativeHash;
        bytes32 rootRecordHash;
        bytes32 tokenInventoryHash;
        bytes32 checkpointHash;
        uint64 tokenCount;
    }
}
