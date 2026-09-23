// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamCurrentAuthorityInventoryLifecycle as Lifecycle } from "./StreamCurrentAuthorityInventoryLifecycle.sol";

import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../../interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    IStreamCurrentAuthorityInventory
} from "../../interfaces/stream/preservation/IStreamCurrentAuthorityInventory.sol";
import {
    StreamCurrentAuthorityInventorySelection as Authority
} from "./StreamCurrentAuthorityInventorySelection.sol";

import { StreamMultiOriginNativeRoles as Roles } from "./StreamMultiOriginNativeRoles.sol";

import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";
import {
    StreamPreservationInventoryChains as Chains
} from "./StreamPreservationInventoryChains.sol";
import {
    StreamPreservationTypedReferences as References
} from "./StreamPreservationTypedReferences.sol";
import {
    StreamPreservationDocumentReads as Documents
} from "./StreamPreservationDocumentReads.sol";
import {
    StreamPreservationOriginalReads as Originals
} from "./StreamPreservationOriginalReads.sol";
import {
    StreamPreservationArtistBundleReads as ArtistBundles
} from "./StreamPreservationArtistBundleReads.sol";
import { StreamRenderCriticalSourceReads as Sources } from "./StreamRenderCriticalSourceReads.sol";
import { StreamReferenceInventoryReads as Reference } from "./StreamReferenceInventoryReads.sol";
import "../../interfaces/stream/preservation/IStreamRenderCriticalInventory.sol";
import "../../interfaces/stream/metadata/IStreamWorkRecordSelection.sol";
import "../../interfaces/stream/metadata/StreamRightsRecordTypes.sol";
import "../../interfaces/stream/metadata/IStreamConservationRecordSelection.sol";
import "../../interfaces/stream/finality/IStreamOnchainContentCheckpoint.sol";
import "../../interfaces/stream/preservation/IStreamReferenceRenderPublication.sol";

import {
    StreamRenderCriticalInventoryState as State
} from "./StreamRenderCriticalInventoryState.sol";
import "./StreamRenderCriticalDescriptionStages.sol";
import "./StreamRenderCriticalInterviewStage.sol";
import "./StreamRenderCriticalDefinitionStages.sol";
import "./StreamRenderCriticalTokenReads.sol";
import "./StreamRenderCriticalRecordStages.sol";

import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    IStreamArtistArchiveOriginInventory
} from "../../interfaces/stream/preservation/IStreamArtistArchiveOriginInventory.sol";
import { StreamMultiOriginInventoryState as Origins } from "./StreamMultiOriginInventoryState.sol";
import {
    StreamMultiOriginInventoryCalls as OriginCalls
} from "./StreamMultiOriginInventoryCalls.sol";
import { StreamMultiOriginSourceReads as OriginSources } from "./StreamMultiOriginSourceReads.sol";
import {
    StreamCurrentAuthorityInventoryGuard as Guard
} from "./StreamCurrentAuthorityInventoryGuard.sol";
import "./StreamMultiOriginDescriptionStages.sol";
import "./StreamMultiOriginRecordStages.sol";
import "./StreamMultiOriginInterviewStage.sol";

