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
    StreamPreservationPolicyRenderCriticalTypesV1 as C
} from "../../interfaces/stream/preservation/StreamPreservationPolicyRenderCriticalTypesV1.sol";
import {
    StreamPreservationPolicyRenderCriticalStateV1 as State
} from "./StreamPreservationPolicyRenderCriticalStateV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import { StreamMultiOriginInventoryState as Origins } from "./StreamMultiOriginInventoryState.sol";
import {
    StreamCurrentAuthorityPreservationPolicyRenderCriticalSourceReadsV1 as Sources
} from "./StreamCurrentAuthorityPreservationPolicyRenderCriticalSourceReadsV1.sol";

library StreamCurrentAuthorityPreservationPolicyInventoryGuardV1 {
    function planId(
        bytes32 dependencyHash,
        D.Capture memory captured,
        C.Context memory c,
        bytes32 lineageHash
    ) public view returns (bytes32) {
        return D.planId(
            D.PRESERVATION_POLICY_INVENTORY_PROFILE,
            dependencyHash,
            D.contextHash(captured, keccak256(abi.encode(c)), lineageHash)
        );
    }

    function requireCurrent(
        State.State storage s,
        Origins.State storage origins,
        Authority.State storage authority,
        bytes32 id
    ) public view returns (C.Context memory c) {
        Authority.requireCurrent(authority);
        if (s.records.plans[id].collectionId == 0) revert T.InventoryIncomplete();
        bytes32 lineageHash;
        (c,,, lineageHash) = Sources.current(
            s.records.dependencies, origins.dependencies, s.records.plans[id].collectionId
        );
        if (
            lineageHash != origins.lineage[id]
                || planId(s.records.dependencyHash, authority.capture, c, lineageHash) != id
                || D.contextHash(authority.capture, keccak256(abi.encode(c)), lineageHash)
                    != s.records.plans[id].sourceContextHash
        ) revert T.InventorySourceChanged();
    }
}
