// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../../interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";

import { StreamMultiOriginInventoryState as Origins } from "./StreamMultiOriginInventoryState.sol";

import {
    StreamScopedPreservationPolicyRenderCriticalTypesV1 as Scoped
} from "../../interfaces/stream/preservation/StreamScopedPreservationPolicyRenderCriticalTypesV1.sol";

import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";

import {
    IStreamConservationRecordSelection as Conservation
} from "../../interfaces/stream/metadata/IStreamConservationRecordSelection.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalStateV1 as State
} from "./StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalStateV1.sol";

import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalDefinitionStagesV1 as Definitions
} from "./StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalDefinitionStagesV1.sol";

/// @notice Fixed linked stages preserve original host storage, validation order and events.
library StreamCurrentAuthorityScopedPreservationPolicyInventoryFinishV1 {
    event ScopedInventoryCompleted(
        uint16 schemaVersion,
        bytes32 indexed id,
        bytes32 indexed evidenceHash,
        Scoped.Evidence evidence
    );

    function sealInventory(State.State storage state_, bytes32 id)
        public
        returns (Scoped.Evidence memory evidence)
    {
        State.stage(state_, id, 8);
        T.Plan storage p = state_.plans[id].progress;
        Scoped.TokenProgress storage token = state_.tokenProgress[id];
        if (p.nextToken != p.tokenCount || token.phase != 0 || token.row != 0 || token.count != 0) {
            revert T.InventoryIncomplete();
        }
        Definitions.requireDefinitions(state_, id, false);
        bytes32 originRoot = Origins.seal(state_.origins, id);
        evidence = _evidence(state_, id);
        evidence.inventory.renderCriticalEvidenceHash = keccak256(
            abi.encode(
                D.SCOPED_PRESERVATION_POLICY_INVENTORY_PROFILE,
                block.chainid,
                address(this),
                state_.dependencyHash,
                state_.authority.capture.selection.selectionHash,
                evidence,
                originRoot,
                state_.origins.origins[id].length
            )
        );
        p.renderCriticalEvidenceHash = evidence.inventory.renderCriticalEvidenceHash;
        state_.completed[id] = evidence;
        emit ScopedInventoryCompleted(
            1, id, evidence.inventory.renderCriticalEvidenceHash, evidence
        );
    }

    function _evidence(State.State storage state_, bytes32 id)
        private
        view
        returns (Scoped.Evidence memory result)
    {
        Scoped.Context storage c = state_.contexts[id];
        T.Plan storage p = state_.plans[id].progress;
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

    function appendOriginRuntime(State.State storage state_, bytes32 id) public {
        State.stage(state_, id, 8);
        T.Plan storage p = state_.plans[id].progress;
        Scoped.TokenProgress storage token = state_.tokenProgress[id];
        if (p.nextToken != p.tokenCount || token.phase != 0 || token.row != 0 || token.count != 0) {
            revert T.InventoryIncomplete();
        }
        (T.Item[] memory rows, bytes32 witness) = Origins.runtimeItems(state_.origins, id);
        State.append(state_, id, rows, witness);
    }
}
