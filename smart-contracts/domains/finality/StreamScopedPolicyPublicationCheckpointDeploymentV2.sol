// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamScopedPolicyPublicationGraphTypesV2 as T
} from "../../interfaces/stream/finality/StreamScopedPolicyPublicationGraphTypesV2.sol";
import {
    StreamScopedPolicyPublicationCheckpointConstructorV2 as Constructor
} from "./StreamScopedPolicyPublicationCheckpointConstructorV2.sol";
import {
    StreamScopedPolicyPublicationRecipeV2 as Recipe
} from "./StreamScopedPolicyPublicationRecipeV2.sol";

/// @notice Fixed delegate-host CREATE worker; callers cannot nominate implementation code.
library StreamScopedPolicyPublicationCheckpointDeploymentV2 {
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
