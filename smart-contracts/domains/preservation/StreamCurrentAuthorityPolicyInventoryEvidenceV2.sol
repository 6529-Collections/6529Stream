// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityInventorySelection as Authority
} from "./StreamCurrentAuthorityInventorySelection.sol";
import { StreamMultiOriginInventoryState as Origins } from "./StreamMultiOriginInventoryState.sol";
import {
    StreamCurrentAuthorityPolicyInventoryGuardV2 as Guard
} from "./StreamCurrentAuthorityPolicyInventoryGuardV2.sol";
import {
    StreamPolicyRenderCriticalStateV2 as State
} from "./StreamPolicyRenderCriticalStateV2.sol";
import {
    StreamPolicyRenderCriticalTypesV2 as C
} from "../../interfaces/stream/preservation/StreamPolicyRenderCriticalTypesV2.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    IStreamConservationRecordSelection
} from "../../interfaces/stream/metadata/IStreamConservationRecordSelection.sol";

/// @dev Fixed read frame: the full original currentness guard runs before projecting its result.
/// Plan storage fields are deliberately read by the caller after origin sealing and definitions.
library StreamCurrentAuthorityPolicyInventoryEvidenceV2 {
    function current(
        State.State storage s,
        Origins.State storage origins,
        Authority.State storage authority,
        bytes32 id
    ) public view returns (T.Evidence memory evidence) {
        C.Context memory now_ = Guard.requireCurrent(s, origins, authority, id);
        return _evidence(id, now_);
    }

    function _evidence(bytes32 id, C.Context memory c) private pure returns (T.Evidence memory e) {
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
        e.tokenInventoryHash = c.records.tokenInventoryHash;
        e.tokenCount = c.records.tokenCount;
    }
}
