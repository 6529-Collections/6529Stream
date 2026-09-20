// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import { StreamMultiOriginInventoryState as Origins } from "./StreamMultiOriginInventoryState.sol";
import {
    StreamMultiOriginPolicyInventoryGuardV2 as Guard
} from "./StreamMultiOriginPolicyInventoryGuardV2.sol";
import {
    StreamMultiOriginInventoryCalls as OriginCalls
} from "./StreamMultiOriginInventoryCalls.sol";
import { StreamMultiOriginRootCalls as RootCalls } from "./StreamMultiOriginRootCalls.sol";
import {
    IStreamArtistArchiveOriginInventory
} from "../../interfaces/stream/preservation/IStreamArtistArchiveOriginInventory.sol";

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
import {
    StreamPolicyRenderCriticalSourceReadsV2 as Sources
} from "./StreamPolicyRenderCriticalSourceReadsV2.sol";
import {
    StreamPolicyReferenceInventoryReadsV2 as Reference
} from "./StreamPolicyReferenceInventoryReadsV2.sol";
import "../../interfaces/stream/preservation/IStreamPolicyRenderCriticalInventoryV2.sol";
import {
    StreamPolicyRenderCriticalTypesV2 as C
} from "../../interfaces/stream/preservation/StreamPolicyRenderCriticalTypesV2.sol";
import {
    StreamPolicyRenderCriticalNativeReadsV2 as Native
} from "./StreamPolicyRenderCriticalNativeReadsV2.sol";
import {
    StreamPolicyRenderCriticalRootAuthorizationV2 as Root
} from "./StreamPolicyRenderCriticalRootAuthorizationV2.sol";
import {
    StreamMultiOriginPolicyRenderCriticalCommonStagesV2 as Common
} from "./StreamMultiOriginPolicyRenderCriticalCommonStagesV2.sol";
import {
    StreamPolicyRenderCriticalTokenStagesV2 as Tokens
} from "./StreamPolicyRenderCriticalTokenStagesV2.sol";
import {
    IStreamScopedContentRootPublication as Aggregate
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamPolicyContentCheckpointV2 as Content
} from "../../interfaces/stream/finality/IStreamPolicyContentCheckpointV2.sol";
import "../../interfaces/stream/metadata/IStreamWorkRecordSelection.sol";
import "../../interfaces/stream/metadata/StreamRightsRecordTypes.sol";
import "../../interfaces/stream/metadata/IStreamConservationRecordSelection.sol";
import "../../interfaces/stream/finality/IStreamOnchainContentCheckpoint.sol";
import "../../interfaces/stream/preservation/IStreamReferenceRenderPublication.sol";

import {
    StreamPolicyRenderCriticalStateV2 as State
} from "./StreamPolicyRenderCriticalStateV2.sol";
import {
    StreamPolicyRenderCriticalDefinitionStagesV2
} from "./StreamPolicyRenderCriticalDefinitionStagesV2.sol";

import {
    StreamMultiOriginPolicyRenderCriticalStartV2 as Start
} from "./StreamMultiOriginPolicyRenderCriticalStartV2.sol";
import {
    StreamMultiOriginPolicyRenderCriticalOriginalStagesV2 as OriginalsV2
} from "./StreamMultiOriginPolicyRenderCriticalOriginalStagesV2.sol";
import {
    StreamMultiOriginPolicyRenderCriticalCurrentV2 as Current
} from "./StreamMultiOriginPolicyRenderCriticalCurrentV2.sol";
import {
    StreamPolicyRenderCriticalContextV2 as ContextRead
} from "./StreamPolicyRenderCriticalContextV2.sol";

