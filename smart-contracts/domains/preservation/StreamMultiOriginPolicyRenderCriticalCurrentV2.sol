// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import { StreamMultiOriginInventoryState as Origins } from "./StreamMultiOriginInventoryState.sol";
import {
    StreamMultiOriginPolicyInventoryGuardV2 as Guard
} from "./StreamMultiOriginPolicyInventoryGuardV2.sol";

import {
    StreamPolicyRenderCriticalStateV2 as State
} from "./StreamPolicyRenderCriticalStateV2.sol";
import {
    StreamMultiOriginPolicyRenderCriticalSourceReadsV2 as Sources
} from "./StreamMultiOriginPolicyRenderCriticalSourceReadsV2.sol";
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

library StreamMultiOriginPolicyRenderCriticalCurrentV2 {
    event InventoryCompleted(
        bytes32 indexed planId, bytes32 indexed renderCriticalEvidenceHash, T.Evidence evidence
    );

    function sealInventory(State.State storage s, Origins.State storage origins, bytes32 id)
        public
        returns (T.Evidence memory evidence)
    {
        State.stage(s, id, 8);
        T.Plan storage p = s.records.plans[id];
        if (
            p.nextToken != p.tokenCount || s.progress[id].phase != 0 || s.progress[id].row != 0
                || s.progress[id].count != 0
        ) revert T.InventoryIncomplete();
        C.Context memory now_ = Guard.requireCurrent(s, origins, id);
        bytes32 originRoot = Origins.seal(origins, id);
        Definitions.requireDefinitions(s, id, false);
        evidence = _evidence(id, now_, p);
        evidence.renderCriticalEvidenceHash = keccak256(
            abi.encode(
                O.POLICY_INVENTORY_PROFILE,
                block.chainid,
                address(this),
                s.records.dependencyHash,
                evidence,
                originRoot,
                origins.origins[id].length
            )
        );
        p.renderCriticalEvidenceHash = evidence.renderCriticalEvidenceHash;
        s.records.completed[id] = evidence;
        emit InventoryCompleted(id, evidence.renderCriticalEvidenceHash, evidence);
    }

    function requireCurrent(
        State.State storage s,
        Origins.State storage origins,
        uint256 collectionId
    ) public view returns (T.Evidence memory result) {
        (C.Context memory c,,, bytes32 lineageHash) = Sources.current(
            s.records.dependencies, origins.dependencies, collectionId
        );
        bytes32 id = Guard.planId(s.records.dependencyHash, c, lineageHash);
        result = s.records.completed[id];
        if (result.renderCriticalEvidenceHash == 0) revert T.InventoryIncomplete();
        Origins.requirePins(origins, id);
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
