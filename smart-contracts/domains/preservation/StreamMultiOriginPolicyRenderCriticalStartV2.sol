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
    StreamPolicyRenderCriticalTypesV2 as C
} from "../../interfaces/stream/preservation/StreamPolicyRenderCriticalTypesV2.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";

library StreamMultiOriginPolicyRenderCriticalStartV2 {
    event InventoryStarted(
        bytes32 indexed planId, uint256 indexed collectionId, bytes32 sourceContextHash
    );

    function begin(State.State storage s, Origins.State storage origins, uint256 collectionId)
        public
        returns (bytes32 id)
    {
        (
            C.Context memory c,
            O.Origin memory current,
            O.Origin memory presented,
            bytes32 lineageHash
        ) = Sources.current(s.records.dependencies, origins.dependencies, collectionId);
        id = Guard.planId(s.records.dependencyHash, c, lineageHash);
        if (s.records.plans[id].collectionId != 0) return id;
        Origins.initialize(origins, id, current, presented, lineageHash);
        s.contexts[id] = c;
        s.records.contexts[id] = c.records;
        T.Plan storage p = s.records.plans[id];
        p.collectionId = collectionId;
        p.subject = c.records.subject;
        p.artistId = c.records.artistId;
        p.sourceContextHash = keccak256(abi.encode(c));
        p.tokenCount = c.records.tokenCount;
        emit InventoryStarted(id, collectionId, p.sourceContextHash);
    }
}
