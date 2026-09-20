// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamPolicyRenderCriticalTypesV2 as C
} from "../../interfaces/stream/preservation/StreamPolicyRenderCriticalTypesV2.sol";
import {
    StreamPolicyRenderCriticalStateV2 as State
} from "./StreamPolicyRenderCriticalStateV2.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import { StreamMultiOriginInventoryState as Origins } from "./StreamMultiOriginInventoryState.sol";
import {
    StreamMultiOriginPolicyRenderCriticalSourceReadsV2 as Sources
} from "./StreamMultiOriginPolicyRenderCriticalSourceReadsV2.sol";

library StreamMultiOriginPolicyInventoryGuardV2 {
    function planId(bytes32 dependencyHash, C.Context memory c, bytes32 lineageHash)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                O.POLICY_INVENTORY_PROFILE,
                block.chainid,
                address(this),
                dependencyHash,
                c,
                lineageHash
            )
        );
    }

    function requireCurrent(State.State storage s, Origins.State storage origins, bytes32 id)
        public
        view
        returns (C.Context memory c)
    {
        if (s.records.plans[id].collectionId == 0) revert T.InventoryIncomplete();
        bytes32 lineageHash;
        (c,,, lineageHash) = Sources.current(
            s.records.dependencies, origins.dependencies, s.records.plans[id].collectionId
        );
        if (
            lineageHash != origins.lineage[id]
                || planId(s.records.dependencyHash, c, lineageHash) != id
                || keccak256(abi.encode(c)) != s.records.plans[id].sourceContextHash
        ) revert T.InventorySourceChanged();
    }
}
