// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../../interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    IStreamCurrentAuthorityInventory
} from "../../interfaces/stream/preservation/IStreamCurrentAuthorityInventory.sol";
import {
    StreamCurrentAuthorityInventorySelection as Authority
} from "./StreamCurrentAuthorityInventorySelection.sol";

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
    StreamCurrentAuthorityScopedPolicyRenderCriticalStateV2 as State
} from "./StreamCurrentAuthorityScopedPolicyRenderCriticalStateV2.sol";
import {
    StreamMultiOriginScopedPolicyRenderCriticalSourceReadsV2 as Sources
} from "./StreamMultiOriginScopedPolicyRenderCriticalSourceReadsV2.sol";
import {
    StreamCurrentAuthorityScopedPolicyRenderCriticalOriginalStagesV2 as Native
} from "./StreamCurrentAuthorityScopedPolicyRenderCriticalOriginalStagesV2.sol";
import {
    StreamScopedPolicyReferenceInventoryReadsV2 as Reference
} from "./StreamScopedPolicyReferenceInventoryReadsV2.sol";
import {
    StreamCurrentAuthorityScopedPolicyRenderCriticalDescriptionStagesV2 as Descriptions
} from "./StreamCurrentAuthorityScopedPolicyRenderCriticalDescriptionStagesV2.sol";
import {
    StreamCurrentAuthorityScopedPolicyRenderCriticalRecordStagesV2 as Records
} from "./StreamCurrentAuthorityScopedPolicyRenderCriticalRecordStagesV2.sol";
import {
    StreamCurrentAuthorityScopedPolicyRenderCriticalInterviewStageV2 as Interviews
} from "./StreamCurrentAuthorityScopedPolicyRenderCriticalInterviewStageV2.sol";
import {
    StreamCurrentAuthorityScopedPolicyRenderCriticalDefinitionStagesV2 as Definitions
} from "./StreamCurrentAuthorityScopedPolicyRenderCriticalDefinitionStagesV2.sol";
import {
    StreamCurrentAuthorityScopedPolicyRenderCriticalTokenStagesV2 as Tokens
} from "./StreamCurrentAuthorityScopedPolicyRenderCriticalTokenStagesV2.sol";

