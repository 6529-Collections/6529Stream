// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamScopedPreservationPolicyPublicationGraphTypesV1 as T
} from "../../interfaces/stream/finality/StreamScopedPreservationPolicyPublicationGraphTypesV1.sol";
import {
    StreamScopedPreservationPolicyPublicationCheckpointConstructorV2 as Constructor
} from "./StreamScopedPreservationPolicyPublicationCheckpointConstructorV2.sol";
import {
    StreamScopedPreservationPolicyPublicationRecipeV1 as Recipe
} from "./StreamScopedPreservationPolicyPublicationRecipeV1.sol";

/// @notice Fixed family V2 CREATE worker; callers cannot nominate code or a producer family.
library StreamScopedPreservationPolicyPublicationCheckpointDeploymentV2 {
    function deploy(T.Recipe memory r, T.Graph memory g) public returns (address) {
        return Constructor.deploy(
            r.targets[1],
            g.sourceSet,
            g.children[0],
            r.targets[3],
            r.checkpointGas[0],
            r.checkpointGas[1]
        );
    }
}
