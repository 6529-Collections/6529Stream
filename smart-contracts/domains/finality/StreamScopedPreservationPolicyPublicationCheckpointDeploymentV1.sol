// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamScopedPreservationPolicyPublicationGraphTypesV1 as T
} from "../../interfaces/stream/finality/StreamScopedPreservationPolicyPublicationGraphTypesV1.sol";
import {
    StreamScopedPreservationPolicyContentCheckpointV1 as Child
} from "./StreamScopedPreservationPolicyContentCheckpointV1.sol";
import {
    StreamScopedPreservationPolicyPublicationRecipeV1 as Recipe
} from "./StreamScopedPreservationPolicyPublicationRecipeV1.sol";

/// @notice Fixed delegate-host CREATE worker; callers cannot nominate implementation code.
library StreamScopedPreservationPolicyPublicationCheckpointDeploymentV1 {
    function deploy(T.Recipe memory r, T.Graph memory g) public returns (address) {
        return address(
            new Child(
                r.targets[1],
                g.sourceSet,
                g.children[0],
                r.targets[3],
                r.checkpointGas[0],
                r.checkpointGas[1]
            )
        );
    }
}
