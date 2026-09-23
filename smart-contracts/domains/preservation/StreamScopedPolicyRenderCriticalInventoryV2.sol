// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamScopedPolicyInventoryFinishV2 as Finish
} from "./StreamScopedPolicyInventoryFinishV2.sol";
import {
    StreamScopedPolicyInventoryViewsV2 as Views
} from "./StreamScopedPolicyInventoryViewsV2.sol";
import {
    StreamScopedPolicyInventoryBeginV2 as Begin
} from "./StreamScopedPolicyInventoryBeginV2.sol";
import {
    IStreamScopedPolicyRenderCriticalInventoryV2
} from "../../interfaces/stream/preservation/IStreamScopedPolicyRenderCriticalInventoryV2.sol";
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
    StreamScopedPolicyRenderCriticalStateV2 as State
} from "./StreamScopedPolicyRenderCriticalStateV2.sol";

import {
    StreamScopedPolicyRenderCriticalNativeReadsV2 as Native
} from "./StreamScopedPolicyRenderCriticalNativeReadsV2.sol";
import {
    StreamScopedPolicyReferenceInventoryReadsV2 as Reference
} from "./StreamScopedPolicyReferenceInventoryReadsV2.sol";
import {
    StreamScopedPolicyRenderCriticalDescriptionStagesV2 as Descriptions
} from "./StreamScopedPolicyRenderCriticalDescriptionStagesV2.sol";
import {
    StreamScopedPolicyRenderCriticalRecordStagesV2 as Records
} from "./StreamScopedPolicyRenderCriticalRecordStagesV2.sol";
import {
    StreamScopedPolicyRenderCriticalInterviewStageV2 as Interviews
} from "./StreamScopedPolicyRenderCriticalInterviewStageV2.sol";
import {
    StreamScopedPolicyRenderCriticalRootAuthorizationV2 as Authority
} from "./StreamScopedPolicyRenderCriticalRootAuthorizationV2.sol";
import {
    StreamScopedPolicyRenderCriticalDefinitionStagesV2 as Definitions
} from "./StreamScopedPolicyRenderCriticalDefinitionStagesV2.sol";
import {
    StreamScopedPolicyRenderCriticalTokenStagesV2 as Tokens
} from "./StreamScopedPolicyRenderCriticalTokenStagesV2.sol";

/// @notice Complete ordered TOKEN/RELEASE/SEASON source inventory under a distinct scope domain.
/// @dev Permissionless preparation confers no Artist, publication, archive or finality authority.
/// Constructor-only storage avoids a runtime hash cycle with the eventual fixed provider.
contract StreamScopedPolicyRenderCriticalInventoryV2 is
    IStreamScopedPolicyRenderCriticalInventoryV2
{
    State.State private _state;

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return
            id == type(IStreamScopedPolicyRenderCriticalInventoryV2).interfaceId || id == 0x01ffc9a7;
    }

    function scopedPolicyInventoryProfile() external pure returns (bytes32) {
        return Scoped.PROFILE;
    }

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
        return Begin.beginInventory(_state, scope);
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
        return Finish.sealInventory(_state, id);
    }

    function plan(bytes32 id) external view returns (Scoped.Plan memory) {
        return _state.plans[id];
    }

    function tokenProgress(bytes32 id) external view returns (Scoped.TokenProgress memory) {
        return _state.tokenProgress[id];
    }

    function sourceContext(bytes32 id) external view returns (Scoped.Context memory) {
        bytes memory encoded = Views.sourceContext(_state, id);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
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
        bytes memory encoded = Views.requireCurrent(_state, scope);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function requireFullDefinitionBytes(bytes32 id) external view {
        Views.requireFullDefinitionBytes(_state, id);
    }
}
