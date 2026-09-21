// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamScopedPreservationPolicyRenderCriticalStateV1 as State
} from "./StreamScopedPreservationPolicyRenderCriticalStateV1.sol";

/// @notice Fixed native-stage validation, retaining the original complete current-context hash.
/// @dev No context crosses this boundary; State.stage reads the exact caller-owned storage root.
library StreamScopedPreservationPolicyNativeStageV1 {
    function requireStage(State.State storage state, bytes32 id) public view {
        State.stage(state, id, 0);
    }
}
