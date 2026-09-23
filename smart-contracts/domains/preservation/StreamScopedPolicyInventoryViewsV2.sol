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

import {
    StreamScopedPolicyRenderCriticalDefinitionStagesV2 as Definitions
} from "./StreamScopedPolicyRenderCriticalDefinitionStagesV2.sol";

/// @notice Fixed linked operations retain the original host storage and domains.
library StreamScopedPolicyInventoryViewsV2 {
    function sourceContext(State.State storage _state, bytes32 id)
        public
        view
        returns (bytes memory)
    {
        if (_state.plans[id].progress.collectionId == 0) revert T.InventoryIncomplete();
        return abi.encode(_state.contexts[id]);
    }

    function requireCurrent(State.State storage _state, StreamFinalityScope calldata scope)
        public
        view
        returns (bytes memory)
    {
        Scoped.Evidence memory e;
        Scoped.Context memory c = Sources.current(_state.dependencies, scope);
        bytes32 id = State.idFor(_state.dependencyHash, c);
        e = _state.completed[id];
        if (e.inventory.renderCriticalEvidenceHash == 0) revert T.InventoryIncomplete();
        Definitions.requireDefinitions(_state, id, false);

        return abi.encode(e);
    }

    function requireFullDefinitionBytes(State.State storage _state, bytes32 id) public view {
        if (_state.completed[id].inventory.renderCriticalEvidenceHash == 0) {
            revert T.InventoryIncomplete();
        }
        State.requireCurrent(_state, id);
        Definitions.requireDefinitions(_state, id, true);
    }
}
