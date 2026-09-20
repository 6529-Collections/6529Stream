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

import { StreamMultiOriginInventoryState as Origins } from "./StreamMultiOriginInventoryState.sol";
import {
    StreamCurrentAuthorityPreservationPolicyInventoryGuardV1 as Guard
} from "./StreamCurrentAuthorityPreservationPolicyInventoryGuardV1.sol";

import {
    StreamPreservationPolicyRenderCriticalStateV1 as State
} from "./StreamPreservationPolicyRenderCriticalStateV1.sol";
import {
    StreamPreservationPolicyRenderCriticalDefinitionStagesV1 as Definitions
} from "./StreamPreservationPolicyRenderCriticalDefinitionStagesV1.sol";
import {
    StreamPreservationPolicyRenderCriticalTypesV1 as C
} from "../../interfaces/stream/preservation/StreamPreservationPolicyRenderCriticalTypesV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    IStreamConservationRecordSelection
} from "../../interfaces/stream/metadata/IStreamConservationRecordSelection.sol";

library StreamCurrentAuthorityPreservationPolicyRenderCriticalCurrentV1 {
    event InventoryCompleted(
        bytes32 indexed planId, bytes32 indexed renderCriticalEvidenceHash, T.Evidence evidence
    );

    function sealInventory(
        State.State storage s,
        Origins.State storage origins,
        Authority.State storage authority,
        bytes32 id
    ) public returns (T.Evidence memory evidence) {
        State.stage(s, id, 8);
        T.Plan storage p = s.records.plans[id];
        if (
            p.nextToken != p.tokenCount || s.progress[id].phase != 0 || s.progress[id].row != 0
                || s.progress[id].count != 0
        ) revert T.InventoryIncomplete();
        C.Context memory now_ = Guard.requireCurrent(s, origins, authority, id);
        bytes32 originRoot = Origins.seal(origins, id);
        Definitions.requireDefinitions(s, id, false);
        evidence = _evidence(id, now_, p);
        evidence.renderCriticalEvidenceHash = keccak256(
            abi.encode(
                D.PRESERVATION_POLICY_INVENTORY_PROFILE,
                block.chainid,
                address(this),
                s.records.dependencyHash,
                authority.capture.selection.selectionHash,
                evidence,
                originRoot,
                origins.origins[id].length
            )
        );
        p.renderCriticalEvidenceHash = evidence.renderCriticalEvidenceHash;
        s.records.completed[id] = evidence;
        emit InventoryCompleted(id, evidence.renderCriticalEvidenceHash, evidence);
    }

    function _evidence(bytes32 id, C.Context memory c, T.Plan storage p)
        private
        view
        returns (T.Evidence memory e)
    {
        e.planId = id;
        e.collectionId = c.records.collectionId;
        e.scopeSubject = c.records.subject;
        e.artistId = c.records.artistId;
        e.originals = T.OriginalInputs(
            c.records.rootRecordHash,
            c.snapshot.recordHash,
            c.referenceRender.observation.recordHash,
            c.records.conservation.record.kind
                == IStreamConservationRecordSelection.RecordKind.INTENT
                ? c.records.conservation.record.recordHash
                : bytes32(0),
            c.records.conservation.record.kind
                == IStreamConservationRecordSelection.RecordKind.INTENT_WAIVER
                ? c.records.conservation.record.recordHash
                : bytes32(0),
            c.records.interviewEvidenceHash,
            c.records.descriptions.rightsStatementRecordHash,
            c.records.descriptions.workDescriptionRecordHash
        );
        e.sourceContextHash = p.sourceContextHash;
        e.tokenInventoryHash = c.records.tokenInventoryHash;
        e.tokenCount = c.records.tokenCount;
        e.segmentCount = p.segmentCount;
        e.itemCount = p.itemCount;
        e.segmentChainHash = p.segmentChainHash;
    }
}
