// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../../interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";

import { StreamMultiOriginInventoryState as Origins } from "./StreamMultiOriginInventoryState.sol";

import {
    StreamScopedPolicyRenderCriticalTypesV2 as Scoped
} from "../../interfaces/stream/preservation/StreamScopedPolicyRenderCriticalTypesV2.sol";

import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";

import {
    IStreamConservationRecordSelection as Conservation
} from "../../interfaces/stream/metadata/IStreamConservationRecordSelection.sol";
import {
    StreamCurrentAuthorityScopedPolicyRenderCriticalStateV2 as State
} from "./StreamCurrentAuthorityScopedPolicyRenderCriticalStateV2.sol";

import {
    StreamCurrentAuthorityScopedPolicyRenderCriticalDefinitionStagesV2 as Definitions
} from "./StreamCurrentAuthorityScopedPolicyRenderCriticalDefinitionStagesV2.sol";

/// @notice Fixed linked operations retain the original host storage and domains.
library StreamCurrentAuthorityScopedPolicyInventoryFinishV2 {
    event ScopedInventoryCompleted(
        uint16 schemaVersion,
        bytes32 indexed id,
        bytes32 indexed evidenceHash,
        Scoped.Evidence evidence
    );

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

    function appendOriginRuntime(mapping(bytes32 => State.State) storage _states, bytes32 id)
        public
    {
        State.stage(_states[id], id, 8);
        T.Plan storage p = _states[id].plans[id].progress;
        Scoped.TokenProgress storage token = _states[id].tokenProgress[id];
        if (p.nextToken != p.tokenCount || token.phase != 0 || token.row != 0 || token.count != 0) {
            revert T.InventoryIncomplete();
        }
        (T.Item[] memory rows, bytes32 witness) = Origins.runtimeItems(_states[id].origins, id);
        State.append(_states[id], id, rows, witness);
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
