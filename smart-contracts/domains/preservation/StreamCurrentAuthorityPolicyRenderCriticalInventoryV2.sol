// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamMultiOriginPolicyRenderCriticalSourceReadsV2 as OriginSources
} from "./StreamMultiOriginPolicyRenderCriticalSourceReadsV2.sol";
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
    StreamCurrentAuthorityPolicyInventoryGuardV2 as Guard
} from "./StreamCurrentAuthorityPolicyInventoryGuardV2.sol";
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
    StreamCurrentAuthorityPolicyRenderCriticalCurrentV2 as Current
} from "./StreamCurrentAuthorityPolicyRenderCriticalCurrentV2.sol";
import {
    StreamPolicyRenderCriticalContextV2 as ContextRead
} from "./StreamPolicyRenderCriticalContextV2.sol";

/// @notice Distinct complete COLLECTION V2 inventory, including each full current STATIC output.
/// @dev Permissionless materialization confers no publication or signing authority. Every
/// source already has an authenticated original. No finality provider, final manifest or
/// sanction record enters this dependency graph or the independent evidence preimage.
contract StreamCurrentAuthorityPolicyRenderCriticalInventoryV2 is
    IStreamPolicyRenderCriticalInventoryV2,
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
        _dependencyHash = D.dependencyHash(D.POLICY_INVENTORY_PROFILE, d, od, ad);
        OriginCalls.pin(od);
        _origins.dependencies = od;
    }

    function policyInventoryProfile() external pure override returns (bytes32) {
        return D.POLICY_INVENTORY_PROFILE;
    }

    function dependencyHash() external view override returns (bytes32) {
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

    function dependencies() external view override returns (S.Dependencies memory) {
        return _config.originalAnchor;
    }

    function beginInventory(uint256 collectionId) external returns (bytes32 id) {
        D.Capture memory captured = Authority.resolve(_config);
        (
            C.Context memory c,
            O.Origin memory current,
            O.Origin memory presented,
            bytes32 lineageHash
        ) = OriginSources.current(captured.dependencies, _origins.dependencies, collectionId);
        id = Guard.planId(_dependencyHash, captured, c, lineageHash);
        if (_states[id].records.plans[id].collectionId != 0) return id;
        Authority.remember(_authorities[id], _config, captured);
        _states[id].records.dependencies = captured.dependencies;
        _states[id].records.dependencyHash = _dependencyHash;
        Origins.initialize(_origins, id, current, presented, lineageHash);
        _states[id].contexts[id] = c;
        _states[id].records.contexts[id] = c.records;
        T.Plan storage p = _states[id].records.plans[id];
        p.collectionId = collectionId;
        p.subject = c.records.subject;
        p.artistId = c.records.artistId;
        p.sourceContextHash = D.contextHash(captured, keccak256(abi.encode(c)), lineageHash);
        p.tokenCount = c.records.tokenCount;
        emit InventoryStarted(id, collectionId, p.sourceContextHash);
    }

    function appendNative(bytes32 id) external {
        Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
        OriginalsV2.appendNative(_states[id], id);
    }

    function appendReference(bytes32 id) external {
        Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
        OriginalsV2.appendReference(_states[id], id);
    }

    function appendWork(
        bytes32 id,
        StreamWorkRecordTypes.Description calldata,
        address,
        O.ReceiptWitness calldata
    ) external {
        Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
        Common.appendWork(_states[id], _origins, msg.data);
    }

    function appendRights(bytes32 id, StreamRightsRecordTypes.Statement calldata) external {
        Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
        Common.appendRights(_states[id], msg.data);
    }

    function appendIntent(
        bytes32 id,
        StreamConservationRecordTypes.Intent calldata,
        address,
        O.ReceiptWitness calldata
    ) external {
        Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
        Common.appendIntent(_states[id], _origins, msg.data);
    }

    function appendIntentWaiver(
        bytes32 id,
        StreamConservationRecordTypes.IntentWaiver calldata,
        address,
        O.ReceiptWitness calldata
    ) external {
        Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
        Common.appendIntentWaiver(_states[id], _origins, msg.data);
    }

    function appendInterview(
        bytes32 id,
        StreamConservationRecordTypes.Interview calldata,
        address,
        O.ReceiptWitness calldata
    ) external {
        Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
        Common.appendInterview(_states[id], _origins, msg.data);
    }

    function appendInterviewWaiver(bytes32 id) external {
        Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
        Common.appendInterviewWaiver(_states[id], id);
    }

    function appendRootAuthorization(
        bytes32 id,
        address actor,
        uint64 observedAt,
        Aggregate.Aggregate calldata originalAggregate,
        O.ReceiptWitness calldata receipt
    ) external {
        Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
        State.stage(_states[id], id, 6);
        T.Item[] memory rows = new T.Item[](1);
        O.RecordOrigin memory original;
        (rows[0], original) = RootCalls.policyContentItem(
            _states[id].records.dependencies,
            _origins.dependencies,
            _states[id].contexts[id],
            actor,
            observedAt,
            originalAggregate,
            _states[id].records.plans[id].sourceContextHash,
            receipt
        );
        Origins.remember(
            _origins,
            id,
            _states[id].records.plans[id].sourceContextHash,
            rows[0],
            original,
            bytes32(0),
            actor,
            keccak256("ORIGINAL_POLICY_CONTENT_ROOT_AUTHORIZATION_V2")
        );
        State.append(_states[id], id, rows, _states[id].contexts[id].records.rootRecordHash);
        _states[id].records.plans[id].completedStages = 7;
    }

    function appendDefinition(bytes32 id) external {
        Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
        StreamPolicyRenderCriticalDefinitionStagesV2.appendDefinition(_states[id], id);
    }

    function appendToken(bytes32 id, Content.Payload calldata payload) external {
        Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
        Tokens.appendOutput(_states[id], id, payload);
    }

    function appendScript(bytes32 id) external {
        Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
        Tokens.appendScript(_states[id], id, false);
    }

    function appendLibrary(bytes32 id) external {
        Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
        Tokens.appendScript(_states[id], id, true);
    }

    function appendRenderer(bytes32 id) external {
        Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
        Tokens.appendRenderer(_states[id], id);
    }

    function appendCurrentProfile(bytes32 id) external {
        Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
        Tokens.appendProfile(_states[id], id);
    }

    function tokenProgress(bytes32 id) external view returns (State.Progress memory) {
        return _states[id].progress[id];
    }

    function sealInventory(bytes32 id) external returns (T.Evidence memory) {
        return Current.sealInventory(_states[id], _origins, _authorities[id], id);
    }

    function inventoryEvidence(bytes32 id)
        external
        view
        override
        returns (T.Evidence memory result)
    {
        result = _states[id].records.completed[id];
        if (result.renderCriticalEvidenceHash == 0) revert T.InventoryIncomplete();
    }

    function inventorySegment(bytes32 id, uint64 index)
        external
        view
        override
        returns (T.Segment memory)
    {
        if (index >= _states[id].records.plans[id].segmentCount) {
            revert T.InvalidInventorySegment();
        }
        return _states[id].records.segments[id][index];
    }

    function plan(bytes32 id) external view returns (T.Plan memory) {
        return _states[id].records.plans[id];
    }

    function sourceContext(bytes32 id) external view returns (C.Context memory) {
        bytes memory raw = ContextRead.encoded(_states[id], id);
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }

    function requireCurrent(uint256 collectionId)
        external
        view
        override
        returns (T.Evidence memory result)
    {
        D.Capture memory captured = Authority.resolve(_config);
        (C.Context memory c,,, bytes32 lineageHash) =
            OriginSources.current(captured.dependencies, _origins.dependencies, collectionId);
        bytes32 id = Guard.planId(_dependencyHash, captured, c, lineageHash);
        result = _states[id].records.completed[id];
        if (result.renderCriticalEvidenceHash == 0) revert T.InventoryIncomplete();
        Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
        Origins.requirePins(_origins, id);
        StreamPolicyRenderCriticalDefinitionStagesV2.requireDefinitions(_states[id], id, false);
    }

    /// @notice Stronger diagnostic reconstructing all full bytes, including artificial code edits.
    function requireFullDefinitionBytes(bytes32 id) external view {
        if (_states[id].records.completed[id].renderCriticalEvidenceHash == 0) {
            revert T.InventoryIncomplete();
        }
        Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
        StreamPolicyRenderCriticalDefinitionStagesV2.requireDefinitions(_states[id], id, true);
    }

    function originDependencies() external view returns (O.Dependencies memory) {
        return _origins.dependencies;
    }

    function originProfile() external pure returns (bytes32) {
        return D.POLICY_INVENTORY_PROFILE;
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
        State.stage(_states[id], id, 8);
        Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
        T.Plan storage p = _states[id].records.plans[id];
        State.Progress storage token = _states[id].progress[id];
        if (p.nextToken != p.tokenCount || token.phase != 0 || token.row != 0 || token.count != 0) {
            revert T.InventoryIncomplete();
        }
        (T.Item[] memory rows, bytes32 witness) = Origins.runtimeItems(_origins, id);
        State.append(_states[id], id, rows, witness);
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
