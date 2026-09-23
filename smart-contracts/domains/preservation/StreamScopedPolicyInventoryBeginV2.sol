// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamScopedPolicyRenderCriticalTypesV2 as Scoped
} from "../../interfaces/stream/preservation/StreamScopedPolicyRenderCriticalTypesV2.sol";

import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamFinalityScope
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

import {
    StreamScopedPolicyRenderCriticalStateV2 as State
} from "./StreamScopedPolicyRenderCriticalStateV2.sol";
import {
    StreamScopedPolicyRenderCriticalSourceReadsV2 as Sources
} from "./StreamScopedPolicyRenderCriticalSourceReadsV2.sol";

/// @notice Fixed linked operations retain the original host storage and domains.
library StreamScopedPolicyInventoryBeginV2 {
    event ScopedInventoryStarted(
        uint16 schemaVersion, bytes32 indexed id, StreamFinalityScope scope, bytes32 contextHash
    );

    function beginInventory(State.State storage _state, StreamFinalityScope calldata scope)
        public
        returns (bytes32 id)
    {
        Scoped.Context memory c = Sources.current(_state.dependencies, scope);
        id = State.idFor(_state.dependencyHash, c);
        if (_state.plans[id].progress.collectionId != 0) return id;
        _state.contexts[id] = c;
        Scoped.Plan storage plan_ = _state.plans[id];
        plan_.scope = scope;
        T.Plan storage p = plan_.progress;
        p.collectionId = scope.collectionId;
        p.subject = c.subject;
        p.artistId = c.artistId;
        p.sourceContextHash = keccak256(abi.encode(c));
        p.tokenCount = c.tokenCount;
        emit ScopedInventoryStarted(2, id, scope, p.sourceContextHash);
    }
}
