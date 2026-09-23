// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalStateV1 as State
} from "./StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalStateV1.sol";

/// @dev Fixed linked guard retains this family's typed host storage and currentness checks.
library StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalStageGuardV1 {
    function stage(State.State storage state, bytes32 id, uint16 expected) public view {
        State.stage(state, id, expected);
    }
}
