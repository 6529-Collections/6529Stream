// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../../interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamCurrentAuthorityInventorySelection as Authority
} from "./StreamCurrentAuthorityInventorySelection.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import { StreamMultiOriginInventoryState as Origins } from "./StreamMultiOriginInventoryState.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamPolicyRenderCriticalStateV2 as State
} from "./StreamPolicyRenderCriticalStateV2.sol";
import {
    StreamCurrentAuthorityPolicyInventoryGuardV2 as Guard
} from "./StreamCurrentAuthorityPolicyInventoryGuardV2.sol";
import {
    StreamMultiOriginPolicyRenderCriticalSourceReadsV2 as OriginSources
} from "./StreamMultiOriginPolicyRenderCriticalSourceReadsV2.sol";
import {
    StreamPolicyRenderCriticalDefinitionStagesV2
} from "./StreamPolicyRenderCriticalDefinitionStagesV2.sol";
import {
    StreamPolicyRenderCriticalTypesV2 as C
} from "../../interfaces/stream/preservation/StreamPolicyRenderCriticalTypesV2.sol";

/// @dev Fixed linked worker; storage references and delegate context belong to the inventory host.
library StreamCurrentAuthorityPolicyInventoryLifecycleV2 {
    event InventoryStarted(
        bytes32 indexed planId, uint256 indexed collectionId, bytes32 sourceContextHash
    );
    event InventoryCompleted(
        bytes32 indexed planId, bytes32 indexed renderCriticalEvidenceHash, T.Evidence evidence
    );

    function beginInventory(
        mapping(bytes32 => State.State) storage _states,
        Origins.State storage _origins,
        mapping(bytes32 => Authority.State) storage _authorities,
        Authority.Config storage _config,
        bytes32 _dependencyHash,
        uint256 collectionId
    ) public returns (bytes32 id) {
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

    function requireCurrent(
        mapping(bytes32 => State.State) storage _states,
        Origins.State storage _origins,
        mapping(bytes32 => Authority.State) storage _authorities,
        Authority.Config storage _config,
        bytes32 _dependencyHash,
        uint256 collectionId
    ) public view returns (T.Evidence memory result) {
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

    function requireFullDefinitionBytes(
        mapping(bytes32 => State.State) storage _states,
        Origins.State storage _origins,
        mapping(bytes32 => Authority.State) storage _authorities,
        bytes32 id
    ) public view {
        if (_states[id].records.completed[id].renderCriticalEvidenceHash == 0) {
            revert T.InventoryIncomplete();
        }
        Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
        StreamPolicyRenderCriticalDefinitionStagesV2.requireDefinitions(_states[id], id, true);
    }

    function requirePlanCurrent(
        mapping(bytes32 => State.State) storage _states,
        Origins.State storage _origins,
        mapping(bytes32 => Authority.State) storage _authorities,
        bytes32 id
    ) public view {
        Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
    }
}