/// @notice Deterministic complete inventory of the supported native eight-input profile.
/// @dev Permissionless materialization confers no publication or signing authority. Every
/// source already has an authenticated original. No finality provider, final manifest or
/// sanction record enters this dependency graph or the independent evidence preimage.
contract StreamCurrentAuthorityRenderCriticalInventory is
    IStreamRenderCriticalInventory,
    IStreamArtistArchiveOriginInventory,
    IStreamCurrentAuthorityInventory
{
    // Constructor-only storage is intentional: late Artist/Coordinator pins do not enter
    // runtime code, avoiding a circular Registry/provider/Coordinator runtime hash graph.
    mapping(bytes32 => State.State) private _states;
    mapping(bytes32 => Authority.State) private _authorities;
    Authority.Config private _config;
    bytes32 private _dependencyHash;
    Origins.State private _origins;

    event InventoryStarted(
        bytes32 indexed planId, uint256 indexed collectionId, bytes32 sourceContextHash
    );
    event InventorySegmentRecorded(
        bytes32 indexed planId, uint64 indexed index, T.Segment segment, T.Item[] items
    );
    event InventoryCompleted(
        bytes32 indexed planId, bytes32 indexed renderCriticalEvidenceHash, T.Evidence evidence
    );

    constructor(S.Dependencies memory d, O.Dependencies memory od, D.Dependencies memory ad) {
        if (
            d.chainId != block.chainid || d.readGas < 50000 || d.sourceGas < d.readGas
                || d.selectionGas < d.readGas || d.snapshotGas < d.readGas
                || d.referenceGas < d.readGas
        ) revert T.InventorySourceChanged();
        for (uint256 i; i < 12; ++i) {
            if (d.targets[i] == address(0) || d.codeHashes[i] == 0) {
                revert T.InventorySourceChanged();
            }
        }
        for (uint256 i; i < 5; ++i) {
            if (d.artistTargets[i] == address(0) || d.artistCodeHashes[i] == 0) {
                revert T.InventorySourceChanged();
            }
        }
        if (d.artistContentOwner == address(0) || d.artistContentOwnerCodeHash == 0) {
            revert T.InventorySourceChanged();
        }
        _config = Authority.Config(d, ad);
        Authority.validate(_config);
        OriginCalls.pin(od);
        _origins.dependencies = od;
        _dependencyHash = D.dependencyHash(D.INVENTORY_PROFILE, d, od, ad);
    }

    function dependencyHash() external view returns (bytes32) {
        return _dependencyHash;
    }

    function core() external view override returns (address) {
        return _config.originalAnchor.targets[0];
    }

    function metadataHost() external view override returns (address) {
        return _config.originalAnchor.targets[1];
    }

    function metadataRouter() external view override returns (address) {
        return _config.originalAnchor.targets[4];
    }

    function snapshots() external view override returns (address) {
        return _config.originalAnchor.targets[5];
    }

    function referencePublisher() external view override returns (address) {
        return _config.originalAnchor.targets[6];
    }

    function artifactCoverage() external view override returns (address) {
        return _config.originalAnchor.targets[10];
    }

    function externalCoverage() external view override returns (address) {
        return _config.originalAnchor.targets[11];
    }

    function deploymentChainId() external view override returns (uint256) {
        return _config.originalAnchor.chainId;
    }

    function coreCodeHash() external view override returns (bytes32) {
        return _config.originalAnchor.codeHashes[0];
    }

    function metadataCodeHash() external view override returns (bytes32) {
        return _config.originalAnchor.codeHashes[1];
    }

    function dependencies() external view returns (S.Dependencies memory) {
        return _config.originalAnchor;
    }

    function originDependencies() external view returns (O.Dependencies memory) {
        return _origins.dependencies;
    }

    function originProfile() external pure returns (bytes32) {
        return D.INVENTORY_PROFILE;
    }

    function originCount(bytes32 id) external view returns (uint256) {
        return _origins.origins[id].length;
    }

    function originAt(bytes32 id, uint256 index) external view returns (O.Origin memory) {
        if (index >= _origins.origins[id].length) revert O.InvalidArchiveOrigin();
        return _origins.origins[id][index];
    }

    function originSetHash(bytes32 id) external view returns (bytes32) {
        return _origins.sealedRoot[id];
    }

    function artistArchiveOrigin(bytes32 id, bytes32 itemHash)
        external
        view
        returns (O.RecordOrigin memory original)
    {
        original = _origins.records[id][itemHash];
        if (original.sourceContextHash == 0) revert O.InvalidArchiveOrigin();
    }

    function originRuntimeCursor(bytes32 id) external view returns (uint256) {
        return _origins.runtimeCursor[id];
    }

    function appendOriginRuntime(bytes32 id) external {
        _stage(id, 8);
        if (_states[id].plans[id].nextToken != _states[id].plans[id].tokenCount) {
            revert T.InventoryIncomplete();
        }
        (T.Item[] memory rows, bytes32 witness) = Origins.runtimeItems(_origins, id);
        _append(id, rows, witness);
    }

    function beginInventory(uint256 collectionId) external returns (bytes32 id) {
        return Lifecycle.beginInventory(_states, _origins, _authorities, _config, _dependencyHash, collectionId);
    }

    function appendNative(bytes32 id) external {
        _stage(id, 0);
        T.Item[] memory nativeRows =
            Sources.nativeItems(_states[id].dependencies, _states[id].contexts[id]);
        Roles.relabel(nativeRows);
        _append(id, nativeRows, _states[id].plans[id].sourceContextHash);
        _states[id].plans[id].completedStages = 1;
    }

    function appendReference(bytes32 id) external {
        _stage(id, 1);
        Reference.appendReference(_states[id], id);
        _states[id].plans[id].completedStages = 2;
    }

    function appendWork(
        bytes32 id,
        StreamWorkRecordTypes.Description calldata,
        address,
        O.ReceiptWitness calldata
    ) external {
        _stage(id, 2);
        StreamMultiOriginDescriptionStages.appendWork(_states[id], _origins, msg.data);
    }

    function appendRights(bytes32 id, StreamRightsRecordTypes.Statement calldata) external {
        _stage(id, 3);
        StreamRenderCriticalDescriptionStages.appendRights(_states[id], msg.data);
    }

    function appendIntent(
        bytes32 id,
        StreamConservationRecordTypes.Intent calldata,
        address,
        O.ReceiptWitness calldata
    ) external {
        _stage(id, 4);
        StreamMultiOriginRecordStages.appendIntent(_states[id], _origins, msg.data);
    }

    function appendIntentWaiver(
        bytes32 id,
        StreamConservationRecordTypes.IntentWaiver calldata,
        address,
        O.ReceiptWitness calldata
    ) external {
        _stage(id, 4);
        StreamMultiOriginRecordStages.appendIntentWaiver(_states[id], _origins, msg.data);
    }

    function appendInterview(
        bytes32 id,
        StreamConservationRecordTypes.Interview calldata,
        address,
        O.ReceiptWitness calldata
    ) external {
        _stage(id, 5);
        StreamMultiOriginInterviewStage.appendInterview(_states[id], _origins, msg.data);
    }

    function appendInterviewWaiver(bytes32 id) external {
        _stage(id, 5);
        StreamRenderCriticalInterviewStage.appendInterviewWaiver(_states[id], id);
    }

    function appendRootAuthorization(
        bytes32 id,
        address originalActor,
        uint64 originalObservedAt,
        O.ReceiptWitness calldata receipt
    ) external {
        _stage(id, 6);
        T.Item[] memory rows = new T.Item[](1);
        O.RecordOrigin memory original;
        (rows[0], original) = OriginCalls.content(
            _states[id].dependencies,
            _origins.dependencies,
            _states[id].contexts[id],
            originalActor,
            originalObservedAt,
            _states[id].plans[id].sourceContextHash,
            receipt
        );
        Origins.remember(
            _origins,
            id,
            _states[id].plans[id].sourceContextHash,
            rows[0],
            original,
            bytes32(0),
            originalActor,
            keccak256("ORIGINAL_CONTENT_ROOT_AUTHORIZATION")
        );
        _append(id, rows, _states[id].contexts[id].rootRecordHash);
        _states[id].plans[id].completedStages = 7;
    }

    function appendDefinition(bytes32 id) external {
        _stage(id, 7);
        StreamRenderCriticalDefinitionStages.appendDefinition(_states[id], id);
    }

    function appendToken(bytes32 id, IStreamOnchainContentCheckpoint.TokenPayload calldata payload)
        external
    {
        _stage(id, 8);
        T.Plan storage p = _states[id].plans[id];
        uint64 index = p.nextToken;
        _append(
            id,
            StreamRenderCriticalTokenReads.tokenItems(
                _states[id].dependencies, _states[id].contexts[id], index, payload
            ),
            keccak256(abi.encode(_states[id].contexts[id].checkpointHash, index))
        );
        p.nextToken = index + 1;
    }

    function sealInventory(bytes32 id) external returns (T.Evidence memory evidence) {
        return Lifecycle.sealInventory(_states, _origins, _authorities, id);
    }

    function inventoryEvidence(bytes32 id)
        external
        view
        override
        returns (T.Evidence memory result)
    {
        result = _states[id].completed[id];
        if (result.renderCriticalEvidenceHash == 0) revert T.InventoryIncomplete();
    }

    function inventorySegment(bytes32 id, uint64 index)
        external
        view
        override
        returns (T.Segment memory)
    {
        if (index >= _states[id].plans[id].segmentCount) {
            revert T.InvalidInventorySegment();
        }
        return _states[id].segments[id][index];
    }

    function plan(bytes32 id) external view returns (T.Plan memory) {
        return _states[id].plans[id];
    }

    function sourceContext(bytes32 id) external view returns (S.Context memory) {
        if (_states[id].plans[id].collectionId == 0) revert T.InventoryIncomplete();
        return _states[id].contexts[id];
    }

    function requireCurrent(uint256 collectionId)
        external
        view
        override
        returns (T.Evidence memory result)
    {
        return Lifecycle.requireCurrent(_states, _origins, _authorities, _config, _dependencyHash, collectionId);
    }

    /// @notice Stronger diagnostic reconstructing all full bytes, including artificial code edits.
    function requireFullDefinitionBytes(bytes32 id) external view {
        Lifecycle.requireFullDefinitionBytes(_states, _origins, _authorities, id);
    }

    function _stage(bytes32 id, uint16 stage) private view {
        Lifecycle.stage(_states, _origins, _authorities, id, stage);
    }

    function _append(bytes32 id, T.Item[] memory rows, bytes32 witnessHash) private {
        T.Plan storage p = _states[id].plans[id];
        uint64 index = p.segmentCount;
        bytes32 key =
            keccak256(abi.encode(keccak256("6529STREAM_RENDER_CRITICAL_SEGMENT_V1"), id, index));
        T.Segment memory segment = Chains.segment(key, witnessHash, rows);
        _states[id].segments[id][index] = segment;
        p.segmentChainHash = Chains.append(p.segmentChainHash, index, segment);
        p.segmentCount = index + 1;
        p.itemCount += segment.itemCount;
        emit InventorySegmentRecorded(id, index, segment, rows);
    }



    function originalAnchor() external view returns (S.Dependencies memory) {
        return _config.originalAnchor;
    }

    function authorityDependencies() external view returns (D.Dependencies memory) {
        return _config.authority;
    }

    function authoritySelection(bytes32 id) external view returns (D.Capture memory captured) {
        captured = _authorities[id].capture;
        if (captured.selection.selectionHash == 0) revert T.InventoryIncomplete();
    }
}
