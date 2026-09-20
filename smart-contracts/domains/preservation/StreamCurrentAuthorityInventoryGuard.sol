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

library StreamCurrentAuthorityInventoryGuard {
    function planId(
        bytes32 dependencyHash,
        D.Capture memory captured,
        S.Context memory c,
        bytes32 lineageHash
    ) public view returns (bytes32) {
        return D.planId(
            D.INVENTORY_PROFILE,
            dependencyHash,
            D.contextHash(captured, keccak256(abi.encode(c)), lineageHash)
        );
    }

    function requireCurrent(
        State.State storage state,
        Origins.State storage origins,
        Authority.State storage authority,
        bytes32 id
    ) public view returns (S.Context memory c) {
        Authority.requireCurrent(authority);
        if (state.plans[id].collectionId == 0) revert T.InventoryIncomplete();
        bytes32 lineageHash;
        (c,,, lineageHash) =
            Sources.current(state.dependencies, origins.dependencies, state.plans[id].collectionId);
        if (
            lineageHash != origins.lineage[id]
                || planId(state.dependencyHash, authority.capture, c, lineageHash) != id
                || D.contextHash(authority.capture, keccak256(abi.encode(c)), lineageHash)
                    != state.plans[id].sourceContextHash
        ) revert T.InventorySourceChanged();
    }
}
