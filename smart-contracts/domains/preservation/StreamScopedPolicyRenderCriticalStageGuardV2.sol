// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamScopedPolicyRenderCriticalStateV2 as State
} from "./StreamScopedPolicyRenderCriticalStateV2.sol";

/// @dev Fixed linked guard retains the host storage root and current-context commitment.
library StreamScopedPolicyRenderCriticalStageGuardV2 {
    function stage(State.State storage state, bytes32 id, uint16 expected) public view {
        State.stage(state, id, expected);
    }
}
