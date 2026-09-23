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
    StreamRenderCriticalInventoryState as State
} from "./StreamRenderCriticalInventoryState.sol";
import {
    StreamCurrentAuthorityInventoryGuard as Guard
} from "./StreamCurrentAuthorityInventoryGuard.sol";
import { StreamMultiOriginSourceReads as OriginSources } from "./StreamMultiOriginSourceReads.sol";
import { StreamRenderCriticalDefinitionStages } from "./StreamRenderCriticalDefinitionStages.sol";
import "../../interfaces/stream/metadata/IStreamConservationRecordSelection.sol";

/// @dev Fixed linked worker; storage references and delegate context belong to the inventory host.
library StreamCurrentAuthorityInventoryLifecycle {
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
            S.Context memory c,
            O.Origin memory current,
            O.Origin memory presented,
            bytes32 lineageHash
        ) = OriginSources.current(captured.dependencies, _origins.dependencies, collectionId);
        id = Guard.planId(_dependencyHash, captured, c, lineageHash);
        if (_states[id].plans[id].collectionId != 0) return id;
        Authority.remember(_authorities[id], _config, captured);
        _states[id].dependencies = captured.dependencies;
        _states[id].dependencyHash = _dependencyHash;
        Origins.initialize(_origins, id, current, presented, lineageHash);
        _states[id].contexts[id] = c;
        T.Plan storage p = _states[id].plans[id];
        p.collectionId = collectionId;
        p.subject = c.subject;
        p.artistId = c.artistId;
        p.sourceContextHash = D.contextHash(captured, keccak256(abi.encode(c)), lineageHash);
        p.tokenCount = c.tokenCount;
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
        (S.Context memory c,,, bytes32 lineageHash) =
            OriginSources.current(captured.dependencies, _origins.dependencies, collectionId);
        bytes32 id = Guard.planId(_dependencyHash, captured, c, lineageHash);
        result = _states[id].completed[id];
        if (result.renderCriticalEvidenceHash == 0) revert T.InventoryIncomplete();
        Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
        Origins.requirePins(_origins, id);
        StreamRenderCriticalDefinitionStages.requireDefinitions(_states[id], id, false);
    }

    function requireFullDefinitionBytes(
        mapping(bytes32 => State.State) storage _states,
        Origins.State storage _origins,
        mapping(bytes32 => Authority.State) storage _authorities,
        bytes32 id
    ) public view {
        if (_states[id].completed[id].renderCriticalEvidenceHash == 0) {
            revert T.InventoryIncomplete();
        }
        Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
        StreamRenderCriticalDefinitionStages.requireDefinitions(_states[id], id, true);
    }

    function sealInventory(
        mapping(bytes32 => State.State) storage _states,
        Origins.State storage _origins,
        mapping(bytes32 => Authority.State) storage _authorities,
        bytes32 id
    ) public returns (T.Evidence memory evidence) {
        stage(_states, _origins, _authorities, id, 8);
        T.Plan storage p = _states[id].plans[id];
        if (p.nextToken != p.tokenCount) revert T.InventoryIncomplete();
        S.Context memory now_ = Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
        bytes32 originRoot = Origins.seal(_origins, id);
        StreamRenderCriticalDefinitionStages.requireDefinitions(_states[id], id, false);
        evidence = _evidence(id, now_, p);
        evidence.renderCriticalEvidenceHash = keccak256(
            abi.encode(
                D.INVENTORY_PROFILE,
                block.chainid,
                address(this),
                _states[id].dependencyHash,
                _authorities[id].capture.selection.selectionHash,
                evidence,
                originRoot,
                _origins.origins[id].length
            )
        );
        p.renderCriticalEvidenceHash = evidence.renderCriticalEvidenceHash;
        _states[id].completed[id] = evidence;
        emit InventoryCompleted(id, evidence.renderCriticalEvidenceHash, evidence);
    }

    function stage(
        mapping(bytes32 => State.State) storage _states,
        Origins.State storage _origins,
        mapping(bytes32 => Authority.State) storage _authorities,
        bytes32 id,
        uint16 stage_
    ) public view {
        T.Plan storage p = _states[id].plans[id];
        if (p.collectionId == 0 || p.completedStages != stage_ || p.renderCriticalEvidenceHash != 0)
        revert T.InventoryIncomplete();
        Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
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
