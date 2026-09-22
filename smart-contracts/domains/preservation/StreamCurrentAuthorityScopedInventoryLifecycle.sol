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
    StreamCurrentAuthorityScopedRenderCriticalState as State
} from "./StreamCurrentAuthorityScopedRenderCriticalState.sol";
import {
    StreamMultiOriginScopedRenderCriticalSourceReads as Sources
} from "./StreamMultiOriginScopedRenderCriticalSourceReads.sol";
import {
    StreamCurrentAuthorityScopedRenderCriticalDefinitionStages as Definitions
} from "./StreamCurrentAuthorityScopedRenderCriticalDefinitionStages.sol";
import {
    StreamScopedRenderCriticalTypes as Scoped
} from "../../interfaces/stream/preservation/StreamScopedRenderCriticalTypes.sol";
import {
    StreamFinalityScope
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    IStreamConservationRecordSelection as Conservation
} from "../../interfaces/stream/metadata/IStreamConservationRecordSelection.sol";

/// @dev Fixed linked worker; storage references and delegate context belong to the inventory host.
library StreamCurrentAuthorityScopedInventoryLifecycle {
    event ScopedInventoryStarted(
        uint16 schemaVersion, bytes32 indexed id, StreamFinalityScope scope, bytes32 contextHash
    );
    event ScopedInventoryCompleted(
        uint16 schemaVersion,
        bytes32 indexed id,
        bytes32 indexed evidenceHash,
        Scoped.Evidence evidence
    );

    function beginInventory(
        mapping(bytes32 => State.State) storage _states,
        Authority.Config storage _config,
        O.Dependencies storage _originDependencies,
        bytes32 _dependencyHash,
        StreamFinalityScope calldata scope
    ) public returns (bytes32 id) {
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
        emit ScopedInventoryStarted(1, id, scope, p.sourceContextHash);
    }

    function requireCurrent(
        mapping(bytes32 => State.State) storage _states,
        Authority.Config storage _config,
        O.Dependencies storage _originDependencies,
        bytes32 _dependencyHash,
        StreamFinalityScope calldata scope
    ) public view returns (Scoped.Evidence memory e) {
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

    function sealInventory(mapping(bytes32 => State.State) storage _states, bytes32 id)
        public
        returns (Scoped.Evidence memory evidence)
    {
        State.stage(_states[id], id, 8);
        T.Plan storage p = _states[id].plans[id].progress;
        Scoped.TokenProgress storage token = _states[id].tokenProgress[id];
        if (p.nextToken != p.tokenCount || token.phase != 0 || token.row != 0 || token.count != 0) {
            revert T.InventoryIncomplete();
        }
        Definitions.requireDefinitions(_states[id], id, false);
        bytes32 originRoot = Origins.seal(_states[id].origins, id);
        evidence = _evidence(_states, id);
        evidence.inventory.renderCriticalEvidenceHash = keccak256(
            abi.encode(
                D.SCOPED_INVENTORY_PROFILE,
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
            1, id, evidence.inventory.renderCriticalEvidenceHash, evidence
        );
    }

    function requireFullDefinitionBytes(mapping(bytes32 => State.State) storage _states, bytes32 id)
        public
        view
    {
        if (_states[id].completed[id].inventory.renderCriticalEvidenceHash == 0) {
            revert T.InventoryIncomplete();
        }
        State.requireCurrent(_states[id], id);
        Definitions.requireDefinitions(_states[id], id, true);
    }

    function _evidence(mapping(bytes32 => State.State) storage _states, bytes32 id)
        private
        view
        returns (Scoped.Evidence memory result)
    {
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
}
