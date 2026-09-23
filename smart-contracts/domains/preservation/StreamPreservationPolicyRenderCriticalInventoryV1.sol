// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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
    StreamPreservationPolicyRenderCriticalSourceReadsV1 as Sources
} from "./StreamPreservationPolicyRenderCriticalSourceReadsV1.sol";
import {
    StreamPreservationPolicyReferenceInventoryReadsV1 as Reference
} from "./StreamPreservationPolicyReferenceInventoryReadsV1.sol";
import "../../interfaces/stream/preservation/IStreamPreservationPolicyRenderCriticalInventoryV1.sol";
import {
    StreamPreservationPolicyRenderCriticalTypesV1 as C
} from "../../interfaces/stream/preservation/StreamPreservationPolicyRenderCriticalTypesV1.sol";
import {
    StreamPreservationPolicyRenderCriticalNativeReadsV1 as Native
} from "./StreamPreservationPolicyRenderCriticalNativeReadsV1.sol";
import {
    StreamPreservationPolicyRenderCriticalRootAuthorizationV1 as Root
} from "./StreamPreservationPolicyRenderCriticalRootAuthorizationV1.sol";
import {
    StreamPreservationPolicyRenderCriticalCommonStagesV1 as Common
} from "./StreamPreservationPolicyRenderCriticalCommonStagesV1.sol";
import {
    StreamPreservationPolicyRenderCriticalTokenStagesV1 as Tokens
} from "./StreamPreservationPolicyRenderCriticalTokenStagesV1.sol";
import {
    IStreamScopedContentRootPublication as Aggregate
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as Content
} from "../../interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import "../../interfaces/stream/metadata/IStreamWorkRecordSelection.sol";
import "../../interfaces/stream/metadata/StreamRightsRecordTypes.sol";
import "../../interfaces/stream/metadata/IStreamConservationRecordSelection.sol";
import "../../interfaces/stream/finality/IStreamOnchainContentCheckpoint.sol";
import "../../interfaces/stream/preservation/IStreamReferenceRenderPublication.sol";

import {
    StreamPreservationPolicyRenderCriticalStateV1 as State
} from "./StreamPreservationPolicyRenderCriticalStateV1.sol";
import {
    StreamPreservationPolicyRenderCriticalDefinitionStagesV1
} from "./StreamPreservationPolicyRenderCriticalDefinitionStagesV1.sol";

import {
    StreamPreservationPolicyRenderCriticalStartV1 as Start
} from "./StreamPreservationPolicyRenderCriticalStartV1.sol";
import {
    StreamPreservationPolicyRenderCriticalOriginalStagesV1 as OriginalsV2
} from "./StreamPreservationPolicyRenderCriticalOriginalStagesV1.sol";
import {
    StreamPreservationPolicyRenderCriticalCurrentV1 as Current
} from "./StreamPreservationPolicyRenderCriticalCurrentV1.sol";
import {
    StreamPreservationPolicyRenderCriticalContextV1 as ContextRead
} from "./StreamPreservationPolicyRenderCriticalContextV1.sol";

/// @notice Distinct complete COLLECTION preservation inventory, including each explicit current preservation output.
/// @dev Permissionless materialization confers no publication or signing authority. Every
/// source already has an authenticated original. No finality provider, final manifest or
/// sanction record enters this dependency graph or the independent evidence preimage.
contract StreamPreservationPolicyRenderCriticalInventoryV1 is
    IStreamPreservationPolicyRenderCriticalInventoryV1
{
    // Constructor-only storage is intentional: late Artist/Coordinator pins do not enter
    // runtime code, avoiding a circular Registry/provider/Coordinator runtime hash graph.
    State.State private _state;

    event InventoryStarted(
        bytes32 indexed planId, uint256 indexed collectionId, bytes32 sourceContextHash
    );
    event InventorySegmentRecorded(
        bytes32 indexed planId, uint64 indexed index, T.Segment segment, T.Item[] items
    );
    event InventoryCompleted(
        bytes32 indexed planId, bytes32 indexed renderCriticalEvidenceHash, T.Evidence evidence
    );

    constructor(S.Dependencies memory d) {
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
        _state.records.dependencyHash = keccak256(abi.encode(d));
    }

    function preservationPolicyInventoryProfile() external pure override returns (bytes32) {
        return C.PROFILE;
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
        return Start.begin(_state, collectionId);
    }

    function appendNative(bytes32 id) external {
        OriginalsV2.appendNative(_state, id);
    }

    function appendReference(bytes32 id) external {
        OriginalsV2.appendReference(_state, id);
    }

    function appendWork(bytes32, StreamWorkRecordTypes.Description calldata, address) external {
        Common.appendWork(_state, msg.data);
    }

    function appendRights(bytes32, StreamRightsRecordTypes.Statement calldata) external {
        Common.appendRights(_state, msg.data);
    }

    function appendIntent(bytes32, StreamConservationRecordTypes.Intent calldata, address)
        external
    {
        Common.appendIntent(_state, msg.data);
    }

    function appendIntentWaiver(
        bytes32,
        StreamConservationRecordTypes.IntentWaiver calldata,
        address
    ) external {
        Common.appendIntentWaiver(_state, msg.data);
    }

    function appendInterview(bytes32, StreamConservationRecordTypes.Interview calldata, address)
        external
    {
        Common.appendInterview(_state, msg.data);
    }

    function appendInterviewWaiver(bytes32 id) external {
        Common.appendInterviewWaiver(_state, id);
    }

    function appendRootAuthorization(
        bytes32 id,
        address actor,
        uint64 observedAt,
        Aggregate.Aggregate calldata originalAggregate
    ) external {
        OriginalsV2.appendRoot(_state, id, actor, observedAt, originalAggregate);
    }

    function appendDefinition(bytes32 id) external {
        StreamPreservationPolicyRenderCriticalDefinitionStagesV1.appendDefinition(_state, id);
    }

    function appendToken(bytes32 id, Content.Payload calldata payload) external {
        Tokens.appendOutput(_state, id, payload);
    }

    function appendScript(bytes32 id) external {
        Tokens.appendScript(_state, id, false);
    }

    function appendLibrary(bytes32 id) external {
        Tokens.appendScript(_state, id, true);
    }

    function appendRenderer(bytes32 id) external {
        Tokens.appendRenderer(_state, id);
    }

    function appendCurrentProfile(bytes32 id) external {
        Tokens.appendProfile(_state, id);
    }

    function tokenProgress(bytes32 id) external view returns (State.Progress memory) {
        return _state.progress[id];
    }

    function appendTokenPreservation(bytes32 id) external {
        Tokens.appendPreservation(_state, id);
    }

    function sealInventory(bytes32 id) external returns (T.Evidence memory) {
        return Current.sealInventory(_state, id);
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
        return Current.requireCurrent(_state, collectionId);
    }

    /// @notice Stronger diagnostic reconstructing all full bytes, including artificial code edits.
    function requireFullDefinitionBytes(bytes32 id) external view {
        if (_state.records.completed[id].renderCriticalEvidenceHash == 0) {
            revert T.InventoryIncomplete();
        }
        Sources.bindings(_state.records.dependencies);
        StreamPreservationPolicyRenderCriticalDefinitionStagesV1.requireDefinitions(
            _state, id, true
        );
    }
}
