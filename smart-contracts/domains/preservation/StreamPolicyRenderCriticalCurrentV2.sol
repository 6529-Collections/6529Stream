// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPolicyRenderCriticalStateV2 as State
} from "./StreamPolicyRenderCriticalStateV2.sol";
import {
    StreamPolicyRenderCriticalSourceReadsV2 as Sources
} from "./StreamPolicyRenderCriticalSourceReadsV2.sol";
import {
    StreamPolicyRenderCriticalDefinitionStagesV2 as Definitions
} from "./StreamPolicyRenderCriticalDefinitionStagesV2.sol";
import {
    StreamPolicyRenderCriticalTypesV2 as C
} from "../../interfaces/stream/preservation/StreamPolicyRenderCriticalTypesV2.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    IStreamConservationRecordSelection
} from "../../interfaces/stream/metadata/IStreamConservationRecordSelection.sol";

library StreamPolicyRenderCriticalCurrentV2 {
    event InventoryCompleted(
        bytes32 indexed planId, bytes32 indexed renderCriticalEvidenceHash, T.Evidence evidence
    );

    function sealInventory(State.State storage s, bytes32 id)
        public
        returns (T.Evidence memory evidence)
    {
        State.stage(s, id, 8);
        T.Plan storage p = s.records.plans[id];
        if (p.nextToken != p.tokenCount || s.progress[id].phase != 0) revert T.InventoryIncomplete();
        C.Context memory now_ = Sources.current(s.records.dependencies, p.collectionId);
        if (State.planId(s, now_) != id) revert T.InventorySourceChanged();
        Definitions.requireDefinitions(s, id, false);
        evidence = _evidence(id, now_, p);
        evidence.renderCriticalEvidenceHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_POLICY_RENDER_CRITICAL_EVIDENCE_V2"),
                block.chainid,
                address(this),
                s.records.dependencyHash,
                evidence
            )
        );
        p.renderCriticalEvidenceHash = evidence.renderCriticalEvidenceHash;
        s.records.completed[id] = evidence;
        emit InventoryCompleted(id, evidence.renderCriticalEvidenceHash, evidence);
    }

    function requireCurrent(State.State storage s, uint256 collectionId)
        public
        view
        returns (T.Evidence memory result)
    {
        bytes32 id = State.planId(s, Sources.current(s.records.dependencies, collectionId));
        result = s.records.completed[id];
        if (result.renderCriticalEvidenceHash == 0) revert T.InventoryIncomplete();
        Definitions.requireDefinitions(s, id, false);
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
