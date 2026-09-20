// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamRenderCriticalInventoryState as State
} from "./StreamRenderCriticalInventoryState.sol";
import { StreamMultiOriginInventoryState as Origins } from "./StreamMultiOriginInventoryState.sol";
import { StreamMultiOriginSourceReads as Sources } from "./StreamMultiOriginSourceReads.sol";

library StreamMultiOriginInventoryGuard {
    function planId(bytes32 dependencyHash, S.Context memory c, bytes32 lineageHash)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                O.INVENTORY_PROFILE, block.chainid, address(this), dependencyHash, c, lineageHash
            )
        );
    }

    function requireCurrent(State.State storage state, Origins.State storage origins, bytes32 id)
        public
        view
        returns (S.Context memory c)
    {
        if (state.plans[id].collectionId == 0) revert T.InventoryIncomplete();
        bytes32 lineageHash;
        (c,,, lineageHash) =
            Sources.current(state.dependencies, origins.dependencies, state.plans[id].collectionId);
        if (
            lineageHash != origins.lineage[id] || planId(state.dependencyHash, c, lineageHash) != id
                || keccak256(abi.encode(c)) != state.plans[id].sourceContextHash
        ) revert T.InventorySourceChanged();
    }
}
