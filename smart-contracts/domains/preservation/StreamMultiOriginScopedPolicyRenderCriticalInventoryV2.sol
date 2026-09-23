// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import { StreamMultiOriginInventoryState as Origins } from "./StreamMultiOriginInventoryState.sol";
import {
    StreamMultiOriginInventoryCalls as OriginCalls
} from "./StreamMultiOriginInventoryCalls.sol";
import { StreamMultiOriginRootCalls as RootCalls } from "./StreamMultiOriginRootCalls.sol";
import {
    IStreamArtistArchiveOriginInventory
} from "../../interfaces/stream/preservation/IStreamArtistArchiveOriginInventory.sol";

import {
    IStreamMultiOriginScopedPolicyRenderCriticalInventoryV2
} from "../../interfaces/stream/preservation/IStreamMultiOriginScopedPolicyRenderCriticalInventoryV2.sol";
import {
    StreamScopedPolicyRenderCriticalTypesV2 as Scoped
} from "../../interfaces/stream/preservation/StreamScopedPolicyRenderCriticalTypesV2.sol";
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
    IStreamScopedPolicyContentCheckpointV2 as Content
} from "../../interfaces/stream/finality/IStreamScopedPolicyContentCheckpointV2.sol";
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
import {
    StreamMultiOriginScopedPolicyRenderCriticalStateV2 as State
} from "./StreamMultiOriginScopedPolicyRenderCriticalStateV2.sol";
import {
    StreamMultiOriginScopedPolicyRenderCriticalSourceReadsV2 as Sources
} from "./StreamMultiOriginScopedPolicyRenderCriticalSourceReadsV2.sol";
import {
    StreamMultiOriginScopedPolicyRenderCriticalOriginalStagesV2 as Native
} from "./StreamMultiOriginScopedPolicyRenderCriticalOriginalStagesV2.sol";
import {
    StreamScopedPolicyReferenceInventoryReadsV2 as Reference
} from "./StreamScopedPolicyReferenceInventoryReadsV2.sol";
import {
    StreamMultiOriginScopedPolicyRenderCriticalDescriptionStagesV2 as Descriptions
} from "./StreamMultiOriginScopedPolicyRenderCriticalDescriptionStagesV2.sol";
import {
    StreamMultiOriginScopedPolicyRenderCriticalRecordStagesV2 as Records
} from "./StreamMultiOriginScopedPolicyRenderCriticalRecordStagesV2.sol";
import {
    StreamMultiOriginScopedPolicyRenderCriticalInterviewStageV2 as Interviews
} from "./StreamMultiOriginScopedPolicyRenderCriticalInterviewStageV2.sol";
import {
    StreamMultiOriginScopedPolicyRenderCriticalDefinitionStagesV2 as Definitions
} from "./StreamMultiOriginScopedPolicyRenderCriticalDefinitionStagesV2.sol";
import {
    StreamMultiOriginScopedPolicyRenderCriticalTokenStagesV2 as Tokens
} from "./StreamMultiOriginScopedPolicyRenderCriticalTokenStagesV2.sol";