/// @notice Complete ordered TOKEN/RELEASE/SEASON source inventory under a distinct scope domain.
/// @dev Permissionless preparation confers no Artist, publication, archive or finality authority.
/// Constructor-only storage avoids a runtime hash cycle with the eventual fixed provider.
contract StreamCurrentAuthorityScopedPolicyRenderCriticalInventoryV2 is
    IStreamMultiOriginScopedPolicyRenderCriticalInventoryV2,
    IStreamCurrentAuthorityInventory
{
    mapping(bytes32 => State.State) private _states;
    Authority.Config private _config;
    O.Dependencies private _originDependencies;
    bytes32 private _dependencyHash;

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamMultiOriginScopedPolicyRenderCriticalInventoryV2).interfaceId
            || id == type(IStreamArtistArchiveOriginInventory).interfaceId
            || id == type(IStreamCurrentAuthorityInventory).interfaceId || id == 0x01ffc9a7;
    }

    function scopedPolicyInventoryProfile() external pure returns (bytes32) {
        return D.SCOPED_POLICY_INVENTORY_PROFILE;
    }

    constructor(S.Dependencies memory d, O.Dependencies memory od, D.Dependencies memory ad) {
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
        _config = Authority.Config(d, ad);
        Authority.validate(_config);
        _dependencyHash = D.dependencyHash(D.SCOPED_POLICY_INVENTORY_PROFILE, d, od, ad);
        OriginCalls.pin(od);
        _originDependencies = od;
    }

    function core() external view returns (address) {
        return _config.originalAnchor.targets[0];
    }

    function metadataHost() external view returns (address) {
        return _config.originalAnchor.targets[1];
    }

    function metadataRouter() external view returns (address) {
        return _config.originalAnchor.targets[4];
    }

    function snapshots() external view returns (address) {
        return _config.originalAnchor.targets[5];
    }

    function referencePublisher() external view returns (address) {
        return _config.originalAnchor.targets[6];
    }

    function artifactCoverage() external view returns (address) {
        return _config.originalAnchor.targets[10];
    }

    function externalCoverage() external view returns (address) {
        return _config.originalAnchor.targets[11];
    }

    function dependencies() external view returns (S.Dependencies memory) {
        return _config.originalAnchor;
    }

    function dependencyHash() external view returns (bytes32) {
        return _dependencyHash;
    }

    function beginInventory(StreamFinalityScope calldata scope) external returns (bytes32 id) {
        D.Capture memory captured = Authority.resolve(_config);
        (
            Scoped.Context memory c,
            O.Origin memory current,
            O.Origin memory presented,
            bytes32 lineageHash
        ) = Sources.current(captured.dependencies, _originDependencies, scope);
        id = State.idFor(_dependencyHash, captured, c, lineageHash);
        if (_states[id].plans[id].progress.collectionId != 0) return id;
        Authority.remember(_states[id].authority, _config, captured);
        _states[id].dependencies = captured.dependencies;
        _states[id].dependencyHash = _dependencyHash;
        _states[id].origins.dependencies = _originDependencies;
        Origins.initialize(_states[id].origins, id, current, presented, lineageHash);
        _states[id].contexts[id] = c;
        Scoped.Plan storage plan_ = _states[id].plans[id];
        plan_.scope = scope;
        T.Plan storage p = plan_.progress;
        p.collectionId = scope.collectionId;
        p.subject = c.subject;
        p.artistId = c.artistId;
        p.sourceContextHash = D.contextHash(captured, keccak256(abi.encode(c)), lineageHash);
        p.tokenCount = c.tokenCount;
        emit ScopedInventoryStarted(2, id, scope, p.sourceContextHash);
    }

    function appendNative(bytes32 id, uint64 maximum) external {
        Native.appendNative(_states[id], id, maximum);
    }

    function appendReference(bytes32 id, uint64 maximum) external {
        State.stage(_states[id], id, 1);
        Scoped.Context storage c = _states[id].contexts[id];
        Scoped.Plan storage p = _states[id].plans[id];
        Reference.Context memory context =
            Reference.Context(c.scope, c.subject, c.artistId, c.snapshot, c.referenceRender);
        (T.Item[] memory rows, uint64 total) =
            Reference.items(_states[id].dependencies, context, p.referenceCursor, maximum);
        if (p.referenceCursor != 0 && p.referenceCount != total) revert T.InventorySourceChanged();
        p.referenceCount = total;
        State.append(
            _states[id],
            id,
            rows,
            keccak256(abi.encode(p.progress.sourceContextHash, p.referenceCursor, total))
        );
        p.referenceCursor += uint64(rows.length);
        if (p.referenceCursor == total) p.progress.completedStages = 2;
    }

    function appendWork(
        bytes32 id,
        StreamWorkRecordTypes.Description calldata,
        address,
        O.ReceiptWitness calldata
    ) external {
        Descriptions.appendWork(_states[id], msg.data);
    }

    function appendRights(bytes32 id, StreamRightsRecordTypes.Statement calldata) external {
        Descriptions.appendRights(_states[id], msg.data);
    }

    function appendIntent(
        bytes32 id,
        StreamConservationRecordTypes.Intent calldata,
        address,
        O.ReceiptWitness calldata
    ) external {
        Records.appendIntent(_states[id], msg.data);
    }

    function appendIntentWaiver(
        bytes32 id,
        StreamConservationRecordTypes.IntentWaiver calldata,
        address,
        O.ReceiptWitness calldata
    ) external {
        Records.appendIntentWaiver(_states[id], msg.data);
    }

    function appendInterview(
        bytes32 id,
        StreamConservationRecordTypes.Interview calldata,
        address,
        O.ReceiptWitness calldata
    ) external {
        Interviews.appendInterview(_states[id], msg.data);
    }

    function appendInterviewWaiver(bytes32 id) external {
        Interviews.appendInterviewWaiver(_states[id], id);
    }

    function appendRootAuthorization(
        bytes32 id,
        address actor,
        uint64 observedAt,
        Root.Aggregate calldata originalAggregate,
        bytes32 originalLegacyFamilyHash,
        O.ReceiptWitness calldata receipt
    ) external {
        State.stage(_states[id], id, 6);
        T.Item[] memory rows = new T.Item[](1);
        O.RecordOrigin memory original;
        (rows[0], original) = RootCalls.scopedPolicyContentItem(
            _states[id].dependencies,
            _states[id].origins.dependencies,
            _states[id].contexts[id],
            actor,
            observedAt,
            originalAggregate,
            originalLegacyFamilyHash,
            _states[id].plans[id].progress.sourceContextHash,
            receipt
        );
        Origins.remember(
            _states[id].origins,
            id,
            _states[id].plans[id].progress.sourceContextHash,
            rows[0],
            original,
            bytes32(0),
            actor,
            keccak256("ORIGINAL_SCOPED_POLICY_CONTENT_ROOT_AUTHORIZATION_V2")
        );
        State.append(_states[id], id, rows, _states[id].contexts[id].rootRecordHash);
        _states[id].plans[id].progress.completedStages = 7;
    }

    function appendDefinition(bytes32 id) external {
        Definitions.appendDefinition(_states[id], id);
    }

    function appendTokenOutput(bytes32 id, Content.Payload calldata payload) external {
        Tokens.appendOutput(_states[id], id, payload);
    }

    function appendTokenScript(bytes32 id) external {
        Tokens.appendScript(_states[id], id, false);
    }

    function appendTokenLibrary(bytes32 id) external {
        Tokens.appendScript(_states[id], id, true);
    }

    function appendTokenRenderer(bytes32 id) external {
        Tokens.appendRenderer(_states[id], id);
    }

    function appendTokenCitation(bytes32 id) external {
        Tokens.appendCitation(_states[id], id);
    }

    function sealInventory(bytes32 id) external returns (Scoped.Evidence memory evidence) {
        State.stage(_states[id], id, 8);
        T.Plan storage p = _states[id].plans[id].progress;
        Scoped.TokenProgress storage token = _states[id].tokenProgress[id];
        if (p.nextToken != p.tokenCount || token.phase != 0 || token.row != 0 || token.count != 0) {
            revert T.InventoryIncomplete();
        }
        Definitions.requireDefinitions(_states[id], id, false);
        bytes32 originRoot = Origins.seal(_states[id].origins, id);
        evidence = _evidence(id);
        evidence.inventory.renderCriticalEvidenceHash = keccak256(
            abi.encode(
                D.SCOPED_POLICY_INVENTORY_PROFILE,
                block.chainid,
                address(this),
                _states[id].dependencyHash,
                _states[id].authority.capture.selection.selectionHash,
                evidence,
                originRoot,
                _states[id].origins.origins[id].length
            )
        );
        p.renderCriticalEvidenceHash = evidence.inventory.renderCriticalEvidenceHash;
        _states[id].completed[id] = evidence;
        emit ScopedInventoryCompleted(
            2, id, evidence.inventory.renderCriticalEvidenceHash, evidence
        );
    }

    function plan(bytes32 id) external view returns (Scoped.Plan memory) {
        return _states[id].plans[id];
    }

    function tokenProgress(bytes32 id) external view returns (Scoped.TokenProgress memory) {
        return _states[id].tokenProgress[id];
    }

    function sourceContext(bytes32 id) external view returns (Scoped.Context memory) {
        if (_states[id].plans[id].progress.collectionId == 0) revert T.InventoryIncomplete();
        return _states[id].contexts[id];
    }

    function inventorySegment(bytes32 id, uint64 index) external view returns (T.Segment memory) {
        if (index >= _states[id].plans[id].progress.segmentCount) {
            revert T.InvalidInventorySegment();
        }
        return _states[id].segments[id][index];
    }

    function inventoryEvidence(bytes32 id) external view returns (Scoped.Evidence memory e) {
        e = _states[id].completed[id];
        if (e.inventory.renderCriticalEvidenceHash == 0) revert T.InventoryIncomplete();
    }

    function requireCurrent(StreamFinalityScope calldata scope)
        external
        view
        returns (Scoped.Evidence memory e)
    {
        D.Capture memory captured = Authority.resolve(_config);
        (Scoped.Context memory c,,, bytes32 lineageHash) =
            Sources.current(captured.dependencies, _originDependencies, scope);
        bytes32 id = State.idFor(_dependencyHash, captured, c, lineageHash);
        e = _states[id].completed[id];
        if (e.inventory.renderCriticalEvidenceHash == 0) revert T.InventoryIncomplete();
        State.requireCurrent(_states[id], id);
        Origins.requirePins(_states[id].origins, id);
        Definitions.requireDefinitions(_states[id], id, false);
    }

    function requireFullDefinitionBytes(bytes32 id) external view {
        if (_states[id].completed[id].inventory.renderCriticalEvidenceHash == 0) {
            revert T.InventoryIncomplete();
        }
        State.requireCurrent(_states[id], id);
        Definitions.requireDefinitions(_states[id], id, true);
    }

    function _evidence(bytes32 id) private view returns (Scoped.Evidence memory result) {
        Scoped.Context storage c = _states[id].contexts[id];
        T.Plan storage p = _states[id].plans[id].progress;
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
        return _originDependencies;
    }

    function originProfile() external pure returns (bytes32) {
        return D.SCOPED_POLICY_INVENTORY_PROFILE;
    }

    function originCount(bytes32 id) external view returns (uint256) {
        return _states[id].origins.origins[id].length;
    }

    function originAt(bytes32 id, uint256 index) external view returns (O.Origin memory) {
        if (index >= _states[id].origins.origins[id].length) revert O.InvalidArchiveOrigin();
        return _states[id].origins.origins[id][index];
    }

    function originSetHash(bytes32 id) external view returns (bytes32) {
        return _states[id].origins.sealedRoot[id];
    }

    function artistArchiveOrigin(bytes32 id, bytes32 itemHash)
        external
        view
        returns (O.RecordOrigin memory original)
    {
        original = _states[id].origins.records[id][itemHash];
        if (original.sourceContextHash == 0) revert O.InvalidArchiveOrigin();
    }

    function originRuntimeCursor(bytes32 id) external view returns (uint256) {
        return _states[id].origins.runtimeCursor[id];
    }

    function appendOriginRuntime(bytes32 id) external {
        State.stage(_states[id], id, 8);
        T.Plan storage p = _states[id].plans[id].progress;
        Scoped.TokenProgress storage token = _states[id].tokenProgress[id];
        if (p.nextToken != p.tokenCount || token.phase != 0 || token.row != 0 || token.count != 0) {
            revert T.InventoryIncomplete();
        }
        (T.Item[] memory rows, bytes32 witness) = Origins.runtimeItems(_states[id].origins, id);
        State.append(_states[id], id, rows, witness);
    }

    function originalAnchor() external view returns (S.Dependencies memory) {
        return _config.originalAnchor;
    }

    function authorityDependencies() external view returns (D.Dependencies memory) {
        return _config.authority;
    }

    function authoritySelection(bytes32 id) external view returns (D.Capture memory captured) {
        captured = _states[id].authority.capture;
        if (captured.selection.selectionHash == 0) revert T.InventoryIncomplete();
    }
}
