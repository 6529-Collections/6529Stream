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

import {
    StreamMultiOriginInventoryCalls as OriginCalls
} from "./StreamMultiOriginInventoryCalls.sol";

import {
    IStreamArtistArchiveOriginInventory
} from "../../interfaces/stream/preservation/IStreamArtistArchiveOriginInventory.sol";

import {
    IStreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1
} from "../../interfaces/stream/preservation/IStreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalTypesV1 as Scoped
} from "../../interfaces/stream/preservation/StreamScopedPreservationPolicyRenderCriticalTypesV1.sol";
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
    IStreamPreservationPolicyContentCheckpointV1 as Content
} from "../../interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
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
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalStateV1 as State
} from "./StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalStateV1.sol";

import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalOriginalStagesV1 as Native
} from "./StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalOriginalStagesV1.sol";

import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalDescriptionStagesV1 as Descriptions
} from "./StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalDescriptionStagesV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalRecordStagesV1 as Records
} from "./StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalRecordStagesV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInterviewStageV1 as Interviews
} from "./StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInterviewStageV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalDefinitionStagesV1 as Definitions
} from "./StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalDefinitionStagesV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalTokenStagesV1 as Tokens
} from "./StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalTokenStagesV1.sol";

import {
    StreamCurrentAuthorityScopedPreservationPolicyInventoryBeginV1 as Begin
} from "./StreamCurrentAuthorityScopedPreservationPolicyInventoryBeginV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyInventoryViewsV1 as Views
} from "./StreamCurrentAuthorityScopedPreservationPolicyInventoryViewsV1.sol";

import {
    StreamCurrentAuthorityScopedPreservationPolicyInventoryFinishV1 as Finish
} from "./StreamCurrentAuthorityScopedPreservationPolicyInventoryFinishV1.sol";

import {
    StreamCurrentAuthorityScopedPreservationPolicyInventoryStagesV1 as Stages
} from "./StreamCurrentAuthorityScopedPreservationPolicyInventoryStagesV1.sol";

/// @notice Captured-current TOKEN/RELEASE/SEASON preservation inventory with original Artist receipts.
/// Every token completes all six fixed source families, including the preservation producer closure.
/// @dev Permissionless preparation confers no Artist, publication, archive or finality authority.
/// Constructor-only storage avoids a runtime hash cycle with the eventual fixed provider.
contract StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1 is
    IStreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1,
    IStreamCurrentAuthorityInventory
{
    mapping(bytes32 => State.State) private _states;
    Authority.Config private _config;
    O.Dependencies private _originDependencies;
    bytes32 private _dependencyHash;

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id
                == type(IStreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1)
                .interfaceId || id == type(IStreamArtistArchiveOriginInventory).interfaceId
            || id == type(IStreamCurrentAuthorityInventory).interfaceId || id == 0x01ffc9a7;
    }

    function scopedPreservationPolicyInventoryProfile() external pure returns (bytes32) {
        return D.SCOPED_PRESERVATION_POLICY_INVENTORY_PROFILE;
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
        _dependencyHash =
            D.dependencyHash(D.SCOPED_PRESERVATION_POLICY_INVENTORY_PROFILE, d, od, ad);
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
        return Begin.beginInventory(_states, _config, _originDependencies, _dependencyHash, scope);
    }

    function appendNative(bytes32 id, uint64 maximum) external {
        Native.appendNative(_states[id], id, maximum);
    }

    function appendReference(bytes32 id, uint64 maximum) external {
        Stages.appendReference(_states[id], id, maximum);
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
        Stages.appendRootAuthorization(
            _states[id], id, actor, observedAt, originalAggregate, originalLegacyFamilyHash, receipt
        );
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

    function appendTokenPreservation(bytes32 id) external {
        Tokens.appendPreservation(_states[id], id);
    }

    function sealInventory(bytes32 id) external returns (Scoped.Evidence memory evidence) {
        return Finish.sealInventory(_states[id], id);
    }

    function plan(bytes32 id) external view returns (Scoped.Plan memory) {
        return _states[id].plans[id];
    }

    function tokenProgress(bytes32 id) external view returns (Scoped.TokenProgress memory) {
        return _states[id].tokenProgress[id];
    }

    function sourceContext(bytes32 id) external view returns (Scoped.Context memory) {
        // Return the already encoded original tuple without a second bytes envelope.
        bytes memory encoded = Views.sourceContext(_states[id], id);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
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
        // Return the already encoded original tuple without a second bytes envelope.
        bytes memory encoded =
            Views.requireCurrent(_states, _config, _originDependencies, _dependencyHash, scope);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function requireFullDefinitionBytes(bytes32 id) external view {
        Views.requireFullDefinitionBytes(_states[id], id);
    }

    function originDependencies() external view returns (O.Dependencies memory) {
        return _originDependencies;
    }

    function originProfile() external pure returns (bytes32) {
        return D.SCOPED_PRESERVATION_POLICY_INVENTORY_PROFILE;
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
        Finish.appendOriginRuntime(_states[id], id);
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