/// @notice Distinct complete COLLECTION V2 inventory, including each full current STATIC output.
/// @dev Permissionless materialization confers no publication or signing authority. Every
/// source already has an authenticated original. No finality provider, final manifest or
/// sanction record enters this dependency graph or the independent evidence preimage.
contract StreamMultiOriginPolicyRenderCriticalInventoryV2 is
    IStreamPolicyRenderCriticalInventoryV2,
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
        _state.records.dependencies = d;
        _state.records.dependencyHash = O.inventoryDependencyHash(O.POLICY_INVENTORY_PROFILE, d, od);
        OriginCalls.pin(od);
        _origins.dependencies = od;
    }

    function policyInventoryProfile() external pure override returns (bytes32) {
        return O.POLICY_INVENTORY_PROFILE;
    }

    function dependencyHash() external view override returns (bytes32) {
        return _state.records.dependencyHash;
    }

    function core() external view override returns (address) {
        return _state.records.dependencies.targets[0];
    }

    function metadataHost() external view override returns (address) {
        return _state.records.dependencies.targets[1];
    }

    function metadataRouter() external view override returns (address) {
        return _state.records.dependencies.targets[4];
    }

    function snapshots() external view override returns (address) {
        return _state.records.dependencies.targets[5];
    }

    function referencePublisher() external view override returns (address) {
        return _state.records.dependencies.targets[6];
    }

    function artifactCoverage() external view override returns (address) {
        return _state.records.dependencies.targets[10];
    }

    function externalCoverage() external view override returns (address) {
        return _state.records.dependencies.targets[11];
    }

    function deploymentChainId() external view override returns (uint256) {
        return _state.records.dependencies.chainId;
    }

    function coreCodeHash() external view override returns (bytes32) {
        return _state.records.dependencies.codeHashes[0];
    }

    function metadataCodeHash() external view override returns (bytes32) {
        return _state.records.dependencies.codeHashes[1];
    }

    function dependencies() external view override returns (S.Dependencies memory) {
        return _state.records.dependencies;
    }

    function beginInventory(uint256 collectionId) external returns (bytes32) {
        return Start.begin(_state, _origins, collectionId);
    }

    function appendNative(bytes32 id) external {
        Guard.requireCurrent(_state, _origins, id);
        OriginalsV2.appendNative(_state, id);
    }

    function appendReference(bytes32 id) external {
        Guard.requireCurrent(_state, _origins, id);
        OriginalsV2.appendReference(_state, id);
    }

    function appendWork(
        bytes32 id,
        StreamWorkRecordTypes.Description calldata,
        address,
        O.ReceiptWitness calldata
    ) external {
        Guard.requireCurrent(_state, _origins, id);
        Common.appendWork(_state, _origins, msg.data);
    }

    function appendRights(bytes32 id, StreamRightsRecordTypes.Statement calldata) external {
        Guard.requireCurrent(_state, _origins, id);
        Common.appendRights(_state, msg.data);
    }

    function appendIntent(
        bytes32 id,
        StreamConservationRecordTypes.Intent calldata,
        address,
        O.ReceiptWitness calldata
    ) external {
        Guard.requireCurrent(_state, _origins, id);
        Common.appendIntent(_state, _origins, msg.data);
    }

    function appendIntentWaiver(
        bytes32 id,
        StreamConservationRecordTypes.IntentWaiver calldata,
        address,
        O.ReceiptWitness calldata
    ) external {
        Guard.requireCurrent(_state, _origins, id);
        Common.appendIntentWaiver(_state, _origins, msg.data);
    }

    function appendInterview(
        bytes32 id,
        StreamConservationRecordTypes.Interview calldata,
        address,
        O.ReceiptWitness calldata
    ) external {
        Guard.requireCurrent(_state, _origins, id);
        Common.appendInterview(_state, _origins, msg.data);
    }

    function appendInterviewWaiver(bytes32 id) external {
        Guard.requireCurrent(_state, _origins, id);
        Common.appendInterviewWaiver(_state, id);
    }

    function appendRootAuthorization(
        bytes32 id,
        address actor,
        uint64 observedAt,
        Aggregate.Aggregate calldata originalAggregate,
        O.ReceiptWitness calldata receipt
    ) external {
        Guard.requireCurrent(_state, _origins, id);
        State.stage(_state, id, 6);
        T.Item[] memory rows = new T.Item[](1);
        O.RecordOrigin memory original;
        (rows[0], original) = RootCalls.policyContentItem(
            _state.records.dependencies,
            _origins.dependencies,
            _state.contexts[id],
            actor,
            observedAt,
            originalAggregate,
            _state.records.plans[id].sourceContextHash,
            receipt
        );
        Origins.remember(
            _origins,
            id,
            _state.records.plans[id].sourceContextHash,
            rows[0],
            original,
            bytes32(0),
            actor,
            keccak256("ORIGINAL_POLICY_CONTENT_ROOT_AUTHORIZATION_V2")
        );
        State.append(_state, id, rows, _state.contexts[id].records.rootRecordHash);
        _state.records.plans[id].completedStages = 7;
    }

    function appendDefinition(bytes32 id) external {
        Guard.requireCurrent(_state, _origins, id);
        StreamPolicyRenderCriticalDefinitionStagesV2.appendDefinition(_state, id);
    }

    function appendToken(bytes32 id, Content.Payload calldata payload) external {
        Guard.requireCurrent(_state, _origins, id);
        Tokens.appendOutput(_state, id, payload);
    }

    function appendScript(bytes32 id) external {
        Guard.requireCurrent(_state, _origins, id);
        Tokens.appendScript(_state, id, false);
    }

    function appendLibrary(bytes32 id) external {
        Guard.requireCurrent(_state, _origins, id);
        Tokens.appendScript(_state, id, true);
    }

    function appendRenderer(bytes32 id) external {
        Guard.requireCurrent(_state, _origins, id);
        Tokens.appendRenderer(_state, id);
    }

    function appendCurrentProfile(bytes32 id) external {
        Guard.requireCurrent(_state, _origins, id);
        Tokens.appendProfile(_state, id);
    }

    function tokenProgress(bytes32 id) external view returns (State.Progress memory) {
        return _state.progress[id];
    }

    function sealInventory(bytes32 id) external returns (T.Evidence memory) {
        return Current.sealInventory(_state, _origins, id);
    }

    function inventoryEvidence(bytes32 id)
        external
        view
        override
        returns (T.Evidence memory result)
    {
        result = _state.records.completed[id];
        if (result.renderCriticalEvidenceHash == 0) revert T.InventoryIncomplete();
    }

    function inventorySegment(bytes32 id, uint64 index)
        external
        view
        override
        returns (T.Segment memory)
    {
        if (index >= _state.records.plans[id].segmentCount) {
            revert T.InvalidInventorySegment();
        }
        return _state.records.segments[id][index];
    }

    function plan(bytes32 id) external view returns (T.Plan memory) {
        return _state.records.plans[id];
    }

    function sourceContext(bytes32 id) external view returns (C.Context memory) {
        bytes memory raw = ContextRead.encoded(_state, id);
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }

    function requireCurrent(uint256 collectionId)
        external
        view
        override
        returns (T.Evidence memory)
    {
        return Current.requireCurrent(_state, _origins, collectionId);
    }

    /// @notice Stronger diagnostic reconstructing all full bytes, including artificial code edits.
    function requireFullDefinitionBytes(bytes32 id) external view {
        if (_state.records.completed[id].renderCriticalEvidenceHash == 0) {
            revert T.InventoryIncomplete();
        }
        Guard.requireCurrent(_state, _origins, id);
        StreamPolicyRenderCriticalDefinitionStagesV2.requireDefinitions(_state, id, true);
    }

    function originDependencies() external view returns (O.Dependencies memory) {
        return _origins.dependencies;
    }

    function originProfile() external pure returns (bytes32) {
        return O.POLICY_INVENTORY_PROFILE;
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
        State.stage(_state, id, 8);
        Guard.requireCurrent(_state, _origins, id);
        T.Plan storage p = _state.records.plans[id];
        State.Progress storage token = _state.progress[id];
        if (p.nextToken != p.tokenCount || token.phase != 0 || token.row != 0 || token.count != 0) {
            revert T.InventoryIncomplete();
        }
        (T.Item[] memory rows, bytes32 witness) = Origins.runtimeItems(_origins, id);
        State.append(_state, id, rows, witness);
    }
}
