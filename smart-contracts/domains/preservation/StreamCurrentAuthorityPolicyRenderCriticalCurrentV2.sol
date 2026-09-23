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
import { StreamMultiOriginInventoryState as Origins } from "./StreamMultiOriginInventoryState.sol";
import {
    StreamCurrentAuthorityPolicyInventoryEvidenceV2 as Evidence
} from "./StreamCurrentAuthorityPolicyInventoryEvidenceV2.sol";

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
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";

library StreamCurrentAuthorityPolicyRenderCriticalCurrentV2 {
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
        evidence = Evidence.current(s, origins, authority, id);
        bytes32 originRoot = Origins.seal(origins, id);
        Definitions.requireDefinitions(s, id, false);
        evidence.sourceContextHash = p.sourceContextHash;
        evidence.segmentCount = p.segmentCount;
        evidence.itemCount = p.itemCount;
        evidence.segmentChainHash = p.segmentChainHash;
        evidence.renderCriticalEvidenceHash = keccak256(
            abi.encode(
                D.POLICY_INVENTORY_PROFILE,
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
}
