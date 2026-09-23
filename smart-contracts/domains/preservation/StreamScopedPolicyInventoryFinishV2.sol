// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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
    StreamScopedPolicyRenderCriticalStateV2 as State
} from "./StreamScopedPolicyRenderCriticalStateV2.sol";

import {
    StreamScopedPolicyRenderCriticalDefinitionStagesV2 as Definitions
} from "./StreamScopedPolicyRenderCriticalDefinitionStagesV2.sol";

/// @notice Fixed linked operations retain the original host storage and domains.
library StreamScopedPolicyInventoryFinishV2 {
    event ScopedInventoryCompleted(
        uint16 schemaVersion,
        bytes32 indexed id,
        bytes32 indexed evidenceHash,
        Scoped.Evidence evidence
    );

    function sealInventory(State.State storage _state, bytes32 id)
        public
        returns (Scoped.Evidence memory evidence)
    {
        State.stage(_state, id, 8);
        T.Plan storage p = _state.plans[id].progress;
        Scoped.TokenProgress storage token = _state.tokenProgress[id];
        if (p.nextToken != p.tokenCount || token.phase != 0 || token.row != 0 || token.count != 0) {
            revert T.InventoryIncomplete();
        }
        Definitions.requireDefinitions(_state, id, false);
        evidence = _evidence(_state, id);
        evidence.inventory.renderCriticalEvidenceHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_POLICY_RENDER_CRITICAL_EVIDENCE_V2"),
                block.chainid,
                address(this),
                _state.dependencyHash,
                evidence
            )
        );
        p.renderCriticalEvidenceHash = evidence.inventory.renderCriticalEvidenceHash;
        _state.completed[id] = evidence;
        emit ScopedInventoryCompleted(
            2, id, evidence.inventory.renderCriticalEvidenceHash, evidence
        );
    }

    function _evidence(State.State storage _state, bytes32 id)
        private
        view
        returns (Scoped.Evidence memory result)
    {
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