/// @notice Complete ordered TOKEN/RELEASE/SEASON source inventory under a distinct scope domain.
/// @dev Permissionless preparation confers no Artist, publication, archive or finality authority.
/// Constructor-only storage avoids a runtime hash cycle with the eventual fixed provider.
contract StreamMultiOriginScopedPolicyRenderCriticalInventoryV2 is
    IStreamMultiOriginScopedPolicyRenderCriticalInventoryV2
{
    State.State private _state;

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamMultiOriginScopedPolicyRenderCriticalInventoryV2).interfaceId
            || id == type(IStreamArtistArchiveOriginInventory).interfaceId || id == 0x01ffc9a7;
    }

    function scopedPolicyInventoryProfile() external pure returns (bytes32) {
        return O.SCOPED_POLICY_INVENTORY_PROFILE;
    }

    constructor(S.Dependencies memory d, O.Dependencies memory od) {
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
        _state.dependencyHash = O.inventoryDependencyHash(O.SCOPED_POLICY_INVENTORY_PROFILE, d, od);
        OriginCalls.pin(od);
        _state.origins.dependencies = od;
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
        (
            Scoped.Context memory c,
            O.Origin memory current,
            O.Origin memory presented,
            bytes32 lineageHash
        ) = Sources.current(_state.dependencies, _state.origins.dependencies, scope);
        id = State.idFor(_state.dependencyHash, c, lineageHash);
        if (_state.plans[id].progress.collectionId != 0) return id;
        Origins.initialize(_state.origins, id, current, presented, lineageHash);
        _state.contexts[id] = c;
        Scoped.Plan storage plan_ = _state.plans[id];
        plan_.scope = scope;
        T.Plan storage p = plan_.progress;
        p.collectionId = scope.collectionId;
        p.subject = c.subject;
        p.artistId = c.artistId;
        p.sourceContextHash = keccak256(abi.encode(c));
        p.tokenCount = c.tokenCount;
        emit ScopedInventoryStarted(2, id, scope, p.sourceContextHash);
    }

    function appendNative(bytes32 id, uint64 maximum) external {
        Native.appendNative(_state, id, maximum);
    }

    function appendReference(bytes32 id, uint64 maximum) external {
        State.stage(_state, id, 1);
        Scoped.Context storage c = _state.contexts[id];
        Scoped.Plan storage p = _state.plans[id];
        Reference.Context memory context =
            Reference.Context(c.scope, c.subject, c.artistId, c.snapshot, c.referenceRender);
        (T.Item[] memory rows, uint64 total) =
            Reference.items(_state.dependencies, context, p.referenceCursor, maximum);
        if (p.referenceCursor != 0 && p.referenceCount != total) revert T.InventorySourceChanged();
        p.referenceCount = total;
        State.append(
            _state,
            id,
            rows,
            keccak256(abi.encode(p.progress.sourceContextHash, p.referenceCursor, total))
        );
        p.referenceCursor += uint64(rows.length);
        if (p.referenceCursor == total) p.progress.completedStages = 2;
    }

    function appendWork(
        bytes32,
        StreamWorkRecordTypes.Description calldata,
        address,
        O.ReceiptWitness calldata
    ) external {
        Descriptions.appendWork(_state, msg.data);
    }

    function appendRights(bytes32, StreamRightsRecordTypes.Statement calldata) external {
        Descriptions.appendRights(_state, msg.data);
    }

    function appendIntent(
        bytes32,
        StreamConservationRecordTypes.Intent calldata,
        address,
        O.ReceiptWitness calldata
    ) external {
        Records.appendIntent(_state, msg.data);
    }

    function appendIntentWaiver(
        bytes32,
        StreamConservationRecordTypes.IntentWaiver calldata,
        address,
        O.ReceiptWitness calldata
    ) external {
        Records.appendIntentWaiver(_state, msg.data);
    }

    function appendInterview(
        bytes32,
        StreamConservationRecordTypes.Interview calldata,
        address,
        O.ReceiptWitness calldata
    ) external {
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
        bytes32 originalLegacyFamilyHash,
        O.ReceiptWitness calldata receipt
    ) external {
        State.stage(_state, id, 6);
        T.Item[] memory rows = new T.Item[](1);
        O.RecordOrigin memory original;
        (rows[0], original) = RootCalls.scopedPolicyContentItem(
            _state.dependencies,
            _state.origins.dependencies,
            _state.contexts[id],
            actor,
            observedAt,
            originalAggregate,
            originalLegacyFamilyHash,
            _state.plans[id].progress.sourceContextHash,
            receipt
        );
        Origins.remember(
            _state.origins,
            id,
            _state.plans[id].progress.sourceContextHash,
            rows[0],
            original,
            bytes32(0),
            actor,
            keccak256("ORIGINAL_SCOPED_POLICY_CONTENT_ROOT_AUTHORIZATION_V2")
        );
        State.append(_state, id, rows, _state.contexts[id].rootRecordHash);
        _state.plans[id].progress.completedStages = 7;
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
        bytes32 originRoot = Origins.seal(_state.origins, id);
        evidence = _evidence(id);
        evidence.inventory.renderCriticalEvidenceHash = keccak256(
            abi.encode(
                O.SCOPED_POLICY_INVENTORY_PROFILE,
                block.chainid,
                address(this),
                _state.dependencyHash,
                evidence,
                originRoot,
                _state.origins.origins[id].length
            )
        );
        p.renderCriticalEvidenceHash = evidence.inventory.renderCriticalEvidenceHash;
        _state.completed[id] = evidence;
        emit ScopedInventoryCompleted(
            2, id, evidence.inventory.renderCriticalEvidenceHash, evidence
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
        (Scoped.Context memory c,,, bytes32 lineageHash) =
            Sources.current(_state.dependencies, _state.origins.dependencies, scope);
        bytes32 id = State.idFor(_state.dependencyHash, c, lineageHash);
        e = _state.completed[id];
        if (e.inventory.renderCriticalEvidenceHash == 0) revert T.InventoryIncomplete();
        Origins.requirePins(_state.origins, id);
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

    function originDependencies() external view returns (O.Dependencies memory) {
        return _state.origins.dependencies;
    }

    function originProfile() external pure returns (bytes32) {
        return O.SCOPED_POLICY_INVENTORY_PROFILE;
    }

    function originCount(bytes32 id) external view returns (uint256) {
        return _state.origins.origins[id].length;
    }

    function originAt(bytes32 id, uint256 index) external view returns (O.Origin memory) {
        if (index >= _state.origins.origins[id].length) revert O.InvalidArchiveOrigin();
        return _state.origins.origins[id][index];
    }

    function originSetHash(bytes32 id) external view returns (bytes32) {
        return _state.origins.sealedRoot[id];
    }

    function artistArchiveOrigin(bytes32 id, bytes32 itemHash)
        external
        view
        returns (O.RecordOrigin memory original)
    {
        original = _state.origins.records[id][itemHash];
        if (original.sourceContextHash == 0) revert O.InvalidArchiveOrigin();
    }

    function originRuntimeCursor(bytes32 id) external view returns (uint256) {
        return _state.origins.runtimeCursor[id];
    }

    function appendOriginRuntime(bytes32 id) external {
        State.stage(_state, id, 8);
        T.Plan storage p = _state.plans[id].progress;
        Scoped.TokenProgress storage token = _state.tokenProgress[id];
        if (p.nextToken != p.tokenCount || token.phase != 0 || token.row != 0 || token.count != 0) {
            revert T.InventoryIncomplete();
        }
        (T.Item[] memory rows, bytes32 witness) = Origins.runtimeItems(_state.origins, id);
        State.append(_state, id, rows, witness);
    }
}
