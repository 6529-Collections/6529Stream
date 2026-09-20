// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamScopedRenderCriticalInventory
} from "../../interfaces/stream/preservation/IStreamScopedRenderCriticalInventory.sol";
import {
    StreamScopedRenderCriticalTypes as Scoped
} from "../../interfaces/stream/preservation/StreamScopedRenderCriticalTypes.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamFinalityScope
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    IStreamStaticContentCheckpoint as Content
} from "../../interfaces/stream/finality/IStreamStaticContentCheckpoint.sol";
import {
    IStreamScopedContentRootPublication as Root
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import { StreamWorkRecordTypes } from "../../interfaces/stream/metadata/StreamWorkRecordTypes.sol";
import {
    StreamRightsRecordTypes
} from "../../interfaces/stream/metadata/StreamRightsRecordTypes.sol";
import {
    StreamConservationRecordTypes
} from "../../interfaces/stream/metadata/StreamConservationRecordTypes.sol";
import {
    IStreamConservationRecordSelection as Conservation
} from "../../interfaces/stream/metadata/IStreamConservationRecordSelection.sol";
import { StreamScopedRenderCriticalState as State } from "./StreamScopedRenderCriticalState.sol";
import {
    StreamScopedRenderCriticalSourceReads as Sources
} from "./StreamScopedRenderCriticalSourceReads.sol";
import {
    StreamScopedRenderCriticalNativeReads as Native
} from "./StreamScopedRenderCriticalNativeReads.sol";
import {
    StreamScopedReferenceInventoryReads as Reference
} from "./StreamScopedReferenceInventoryReads.sol";
import {
    StreamScopedRenderCriticalDescriptionStages as Descriptions
} from "./StreamScopedRenderCriticalDescriptionStages.sol";
import {
    StreamScopedRenderCriticalRecordStages as Records
} from "./StreamScopedRenderCriticalRecordStages.sol";
import {
    StreamScopedRenderCriticalInterviewStage as Interviews
} from "./StreamScopedRenderCriticalInterviewStage.sol";
import {
    StreamScopedRenderCriticalRootAuthorization as Authority
} from "./StreamScopedRenderCriticalRootAuthorization.sol";
import {
    StreamScopedRenderCriticalDefinitionStages as Definitions
} from "./StreamScopedRenderCriticalDefinitionStages.sol";
import {
    StreamScopedRenderCriticalTokenStages as Tokens
} from "./StreamScopedRenderCriticalTokenStages.sol";

/// @notice Complete ordered TOKEN/RELEASE/SEASON source inventory under a distinct scope domain.
/// @dev Permissionless preparation confers no Artist, publication, archive or finality authority.
/// Constructor-only storage avoids a runtime hash cycle with the eventual fixed provider.
contract StreamScopedRenderCriticalInventory is IStreamScopedRenderCriticalInventory {
    State.State private _state;

    constructor(S.Dependencies memory d) {
        if (
            d.chainId != block.chainid || d.readGas < 50000 || d.sourceGas < d.readGas
                || d.selectionGas < d.readGas || d.snapshotGas < d.readGas
                || d.referenceGas < d.readGas
        ) {
            revert T.InventorySourceChanged();
        }
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
        _state.dependencyHash = keccak256(abi.encode(d));
    }

    function core() external view returns (address) {
        return _state.dependencies.targets[0];
    }

    function metadataHost() external view returns (address) {
        return _state.dependencies.targets[1];
    }

    function metadataRouter() external view returns (address) {
        return _state.dependencies.targets[4];
    }

    function snapshots() external view returns (address) {
        return _state.dependencies.targets[5];
    }

    function referencePublisher() external view returns (address) {
        return _state.dependencies.targets[6];
    }

    function artifactCoverage() external view returns (address) {
        return _state.dependencies.targets[10];
    }

    function externalCoverage() external view returns (address) {
        return _state.dependencies.targets[11];
    }

    function dependencies() external view returns (S.Dependencies memory) {
        return _state.dependencies;
    }

    function dependencyHash() external view returns (bytes32) {
        return _state.dependencyHash;
    }

    function beginInventory(StreamFinalityScope calldata scope) external returns (bytes32 id) {
        Scoped.Context memory c = Sources.current(_state.dependencies, scope);
        id = State.idFor(_state.dependencyHash, c);
        if (_state.plans[id].progress.collectionId != 0) return id;
        _state.contexts[id] = c;
        Scoped.Plan storage plan_ = _state.plans[id];
        plan_.scope = scope;
        T.Plan storage p = plan_.progress;
        p.collectionId = scope.collectionId;
        p.subject = c.subject;
        p.artistId = c.artistId;
        p.sourceContextHash = keccak256(abi.encode(c));
        p.tokenCount = c.tokenCount;
        emit ScopedInventoryStarted(1, id, scope, p.sourceContextHash);
    }

    function appendNative(bytes32 id, uint64 maximum) external {
        Native.appendNative(_state, id, maximum);
    }

    function appendReference(bytes32 id, uint64 maximum) external {
        Reference.appendReference(_state, id, maximum);
    }

    function appendWork(bytes32, StreamWorkRecordTypes.Description calldata, address) external {
        Descriptions.appendWork(_state, msg.data);
    }

    function appendRights(bytes32, StreamRightsRecordTypes.Statement calldata) external {
        Descriptions.appendRights(_state, msg.data);
    }

    function appendIntent(bytes32, StreamConservationRecordTypes.Intent calldata, address)
        external
    {
        Records.appendIntent(_state, msg.data);
    }

    function appendIntentWaiver(
        bytes32,
        StreamConservationRecordTypes.IntentWaiver calldata,
        address
    ) external {
        Records.appendIntentWaiver(_state, msg.data);
    }

    function appendInterview(bytes32, StreamConservationRecordTypes.Interview calldata, address)
        external
    {
        Interviews.appendInterview(_state, msg.data);
    }

    function appendInterviewWaiver(bytes32 id) external {
        Interviews.appendInterviewWaiver(_state, id);
    }

    function appendRootAuthorization(
        bytes32 id,
        address actor,
        uint64 observedAt,
        Root.Aggregate calldata originalAggregate,
        bytes32 originalLegacyFamilyHash
    ) external {
        Authority.appendRootAuthorization(
            _state, id, actor, observedAt, originalAggregate, originalLegacyFamilyHash
        );
    }

    function appendDefinition(bytes32 id) external {
        Definitions.appendDefinition(_state, id);
    }

    function appendTokenOutput(bytes32 id, Content.Payload calldata payload) external {
        Tokens.appendOutput(_state, id, payload);
    }

    function appendTokenScript(bytes32 id) external {
        Tokens.appendScript(_state, id, false);
    }

    function appendTokenLibrary(bytes32 id) external {
        Tokens.appendScript(_state, id, true);
    }

    function appendTokenRenderer(bytes32 id) external {
        Tokens.appendRenderer(_state, id);
    }

    function appendTokenCitation(bytes32 id) external {
        Tokens.appendCitation(_state, id);
    }

    function sealInventory(bytes32 id) external returns (Scoped.Evidence memory evidence) {
        State.stage(_state, id, 8);
        T.Plan storage p = _state.plans[id].progress;
        Scoped.TokenProgress storage token = _state.tokenProgress[id];
        if (p.nextToken != p.tokenCount || token.phase != 0 || token.row != 0 || token.count != 0) {
            revert T.InventoryIncomplete();
        }
        Definitions.requireDefinitions(_state, id, false);
        evidence = _evidence(id);
        evidence.inventory.renderCriticalEvidenceHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_RENDER_CRITICAL_EVIDENCE_V1"),
                block.chainid,
                address(this),
                _state.dependencyHash,
                evidence
            )
        );
        p.renderCriticalEvidenceHash = evidence.inventory.renderCriticalEvidenceHash;
        _state.completed[id] = evidence;
        emit ScopedInventoryCompleted(
            1, id, evidence.inventory.renderCriticalEvidenceHash, evidence
        );
    }

    function plan(bytes32 id) external view returns (Scoped.Plan memory) {
        return _state.plans[id];
    }

    function tokenProgress(bytes32 id) external view returns (Scoped.TokenProgress memory) {
        return _state.tokenProgress[id];
    }

    function sourceContext(bytes32 id) external view returns (Scoped.Context memory) {
        if (_state.plans[id].progress.collectionId == 0) revert T.InventoryIncomplete();
        return _state.contexts[id];
    }

    function inventorySegment(bytes32 id, uint64 index) external view returns (T.Segment memory) {
        if (index >= _state.plans[id].progress.segmentCount) revert T.InvalidInventorySegment();
        return _state.segments[id][index];
    }

    function inventoryEvidence(bytes32 id) external view returns (Scoped.Evidence memory e) {
        e = _state.completed[id];
        if (e.inventory.renderCriticalEvidenceHash == 0) revert T.InventoryIncomplete();
    }

    function requireCurrent(StreamFinalityScope calldata scope)
        external
        view
        returns (Scoped.Evidence memory e)
    {
        Scoped.Context memory c = Sources.current(_state.dependencies, scope);
        bytes32 id = State.idFor(_state.dependencyHash, c);
        e = _state.completed[id];
        if (e.inventory.renderCriticalEvidenceHash == 0) revert T.InventoryIncomplete();
        Definitions.requireDefinitions(_state, id, false);
    }

    function requireFullDefinitionBytes(bytes32 id) external view {
        if (_state.completed[id].inventory.renderCriticalEvidenceHash == 0) {
            revert T.InventoryIncomplete();
        }
        State.requireCurrent(_state, id);
        Definitions.requireDefinitions(_state, id, true);
    }

    function _evidence(bytes32 id) private view returns (Scoped.Evidence memory result) {
        Scoped.Context storage c = _state.contexts[id];
        T.Plan storage p = _state.plans[id].progress;
        result.scope = c.scope;
        T.Evidence memory e;
        e.planId = id;
        e.collectionId = c.scope.collectionId;
        e.scopeSubject = c.subject;
        e.artistId = c.artistId;
        e.originals = T.OriginalInputs(
            c.rootRecordHash,
            c.snapshot.recordHash,
            c.referenceRender.observation.recordHash,
            c.conservation.record.kind == Conservation.RecordKind.INTENT
                ? c.conservation.record.recordHash
                : bytes32(0),
            c.conservation.record.kind == Conservation.RecordKind.INTENT_WAIVER
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
        result.inventory = e;
    }
}
