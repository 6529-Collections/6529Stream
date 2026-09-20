// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
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
import { StreamMultiOriginInventoryGuard as Guard } from "./StreamMultiOriginInventoryGuard.sol";
import "./StreamMultiOriginDescriptionStages.sol";
import "./StreamMultiOriginRecordStages.sol";
import "./StreamMultiOriginInterviewStage.sol";

/// @notice Deterministic complete inventory of the supported native eight-input profile.
/// @dev Permissionless materialization confers no publication or signing authority. Every
/// source already has an authenticated original. No finality provider, final manifest or
/// sanction record enters this dependency graph or the independent evidence preimage.
contract StreamMultiOriginRenderCriticalInventory is
    IStreamRenderCriticalInventory,
    IStreamArtistArchiveOriginInventory
{
    // Constructor-only storage is intentional: late Artist/Coordinator pins do not enter
    // runtime code, avoiding a circular Registry/provider/Coordinator runtime hash graph.
    State.State private _state;
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

    constructor(S.Dependencies memory d, O.Dependencies memory od) {
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
        _state.dependencies = d;
        OriginCalls.pin(od);
        _origins.dependencies = od;
        _state.dependencyHash = O.inventoryDependencyHash(d, od);
    }

    function dependencyHash() external view returns (bytes32) {
        return _state.dependencyHash;
    }

    function core() external view override returns (address) {
        return _state.dependencies.targets[0];
    }

    function metadataHost() external view override returns (address) {
        return _state.dependencies.targets[1];
    }

    function metadataRouter() external view override returns (address) {
        return _state.dependencies.targets[4];
    }

    function snapshots() external view override returns (address) {
        return _state.dependencies.targets[5];
    }

    function referencePublisher() external view override returns (address) {
        return _state.dependencies.targets[6];
    }

    function artifactCoverage() external view override returns (address) {
        return _state.dependencies.targets[10];
    }

    function externalCoverage() external view override returns (address) {
        return _state.dependencies.targets[11];
    }

    function deploymentChainId() external view override returns (uint256) {
        return _state.dependencies.chainId;
    }

    function coreCodeHash() external view override returns (bytes32) {
        return _state.dependencies.codeHashes[0];
    }

    function metadataCodeHash() external view override returns (bytes32) {
        return _state.dependencies.codeHashes[1];
    }

    function dependencies() external view returns (S.Dependencies memory) {
        return _state.dependencies;
    }

    function originDependencies() external view returns (O.Dependencies memory) {
        return _origins.dependencies;
    }

    function originProfile() external pure returns (bytes32) {
        return O.INVENTORY_PROFILE;
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
        if (_state.plans[id].nextToken != _state.plans[id].tokenCount) {
            revert T.InventoryIncomplete();
        }
        (T.Item[] memory rows, bytes32 witness) = Origins.runtimeItems(_origins, id);
        _append(id, rows, witness);
    }

    function beginInventory(uint256 collectionId) external returns (bytes32 id) {
        (
            S.Context memory c,
            O.Origin memory current,
            O.Origin memory presented,
            bytes32 lineageHash
        ) = OriginSources.current(_state.dependencies, _origins.dependencies, collectionId);
        id = Guard.planId(_state.dependencyHash, c, lineageHash);
        if (_state.plans[id].collectionId != 0) return id;
        Origins.initialize(_origins, id, current, presented, lineageHash);
        _state.contexts[id] = c;
        T.Plan storage p = _state.plans[id];
        p.collectionId = collectionId;
        p.subject = c.subject;
        p.artistId = c.artistId;
        p.sourceContextHash = keccak256(abi.encode(c));
        p.tokenCount = c.tokenCount;
        emit InventoryStarted(id, collectionId, p.sourceContextHash);
    }

    function appendNative(bytes32 id) external {
        _stage(id, 0);
        T.Item[] memory nativeRows = Sources.nativeItems(_state.dependencies, _state.contexts[id]);
        Roles.relabel(nativeRows);
        _append(id, nativeRows, _state.plans[id].sourceContextHash);
        _state.plans[id].completedStages = 1;
    }

    function appendReference(bytes32 id) external {
        _stage(id, 1);
        Reference.appendReference(_state, id);
        _state.plans[id].completedStages = 2;
    }

    function appendWork(
        bytes32 id,
        StreamWorkRecordTypes.Description calldata,
        address,
        O.ReceiptWitness calldata
    ) external {
        _stage(id, 2);
        StreamMultiOriginDescriptionStages.appendWork(_state, _origins, msg.data);
    }

    function appendRights(bytes32 id, StreamRightsRecordTypes.Statement calldata) external {
        _stage(id, 3);
        StreamRenderCriticalDescriptionStages.appendRights(_state, msg.data);
    }

    function appendIntent(
        bytes32 id,
        StreamConservationRecordTypes.Intent calldata,
        address,
        O.ReceiptWitness calldata
    ) external {
        _stage(id, 4);
        StreamMultiOriginRecordStages.appendIntent(_state, _origins, msg.data);
    }

    function appendIntentWaiver(
        bytes32 id,
        StreamConservationRecordTypes.IntentWaiver calldata,
        address,
        O.ReceiptWitness calldata
    ) external {
        _stage(id, 4);
        StreamMultiOriginRecordStages.appendIntentWaiver(_state, _origins, msg.data);
    }

    function appendInterview(
        bytes32 id,
        StreamConservationRecordTypes.Interview calldata,
        address,
        O.ReceiptWitness calldata
    ) external {
        _stage(id, 5);
        StreamMultiOriginInterviewStage.appendInterview(_state, _origins, msg.data);
    }

    function appendInterviewWaiver(bytes32 id) external {
        _stage(id, 5);
        StreamRenderCriticalInterviewStage.appendInterviewWaiver(_state, id);
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
            _state.dependencies,
            _origins.dependencies,
            _state.contexts[id],
            originalActor,
            originalObservedAt,
            _state.plans[id].sourceContextHash,
            receipt
        );
        Origins.remember(
            _origins,
            id,
            _state.plans[id].sourceContextHash,
            rows[0],
            original,
            bytes32(0),
            originalActor,
            keccak256("ORIGINAL_CONTENT_ROOT_AUTHORIZATION")
        );
        _append(id, rows, _state.contexts[id].rootRecordHash);
        _state.plans[id].completedStages = 7;
    }

    function appendDefinition(bytes32 id) external {
        _stage(id, 7);
        StreamRenderCriticalDefinitionStages.appendDefinition(_state, id);
    }

    function appendToken(bytes32 id, IStreamOnchainContentCheckpoint.TokenPayload calldata payload)
        external
    {
        _stage(id, 8);
        T.Plan storage p = _state.plans[id];
        uint64 index = p.nextToken;
        _append(
            id,
            StreamRenderCriticalTokenReads.tokenItems(
                _state.dependencies, _state.contexts[id], index, payload
            ),
            keccak256(abi.encode(_state.contexts[id].checkpointHash, index))
        );
        p.nextToken = index + 1;
    }

    function sealInventory(bytes32 id) external returns (T.Evidence memory evidence) {
        _stage(id, 8);
        T.Plan storage p = _state.plans[id];
        if (p.nextToken != p.tokenCount) revert T.InventoryIncomplete();
        S.Context memory now_ = Guard.requireCurrent(_state, _origins, id);
        bytes32 originRoot = Origins.seal(_origins, id);
        StreamRenderCriticalDefinitionStages.requireDefinitions(_state, id, false);
        evidence = _evidence(id, now_, p);
        evidence.renderCriticalEvidenceHash = keccak256(
            abi.encode(
                O.INVENTORY_PROFILE,
                block.chainid,
                address(this),
                _state.dependencyHash,
                evidence,
                originRoot,
                _origins.origins[id].length
            )
        );
        p.renderCriticalEvidenceHash = evidence.renderCriticalEvidenceHash;
        _state.completed[id] = evidence;
        emit InventoryCompleted(id, evidence.renderCriticalEvidenceHash, evidence);
    }

    function inventoryEvidence(bytes32 id)
        external
        view
        override
        returns (T.Evidence memory result)
    {
        result = _state.completed[id];
        if (result.renderCriticalEvidenceHash == 0) revert T.InventoryIncomplete();
    }

    function inventorySegment(bytes32 id, uint64 index)
        external
        view
        override
        returns (T.Segment memory)
    {
        if (index >= _state.plans[id].segmentCount) revert T.InvalidInventorySegment();
        return _state.segments[id][index];
    }

    function plan(bytes32 id) external view returns (T.Plan memory) {
        return _state.plans[id];
    }

    function sourceContext(bytes32 id) external view returns (S.Context memory) {
        if (_state.plans[id].collectionId == 0) revert T.InventoryIncomplete();
        return _state.contexts[id];
    }

    function requireCurrent(uint256 collectionId)
        external
        view
        override
        returns (T.Evidence memory result)
    {
        (S.Context memory c,,, bytes32 lineageHash) =
            OriginSources.current(_state.dependencies, _origins.dependencies, collectionId);
        bytes32 id = Guard.planId(_state.dependencyHash, c, lineageHash);
        result = _state.completed[id];
        if (result.renderCriticalEvidenceHash == 0) revert T.InventoryIncomplete();
        Origins.requirePins(_origins, id);
        StreamRenderCriticalDefinitionStages.requireDefinitions(_state, id, false);
    }

    /// @notice Stronger diagnostic reconstructing all full bytes, including artificial code edits.
    function requireFullDefinitionBytes(bytes32 id) external view {
        if (_state.completed[id].renderCriticalEvidenceHash == 0) revert T.InventoryIncomplete();
        Guard.requireCurrent(_state, _origins, id);
        StreamRenderCriticalDefinitionStages.requireDefinitions(_state, id, true);
    }

    function _stage(bytes32 id, uint16 stage) private view {
        T.Plan storage p = _state.plans[id];
        if (p.collectionId == 0 || p.completedStages != stage || p.renderCriticalEvidenceHash != 0) revert T.InventoryIncomplete();
        Guard.requireCurrent(_state, _origins, id);
    }

    function _append(bytes32 id, T.Item[] memory rows, bytes32 witnessHash) private {
        T.Plan storage p = _state.plans[id];
        uint64 index = p.segmentCount;
        bytes32 key =
            keccak256(abi.encode(keccak256("6529STREAM_RENDER_CRITICAL_SEGMENT_V1"), id, index));
        T.Segment memory segment = Chains.segment(key, witnessHash, rows);
        _state.segments[id][index] = segment;
        p.segmentChainHash = Chains.append(p.segmentChainHash, index, segment);
        p.segmentCount = index + 1;
        p.itemCount += segment.itemCount;
        emit InventorySegmentRecorded(id, index, segment, rows);
    }

    function _evidence(bytes32 id, S.Context memory c, T.Plan storage p)
        private
        view
        returns (T.Evidence memory e)
    {
        e.planId = id;
        e.collectionId = c.collectionId;
        e.scopeSubject = c.subject;
        e.artistId = c.artistId;
        e.originals = T.OriginalInputs(
            c.rootRecordHash,
            c.snapshot.recordHash,
            c.referenceRender.recordHash,
            c.conservation.record.kind == IStreamConservationRecordSelection.RecordKind.INTENT
                ? c.conservation.record.recordHash
                : bytes32(0),
            c.conservation.record.kind
                == IStreamConservationRecordSelection.RecordKind.INTENT_WAIVER
                ? c.conservation.record.recordHash
                : bytes32(0),
            c.interviewEvidenceHash,
            c.descriptions.rightsStatementRecordHash,
            c.descriptions.workDescriptionRecordHash
        );
        e.sourceContextHash = p.sourceContextHash;
        e.tokenInventoryHash = c.tokenInventoryHash;
        e.tokenCount = c.tokenCount;
        e.segmentCount = p.segmentCount;
        e.itemCount = p.itemCount;
        e.segmentChainHash = p.segmentChainHash;
    }
}
